import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';
import 'package:dio/dio.dart';

// 记录服务：从后端拉取图片记录并与本地缓存合并
final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService(
    ref.watch(sharedPreferencesProvider.future),
    ref.read(dioProvider),
    ref.read(sceneServiceProvider),
    ref.read(localCacheServiceProvider),
  );
});

class RecordService {
  final Future<SharedPreferences> _prefs;
  final Dio _dio;
  final SceneService _sceneService;
  final LocalCacheService _cache;

  static const String _recordsKey = 'inspection_records';

  RecordService(this._prefs, this._dio, this._sceneService, this._cache);

  /// 获取拍摄记录（优先网络，失败兜底本地缓存）
  /// 说明：
  /// - 后端 /api/images 返回图片记录列表，字段包含 id、sceneId、path、createdAt 等
  /// - 为了显示场景名称，这里会先调用 SceneService.getScenes() 并用 sceneId 做映射
  /// - 图片 path 可能是相对路径（如 uploads/images/...），需要拼接为完整 URL 才能在前端展示
  Future<List<InspectionRecord>> getRecords() async {
    try {
      // 1) 并发获取场景列表与图片记录
      final scenesFuture = _sceneService.getScenes();
      final imagesResponse = await _dio.get('/images');

      final data = imagesResponse.data;
      List<InspectionRecord> networkRecords = [];

      if (data is Map && data['images'] is List) {
        final scenes = await scenesFuture;
        // 构建 sceneId -> sceneName 映射表
        final Map<String, String> sceneNameById = {
          for (final s in scenes) s.id: s.name,
        };

        final List items = data['images'];
        networkRecords = items.map((raw) {
          final m = raw as Map<String, dynamic>;

          // 提前解析字段，避免多层嵌套，提高可读性
          final String id = m['id']?.toString() ?? '';
          final String sceneId = m['sceneId'] is Map && m['sceneId']['Hex'] != null
              ? m['sceneId']['Hex'].toString()
              : (m['sceneId']?.toString() ?? '');
          final String path = m['path']?.toString() ?? '';
          final String createdAtStr = m['createdAt']?.toString() ?? m['timestamp']?.toString() ?? '';

          // 构建完整图片URL（当 path 为相对路径或以 ./ 开头时，统一转为 http://host:port/uploads/...）
          final String fullUrl = _buildFullImageUrl(path);

          // 推断状态：若已检测则显示“已检测”，有缺陷则显示“存在缺陷”，否则“已上传”
          final bool isDetected = m['isDetected'] == true;
          final bool hasIssue = m['hasIssue'] == true;
          final String status = hasIssue
              ? '存在缺陷'
              : (isDetected ? '已检测' : '已上传');

          // 时间解析：尽量使用后端的 createdAt/timestamp，失败则使用当前时间
          DateTime ts;
          try {
            ts = DateTime.parse(createdAtStr);
          } catch (_) {
            ts = DateTime.now();
          }

          return InspectionRecord(
            id: id,
            sceneName: sceneNameById[sceneId] ?? '未知场景',
            imagePath: fullUrl,
            timestamp: ts,
            status: status,
          );
        }).toList().cast<InspectionRecord>();
      }

      // 2) 读取本地缓存记录作为兜底或补充（例如刚上传的本地记录）
      final prefs = await _prefs;
      final localJson = prefs.getString(_recordsKey);
      final List<InspectionRecord> localRecords = localJson != null
          ? InspectionRecord.fromJsonList(localJson)
          : <InspectionRecord>[];

      // 3) 合并记录并去重：优先使用“网络记录”的权威信息，保留“仅本地存在”的新记录
      // 中文说明：
      // - 修复重复显示同一图片的问题：之前直接拼接本地+网络，导致同一条记录出现两次甚至多次
      // - 合并规则：以 id 为主键去重；若 id 为空则使用 imagePath+timestamp 作为备用键
      final combined = _mergeAndDedupRecords(localRecords, networkRecords);

      // 4) 图片离线缓存：将网络图片下载到本地并替换 imagePath；失败则回退使用原combined
      // 中文注释：
      // - 为避免多层嵌套，采用 try-catch 包裹缓存过程；
      // - 仅对 http/https 的图片执行下载，本地路径保持不变；
      List<InspectionRecord> cachedCombined = combined;
      try {
        cachedCombined = await _cache.cacheRecordImages<InspectionRecord>(
          records: combined,
          getImagePath: (r) => r.imagePath,
          getIdOrKey: (r) => r.id.isNotEmpty ? r.id : r.timestamp.millisecondsSinceEpoch.toString(),
          copyWithImagePath: (r, newPath) => r.copyWith(imagePath: newPath),
        );
      } catch (_) {
        // 缓存失败不影响主流程，继续使用合并后的记录
      }

      // 5) 将（可能已替换为本地路径的）记录写入本地，作为下次兜底数据
      await saveRecords(cachedCombined);

      return cachedCombined;
    } catch (e) {
      // 网络失败时，使用本地缓存兜底
      final prefs = await _prefs;
      final recordsJson = prefs.getString(_recordsKey);
      if (recordsJson != null) {
        return InspectionRecord.fromJsonList(recordsJson);
      }
      throw Exception('获取检测记录失败: $e');
    }
  }

