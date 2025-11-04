import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:dio/dio.dart';

final sceneServiceProvider = Provider<SceneService>((ref) {
  // 通过 SharedPreferences 做本地缓存兜底，Dio 用于请求后端接口
  return SceneService(
    ref.watch(sharedPreferencesProvider.future),
    ref.read(dioProvider),
  );
});

class SceneService {
  final Future<SharedPreferences> _prefs;
  final Dio _dio;
  static const String _scenesKey = 'scenes';

  SceneService(this._prefs, this._dio);

  Future<List<SceneData>> getScenes() async {
    try {
      // 先尝试从后端接口获取
      // 说明：后端 Gin 路由基础路径为 /api，这里使用 Dio 已设置的 baseUrl（例如 http://localhost:3000/api）
      final response = await _dio.get('/scenes');
      final data = response.data;

      // 后端返回结构示例：{ success: true, scenes: [...] }
      if (data is Map && data['scenes'] is List) {
        final List scenesList = data['scenes'];
        final scenes = scenesList.map((item) {
          final m = item as Map<String, dynamic>;
          return SceneData(
            id: m['id']?.toString() ?? '', // ObjectID 转 hex 字符串
            name: m['name']?.toString() ?? '',
          );
        }).toList().cast<SceneData>();

        // 写入本地缓存作为兜底
        await saveScenes(scenes);
        return scenes;
      }

      // 如果结构不符合预期，尝试本地缓存兜底
      final prefs = await _prefs;
      final scenesJson = prefs.getString(_scenesKey);
      if (scenesJson != null) {
        return SceneData.fromJsonList(scenesJson);
      }

      // 最后兜底：返回空列表
      return <SceneData>[];
    } catch (e) {
      // 网络或解析失败时，走本地缓存兜底
      final prefs = await _prefs;
      final scenesJson = prefs.getString(_scenesKey);
      if (scenesJson != null) {
        return SceneData.fromJsonList(scenesJson);
      }
      throw Exception('获取场景数据失败: $e');
    }
  }

  Future<void> saveScenes(List<SceneData> scenes) async {
    try {
      final prefs = await _prefs;
      final scenesJson = SceneData.toJsonList(scenes);
      await prefs.setString(_scenesKey, scenesJson);
    } catch (e) {
      throw Exception('保存场景数据失败: $e');
    }
  }

  Future<void> updateSceneImage(String sceneId, String imagePath) async {
    try {
      final scenes = await getScenes();
      final updatedScenes = scenes.map((scene) {
        if (scene.id == sceneId) {
          return scene.copyWith(
            capturedImage: imagePath,
            captureTime: DateTime.now(), // Set the capture time to now
          );
        }
        return scene;
      }).toList();
      
      await saveScenes(updatedScenes);
    } catch (e) {
      throw Exception('更新场景图片失败: $e');
    }
  }

  /// 更新场景的传输状态
  /// - 上传成功后调用：设置 isTransferred=true，记录 transferTime
  /// - 若取消或重置，可传 isTransferred=false 并清空 transferTime
  Future<void> updateSceneTransferStatus(String sceneId, bool isTransferred) async {
    try {
      final scenes = await getScenes();
      final updatedScenes = scenes.map((scene) {
        if (scene.id == sceneId) {
          return scene.copyWith(
            isTransferred: isTransferred,
            transferTime: isTransferred ? DateTime.now() : null,
          );
        }
        return scene;
      }).toList();

      await saveScenes(updatedScenes);
    } catch (e) {
      throw Exception('更新场景传输状态失败: $e');
    }
  }

  Future<void> addScene(SceneData scene) async {
    try {
      final scenes = await getScenes();
      scenes.add(scene);
      await saveScenes(scenes);
    } catch (e) {
      throw Exception('添加场景失败: $e');
    }
  }

  Future<void> deleteScene(String sceneId) async {
    try {
      final scenes = await getScenes();
      scenes.removeWhere((scene) => scene.id == sceneId);
      await saveScenes(scenes);
    } catch (e) {
      throw Exception('删除场景失败: $e');
    }
  }
}