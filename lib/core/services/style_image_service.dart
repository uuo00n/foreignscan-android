// ==================== lib/core/services/style_image_service.dart ====================
// 样式图（模板参考图）服务：从后端拉取指定场景的样式图列表

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/style_image.dart';

// Provider：样式图服务
final styleImageServiceProvider = Provider<StyleImageService>((ref) {
  // 引入 SharedPreferences + LocalCacheService 以实现样式图元数据与图片本地兜底
  return StyleImageService(
    ref.watch(sharedPreferencesProvider.future),
    ref.read(dioProvider),
    ref.read(localCacheServiceProvider),
  );
});

class StyleImageWarmupResult {
  final int totalScenes;
  final int cachedScenes;
  final int failedScenes;
  final List<String> failedSceneIds;

  const StyleImageWarmupResult({
    required this.totalScenes,
    required this.cachedScenes,
    required this.failedScenes,
    this.failedSceneIds = const <String>[],
  });
}

class StyleImageService {
  final Future<SharedPreferences> _prefs;
  final Dio _dio;
  final LocalCacheService _localCacheService;

  StyleImageService(this._prefs, this._dio, this._localCacheService);

  // 获取指定点位的样式图列表（后端点位一对一）
  Future<List<StyleImage>> getStyleImagesByScene(String sceneId) async {
    final pointId = sceneId;
    final cacheKey = 'style_images_point_$pointId';
    try {
      final response = await _dio.get('/style-images/point/$pointId');
      final data = response.data;

      if (data is Map && data['success'] == true) {
        final dynamic single = data['styleImage'];
        final List items = single == null ? <dynamic>[] : <dynamic>[single];
        final images = items
            .map((e) => StyleImage.fromJson(e as Map<String, dynamic>))
            .toList();
        // 成功拉取后写入本地缓存，便于离线展示
        try {
          final prefs = await _prefs;
          final jsonList = images.map((e) => e.toJson()).toList();
          await prefs.setString(cacheKey, StyleImage.toJsonList(jsonList));
        } catch (_) {}
        return images;
      }

      // 若结构不符合预期，尝试从本地缓存兜底
      final prefs = await _prefs;
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return StyleImage.fromJsonList(cached);
      }

      return <StyleImage>[];
    } catch (e) {
      // 网络失败：使用本地缓存兜底
      try {
        final prefs = await _prefs;
        final cached = prefs.getString(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return StyleImage.fromJsonList(cached);
        }
      } catch (_) {}
      return <StyleImage>[];
    }
  }

  // 根据样式图对象，生成可直接访问的完整URL
  // 注意：静态文件通过后端服务器根路径（非 /api）下的 /uploads 暴露，这里使用 NetworkConfig.apiBaseUrl 去掉 /api
  String buildImageUrl(StyleImage image) {
    // 优化：改为使用当前 Dio 的 baseUrl，而不是静态常量。
    // 这样当用户在“服务器设置”中修改 IP/端口后，图片 URL 会自动匹配最新地址。
    // 示例：_dio.options.baseUrl = http://192.168.1.100:8080/api => rootBase = http://192.168.1.100:8080
    final apiBase = _dio.options.baseUrl;
    final rootBase = apiBase.replaceFirst(RegExp(r'/api/?$'), '');
    return image.toFullUrl(rootBase);
  }

  /// 批量预热：按场景拉取样式图元数据并下载到本地缓存
  /// 结果用于同步后的统计展示与日志记录
  Future<StyleImageWarmupResult> warmupStyleImagesForScenes(
    List<SceneData> scenes,
  ) async {
    if (scenes.isEmpty) {
      return const StyleImageWarmupResult(
        totalScenes: 0,
        cachedScenes: 0,
        failedScenes: 0,
      );
    }

    final uniqueSceneIds = <String>{};
    var cachedScenes = 0;
    final failedSceneIds = <String>[];

    for (final scene in scenes) {
      final sceneId = scene.id.trim();
      if (sceneId.isEmpty || !uniqueSceneIds.add(sceneId)) {
        continue;
      }

      final images = await getStyleImagesByScene(sceneId);
      if (images.isEmpty) {
        failedSceneIds.add(sceneId);
        continue;
      }

      var hasAnyCached = false;
      for (final image in images) {
        final remoteUrl = buildImageUrl(image);
        final filename = '${image.id}_${image.filename ?? 'style.jpg'}';
        final localPath = await _localCacheService.ensureCachedImage(
          url: remoteUrl,
          subdir: 'style_images/$sceneId',
          filename: filename,
        );
        if (localPath != null && localPath.isNotEmpty) {
          hasAnyCached = true;
        }
      }

      if (hasAnyCached) {
        cachedScenes += 1;
      } else {
        failedSceneIds.add(sceneId);
      }
    }

    return StyleImageWarmupResult(
      totalScenes: uniqueSceneIds.length,
      cachedScenes: cachedScenes,
      failedScenes: failedSceneIds.length,
      failedSceneIds: failedSceneIds,
    );
  }
}
