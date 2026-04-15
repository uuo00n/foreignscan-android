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
  static const String _matchingScenesKey = 'matching_scenes';

  SceneService(this._prefs, this._dio);

  String _buildSceneName(String pointName, String roomName) {
    final p = pointName.trim();
    final r = roomName.trim();
    if (r.isEmpty) return p;
    if (p.isEmpty) return r;
    return '$r / $p';
  }

  Future<Map<String, String>> _buildPadHeaders() async {
    final prefs = await _prefs;
    final padId = (prefs.getString('pad_id') ?? '').trim();
    final padKey = (prefs.getString('pad_key') ?? '').trim();
    final headers = <String, String>{};
    if (padId.isNotEmpty && padKey.isNotEmpty) {
      headers['X-Pad-Id'] = padId;
      headers['X-Pad-Key'] = padKey;
    }
    return headers;
  }

  SceneData _mapSceneItem(
    Map<String, dynamic> raw, {
    String fallbackRoomId = '',
    String fallbackRoomName = '',
  }) {
    final room = raw['room'];
    final roomMap = room is Map ? room : null;
    final roomId =
        raw['roomId']?.toString() ??
        roomMap?['id']?.toString() ??
        fallbackRoomId;
    final roomName =
        raw['roomName']?.toString() ??
        roomMap?['name']?.toString() ??
        fallbackRoomName;
    final pointId = raw['id']?.toString() ?? raw['pointId']?.toString() ?? '';
    final pointName =
        raw['name']?.toString() ?? raw['pointName']?.toString() ?? pointId;

    return SceneData(
      id: pointId,
      name: _buildSceneName(pointName, roomName),
      roomId: roomId,
      roomName: roomName,
      pointCode: raw['code']?.toString() ?? '',
      location: raw['location']?.toString() ?? '',
    );
  }

  List<SceneData> _parseSceneList(
    dynamic data, {
    String fallbackRoomId = '',
    String fallbackRoomName = '',
  }) {
    List<dynamic> items = const <dynamic>[];
    if (data is List) {
      items = data;
    } else if (data is Map) {
      if (data['points'] is List) {
        items = data['points'] as List<dynamic>;
      } else if (data['scenes'] is List) {
        items = data['scenes'] as List<dynamic>;
      } else if (data['data'] is List) {
        items = data['data'] as List<dynamic>;
      }
    }

    return items
        .whereType<Map>()
        .map(
          (item) => _mapSceneItem(
            Map<String, dynamic>.from(item),
            fallbackRoomId: fallbackRoomId,
            fallbackRoomName: fallbackRoomName,
          ),
        )
        .where((scene) => scene.id.isNotEmpty)
        .toList();
  }

  Future<List<SceneData>> getScenes({bool forceOffline = false}) async {
    try {
      if (!forceOffline) {
        final headers = await _buildPadHeaders();
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
          final scenes = _parseSceneList(
            data['points'],
            fallbackRoomId: roomId,
            fallbackRoomName: roomName,
          );

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

  Future<List<SceneData>> getAllScenesForMatching({
    bool forceOffline = false,
  }) async {
    try {
      if (!forceOffline) {
        final headers = await _buildPadHeaders();
        final response = await _dio.get(
          '/scenes',
          options: Options(headers: headers),
        );
        final scenes = _parseSceneList(response.data);
        if (scenes.isNotEmpty) {
          final prefs = await _prefs;
          await prefs.setString(
            _matchingScenesKey,
            SceneData.toJsonList(scenes),
          );
          return scenes;
        }
      }

      final prefs = await _prefs;
      final cachedScenes = prefs.getString(_matchingScenesKey);
      if (cachedScenes != null && cachedScenes.isNotEmpty) {
        return SceneData.fromJsonList(cachedScenes);
      }

      return await getScenes(forceOffline: true);
    } catch (e) {
      final prefs = await _prefs;
      final cachedScenes = prefs.getString(_matchingScenesKey);
      if (cachedScenes != null && cachedScenes.isNotEmpty) {
        return SceneData.fromJsonList(cachedScenes);
      }
      return await getScenes(forceOffline: true);
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
            clearLastSimilarityLevel: true,
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
            clearLastSimilarityLevel: isTransferred,
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
            clearLastSimilarityLevel: true,
            clearLastSimilarityStyleImageId: true,
          );
        }

        if (scene.id == toSceneId) {
          return scene.copyWith(
            capturedImage: imagePath,
            captureTime: now,
            lastSimilarityPassed: false,
            clearLastSimilarityPercent: true,
            clearLastSimilarityLevel: true,
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
    String? similarityLevel,
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
          lastSimilarityLevel: passed ? similarityLevel : null,
          clearLastSimilarityLevel: !passed,
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
