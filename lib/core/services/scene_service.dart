import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/providers/app_providers.dart';

final sceneServiceProvider = Provider<SceneService>((ref) {
  return SceneService(ref.watch(sharedPreferencesProvider.future));
});

class SceneService {
  final Future<SharedPreferences> _prefs;
  static const String _scenesKey = 'scenes';

  SceneService(this._prefs);

  Future<List<SceneData>> getScenes() async {
    try {
      final prefs = await _prefs;
      final scenesJson = prefs.getString(_scenesKey);
      
      if (scenesJson != null) {
        return SceneData.fromJsonList(scenesJson);
      }
      
      // 默认场景数据
      final defaultScenes = [
        SceneData(id: '001', name: '管道闸口'),
        SceneData(id: '002', name: '主承轴区域'),
        SceneData(id: '003', name: '冷却系统出口'),
        SceneData(id: '004', name: '传动轴检测点'),
        SceneData(id: '005', name: '润滑系统'),
        SceneData(id: '006', name: '控制阀门'),
        SceneData(id: '007', name: '进气管道'),
        SceneData(id: '008', name: '排气系统'),
        SceneData(id: '009', name: '温控单元'),
      ];
      
      await saveScenes(defaultScenes);
      return defaultScenes;
    } catch (e) {
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