  Future<void> saveRecords(List<InspectionRecord> records) async {
    try {
      final prefs = await _prefs;
      final recordsJson = InspectionRecord.toJsonList(records);
      await prefs.setString(_recordsKey, recordsJson);
    } catch (e) {
      throw Exception('保存检测记录失败: $e');
    }
  }

  Future<void> addRecord(InspectionRecord record) async {
    try {
      // 仅读取本地缓存，避免再次拉取网络导致重复合并
      final prefs = await _prefs;
      final localJson = prefs.getString(_recordsKey);
      final List<InspectionRecord> localRecords = localJson != null
          ? InspectionRecord.fromJsonList(localJson)
          : <InspectionRecord>[];

      // 插入新记录到顶部
      final updated = <InspectionRecord>[record, ...localRecords];

      // 为避免后续刷新时再次出现重复，直接保存本地缓存
      await saveRecords(updated);
    } catch (e) {
      throw Exception('添加检测记录失败: $e');
    }
  }

  Future<void> updateRecord(InspectionRecord updatedRecord) async {
    try {
      final records = await getRecords();
      final index = records.indexWhere((record) => record.id == updatedRecord.id);
      
      if (index != -1) {
        records[index] = updatedRecord;
        await saveRecords(records);
      } else {
        throw Exception('记录不存在');
      }
    } catch (e) {
      throw Exception('更新检测记录失败: $e');
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      final records = await getRecords();
      records.removeWhere((record) => record.id == recordId);
      await saveRecords(records);
    } catch (e) {
      throw Exception('删除检测记录失败: $e');
    }
  }

  Future<InspectionRecord?> getRecordById(String recordId) async {
    try {
      final records = await getRecords();
      return records.firstWhere((record) => record.id == recordId);
    } catch (e) {
      return null;
    }
  }

  Future<List<InspectionRecord>> getRecordsByScene(String sceneName) async {
    try {
      final records = await getRecords();
      return records.where((record) => record.sceneName == sceneName).toList();
    } catch (e) {
      throw Exception('按场景获取记录失败: $e');
    }
  }

  Future<void> clearAllRecords() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_recordsKey);
    } catch (e) {
      throw Exception('清空检测记录失败: $e');
    }
  }

  // 构建完整图片URL（与样式图逻辑保持一致）
  // 规则：
  // 1) 若 path 已是 http(s) 则直接返回
  // 2) 若 path 以 ./ 开头，去掉前缀 '.'
  // 3) 确保相对路径以 '/' 开头
  // 4) 使用 Dio 的 baseUrl 去掉 /api 前缀得到服务器根地址，然后拼接
  String _buildFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final apiBase = _dio.options.baseUrl;
    final rootBase = apiBase.replaceFirst(RegExp(r'/api/?$'), '');
    String relative = p.replaceFirst(RegExp(r'^\.'), '');
    if (!relative.startsWith('/')) {
      relative = '/$relative';
    }
    final normalizedBase = rootBase.endsWith('/') ? rootBase.substring(0, rootBase.length - 1) : rootBase;
    return '$normalizedBase$relative';
  }

  /// 合并并去重记录列表
  /// 中文注释：
  /// - 先将“网络记录”放入字典（键为唯一键），确保以服务器权威信息为准
  /// - 再补充“本地记录”：若字典中不存在相同唯一键，则加入（保留仅本地存在的新记录）
  /// - 唯一键策略：优先使用 id；若 id 为空，则使用 imagePath|timestamp 作为备用键，避免错误合并
  /// - 返回值：按时间倒序排序的去重列表
  List<InspectionRecord> _mergeAndDedupRecords(
    List<InspectionRecord> localRecords,
    List<InspectionRecord> networkRecords,
  ) {
    String _keyOf(InspectionRecord r) {
      if (r.id.isNotEmpty) return r.id;
      return '${r.imagePath}|${r.timestamp.millisecondsSinceEpoch}';
    }

    final Map<String, InspectionRecord> map = {};

    // 1) 先放入网络数据（权威信息）
    for (final r in networkRecords) {
      map[_keyOf(r)] = r;
    }

    // 2) 再补充本地数据（仅当不存在同键时加入）
    for (final r in localRecords) {
      final key = _keyOf(r);
      map.putIfAbsent(key, () => r);
    }

    // 3) 输出并排序（新在前）
    final merged = map.values.toList();
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }
}