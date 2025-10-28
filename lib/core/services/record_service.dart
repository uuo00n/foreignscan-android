import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';

final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService(ref.watch(sharedPreferencesProvider.future));
});

class RecordService {
  final Future<SharedPreferences> _prefs;
  static const String _recordsKey = 'inspection_records';

  RecordService(this._prefs);

  Future<List<InspectionRecord>> getRecords() async {
    try {
      final prefs = await _prefs;
      final recordsJson = prefs.getString(_recordsKey);
      
      if (recordsJson != null) {
        return InspectionRecord.fromJsonList(recordsJson);
      }
      
      // 返回空列表，不再使用默认记录
      return [];
    } catch (e) {
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
}