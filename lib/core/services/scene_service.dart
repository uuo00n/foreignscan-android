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

  Future<List<SceneData>> getScenes({bool forceOffline = false}) async {
    try {
      if (!forceOffline) {
        // 先尝试从后端接口获取
        // 说明：后端 Gin 路由基础路径为 /api，这里使用 Dio 已设置的 baseUrl（例如 http://localhost:3000/api）
        final response = await _dio.get('/scenes');
        final data = response.data;

        // 后端返回结构示例：{ success: true, scenes: [...] }
        if (data is Map && data['scenes'] is List) {
          final List scenesList = data['scenes'];
          final scenes = await Future.wait(scenesList.map((item) async {
            final m = item as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            
            // 并行请求每个场景的最新状态（可选优化：后端已在列表接口返回状态最好，若未返回则需补充请求）
            // 假设后端 /scenes 接口暂未返回 latestStatus，则需要单独 fetchDetail
            // 但为了性能，这里我们先直接解析（如果后端已在 /scenes 列表里补充了字段最好）
            // 补充逻辑：如果列表项没有状态字段，尝试调用 /scenes/{id} 获取详情（注意并发量）
            // 考虑到并发请求太多，暂时先只从列表项解析（假设后端 /scenes 接口已包含或将包含）
            // 如果后端 /scenes 没返回，则 UI 上暂时为空
            
            // 为了支持最新的“闭环”逻辑，我们在这里尝试请求详情获取最新状态
            // 注意：这会产生 N+1 次请求，如果场景多可能会慢。
            // 更好的方式是后端 /scenes 接口直接返回。
            // 现阶段后端 /scenes 接口未修改返回详情，但 /scenes/{id} 已修改。
            // 临时方案：前端在此处循环请求详情（数量少时可行）。
            
            String? latestStatus;
            bool? hasIssue;
            try {
              final detailResp = await _dio.get('/scenes/$id');
              final detailData = detailResp.data;
              if (detailData is Map && detailData['success'] == true) {
                 latestStatus = detailData['latestStatus']?.toString();
                 hasIssue = detailData['hasIssue'] == true;
              }
            } catch (_) {
              // 详情获取失败忽略
            }

            return SceneData(
              id: id, // ObjectID 转 hex 字符串
              name: m['name']?.toString() ?? '',
              latestStatus: latestStatus,
              hasIssue: hasIssue,
            );
          }));

          // 写入本地缓存作为兜底
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