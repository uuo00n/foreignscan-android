// ==================== lib/core/services/local_cache_service.dart ====================
// 本地图片缓存服务
// 作用：
// 1) 将网络图片（http/https）下载到应用的本地存储（Documents目录）
// 2) 为“模板参考图”（样式图）与“拍摄记录图片”提供统一的缓存路径与命名规范
// 3) 通过统一的 ensureCachedImage 接口，避免重复下载与不必要的对象复制
//
// 设计要点（中文注释）：
// - 路径结构：<appDocDir>/<subdir>/<filename>
// - 命名规范：优先使用具备唯一性的标识（如样式图id、记录id），辅以原始文件名；
// - 并发控制：本版本采用简单串行下载，避免复杂并发；如需优化可引入队列或Isolate。

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalCacheService {
  final Dio _dio;

  LocalCacheService(this._dio);

  /// 确保将指定URL的图片缓存到本地，并返回本地文件路径
  /// 参数说明：
  /// - url: 网络图片的完整URL（必须是 http/https）
  /// - subdir: 本地子目录，例如 `style_images/<sceneId>` 或 `records`
  /// - filename: 目标文件名，例如 `<styleId>_<origName>.jpg` 或 `record_<id>.jpg`
  /// 返回：成功时返回本地文件绝对路径；失败或不需要缓存时返回 null
  Future<String?> ensureCachedImage({
    required String url,
    required String subdir,
    required String filename,
  }) async {
    // 1) 参数校验：仅处理 http/https URL；本地路径不参与下载
    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return null;
    }

    try {
      // 2) 计算目标保存路径（提前返回策略：若已存在则直接返回）
      final String targetPath = await _buildLocalPath(
        subdir: subdir,
        filename: filename,
      );
      final file = File(targetPath);
      if (await file.exists()) {
        return targetPath; // 已缓存，直接返回
      }

      // 3) 确保父目录存在
      await file.parent.create(recursive: true);

      // 4) 下载并写入文件（避免多层嵌套，逐步返回）
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return null; // 下载失败或为空
      }

      await file.writeAsBytes(bytes, flush: true);
      return targetPath;
    } catch (_) {
      // 下载失败不抛出致命错误，返回 null 由调用方兜底
      return null;
    }
  }

  /// 批量缓存拍摄记录图片，并返回“可能被本地路径替换”的新列表
  /// 中文注释：
  /// - 对于 imagePath 为 http/https 的记录会下载到本地，然后将 imagePath 替换为本地文件路径
  /// - 对于已经是本地路径或空路径，保持不变，避免不必要的对象复制
  Future<List<TRecord>> cacheRecordImages<TRecord>({
    required List<TRecord> records,
    required String Function(TRecord r) getImagePath,
    required String Function(TRecord r) getIdOrKey,
    required TRecord Function(TRecord r, String newImagePath) copyWithImagePath,
  }) async {
    final List<TRecord> out = <TRecord>[];
    for (final r in records) {
      final imagePath = getImagePath(r);
      // 1) 非网络图片或空路径：保持原样
      if (imagePath.isEmpty ||
          (!imagePath.startsWith('http://') &&
              !imagePath.startsWith('https://'))) {
        out.add(r);
        continue;
      }

      // 2) 构建目标文件名（record_<idOrKey>.<ext>），默认使用 .jpg 扩展名
      final String idOrKey = getIdOrKey(r).isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : getIdOrKey(r);
      final String ext = _inferExtensionFromUrl(imagePath);
      final String filename = 'record_$idOrKey$ext';

      final local = await ensureCachedImage(
        url: imagePath,
        subdir: 'records',
        filename: filename,
      );
      out.add(local != null ? copyWithImagePath(r, local) : r);
    }
    return out;
  }

  /// 根据 URL 猜测文件扩展名（简单规则）
  /// - 若URL路径包含 .png/.jpg/.jpeg/.bmp/.webp，则对应返回；否则返回默认 .jpg
  String _inferExtensionFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return '.png';
    if (lower.contains('.jpeg')) return '.jpeg';
    if (lower.contains('.jpg')) return '.jpg';
    if (lower.contains('.bmp')) return '.bmp';
    if (lower.contains('.webp')) return '.webp';
    return '.jpg';
  }

  /// 计算本地文件完整路径（Documents/subdir/filename）
  Future<String> _buildLocalPath({
    required String subdir,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeSubdir = subdir.trim().isEmpty ? '' : subdir.trim();
    final safeFilename = filename.trim().isEmpty
        ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : filename.trim();
    return p.join(dir.path, safeSubdir, safeFilename);
  }

  /// 帮助方法：根据 subdir+filename 返回本地路径（不检查存在性）
  /// 适用于调用方希望先行判断文件是否已缓存
  Future<String> buildLocalPath({
    required String subdir,
    required String filename,
  }) async {
    return _buildLocalPath(subdir: subdir, filename: filename);
  }

  /// 在指定子目录下查找首个已缓存的文件路径（用于离线兜底显示模板参考图）
  /// 中文注释：
  /// - 通过应用文档目录 + subdir 定位目录；
  /// - 若目录存在且包含文件，返回第一个文件的绝对路径；
  /// - 若不存在或为空，返回 null。
  Future<String?> findFirstFileInSubdir(String subdir) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(baseDir.path, subdir));

    if (!await targetDir.exists()) {
      return null; // 目录不存在
    }

    // 列出该目录下的文件（不递归），选择第一个文件返回
    // 中文说明：避免多层嵌套，采用for循环提前返回，提升可读性
    final entries = targetDir.listSync(followLinks: false);
    for (final e in entries) {
      if (e is File) {
        return e.path; // 找到首个文件即返回
      }
    }
    return null; // 目录存在但没有文件
  }
}
