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

  String _buildSceneName(String pointName, String roomName) {
    final p = pointName.trim();
    final r = roomName.trim();
    if (r.isEmpty) return p;
    if (p.isEmpty) return r;
    return '$r / $p';
  }

  Future<List<SceneData>> getScenes({bool forceOffline = false}) async {
    try {
      if (!forceOffline) {
        final prefs = await _prefs;
        final padId = (prefs.getString('pad_id') ?? '').trim();
        final padKey = (prefs.getString('pad_key') ?? '').trim();
        final headers = <String, String>{};
        if (padId.isNotEmpty && padKey.isNotEmpty) {
          headers['X-Pad-Id'] = padId;
          headers['X-Pad-Key'] = padKey;
        }
        final response = await _dio.get(
          '/pad/room-context',
          options: Options(headers: headers),
        );
        final data = response.data;

        if (data is Map &&
            data['success'] == true &&
            data['room'] is Map &&
            data['points'] is List) {
          final room = data['room'] as Map;
          final roomId = room['id']?.toString() ?? '';
          final roomName = room['name']?.toString() ?? roomId;

          final List pointsList = data['points'];
          final scenes = pointsList.map((item) {
            final m = item as Map<String, dynamic>;
            final pointId = m['id']?.toString() ?? '';
            final pointName = m['name']?.toString() ?? pointId;
            return SceneData(
              id: pointId,
              name: _buildSceneName(pointName, roomName),
              roomId: m['roomId']?.toString().isNotEmpty == true
                  ? m['roomId'].toString()
                  : roomId,
              roomName: roomName,
              pointCode: m['code']?.toString() ?? '',
              location: m['location']?.toString() ?? '',
            );
          }).toList();

          await saveScenes(scenes);
          return scenes;
        }
      }

      // 如果强制离线或结构不符合预期，尝试本地缓存兜底
      final prefs = await _prefs;
      final scenesJson = prefs.getString(_scenesKey);
      if (scenesJson != null) {
        return SceneData.fromJsonList(scenesJson);
      }

      // 最后兜底：返回空列表
      return <SceneData>[];
    } catch (e) {
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
            lastSimilarityPassed: false,
            clearLastSimilarityPercent: true,
            clearLastSimilarityStyleImageId: true,
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
  Future<void> updateSceneTransferStatus(
    String sceneId,
    bool isTransferred,
  ) async {
    try {
      final scenes = await getScenes();
      final updatedScenes = scenes.map((scene) {
        if (scene.id == sceneId) {
          return scene.copyWith(
            isTransferred: isTransferred,
            transferTime: isTransferred ? DateTime.now() : null,
            clearTransferTime: !isTransferred,
            lastSimilarityPassed: isTransferred
                ? false
                : scene.lastSimilarityPassed,
            clearLastSimilarityPercent: isTransferred,
            clearLastSimilarityStyleImageId: isTransferred,
          );
        }
        return scene;
      }).toList();

      await saveScenes(updatedScenes);
    } catch (e) {
      throw Exception('更新场景传输状态失败: $e');
    }
  }

  Future<void> reassignSceneImage({
    required String fromSceneId,
    required String toSceneId,
    required String imagePath,
  }) async {
    try {
      final scenes = await getScenes();
      final now = DateTime.now();
      final updatedScenes = scenes.map((scene) {
        if (scene.id == fromSceneId && fromSceneId != toSceneId) {
          return scene.copyWith(
            clearCapturedImage: true,
            clearCaptureTime: true,
            lastSimilarityPassed: false,
            clearLastSimilarityPercent: true,
            clearLastSimilarityStyleImageId: true,
          );
        }

        if (scene.id == toSceneId) {
          return scene.copyWith(
            capturedImage: imagePath,
            captureTime: now,
            lastSimilarityPassed: false,
            clearLastSimilarityPercent: true,
            clearLastSimilarityStyleImageId: true,
          );
        }

        return scene;
      }).toList();

      await saveScenes(updatedScenes);
    } catch (e) {
      throw Exception('重新分配场景图片失败: $e');
    }
  }

  Future<void> updateSceneSimilarityStatus(
    String sceneId, {
    required bool passed,
    double? similarityPercent,
    String? styleImageId,
  }) async {
    try {
      final scenes = await getScenes();
      final updatedScenes = scenes.map((scene) {
        if (scene.id != sceneId) {
          return scene;
        }
        return scene.copyWith(
          lastSimilarityPassed: passed,
          lastSimilarityPercent: passed ? similarityPercent : null,
          clearLastSimilarityPercent: !passed,
          lastSimilarityStyleImageId: passed ? styleImageId : null,
          clearLastSimilarityStyleImageId: !passed,
        );
      }).toList();

      await saveScenes(updatedScenes);
    } catch (e) {
      throw Exception('更新场景相似度状态失败: $e');
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
