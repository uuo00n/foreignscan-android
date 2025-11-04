import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:dio/dio.dart';

// 记录服务：从后端拉取图片记录并与本地缓存合并
final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService(
    ref.watch(sharedPreferencesProvider.future),
    ref.read(dioProvider),
    ref.read(sceneServiceProvider),
  );
});

class RecordService {
  final Future<SharedPreferences> _prefs;
  final Dio _dio;
  final SceneService _sceneService;

  static const String _recordsKey = 'inspection_records';

  RecordService(this._prefs, this._dio, this._sceneService);

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

      // 3) 合并记录并按时间倒序排序（避免重复复杂化，直接拼接即可）
      final combined = <InspectionRecord>[...localRecords, ...networkRecords];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 4) 将网络记录写入本地，作为下次的兜底数据（避免不必要的对象复制）
      await saveRecords(combined);

      return combined;
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
      final records = await getRecords();
      records.insert(0, record);
      await saveRecords(records);
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
}