import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/models/scene_data.dart';

class SceneTransferResult {
  final bool success;
  final String? errorMessage;

  const SceneTransferResult._({required this.success, this.errorMessage});

  const SceneTransferResult.success() : this._(success: true);

  const SceneTransferResult.failure(String message)
    : this._(success: false, errorMessage: message);
}

class BatchTransferProgress {
  final int completed;
  final int failed;
  final int total;

  const BatchTransferProgress({
    required this.completed,
    required this.failed,
    required this.total,
  });

  int get processed => completed + failed;

  double get progress => total <= 0 ? 0 : processed / total;
}

class BatchTransferResult {
  final int completed;
  final int failed;
  final int total;

  const BatchTransferResult({
    required this.completed,
    required this.failed,
    required this.total,
  });
}

class SyncDataResult {
  final bool success;
  final bool isOnline;
  final String? errorMessage;

  const SyncDataResult({
    required this.success,
    required this.isOnline,
    this.errorMessage,
  });
}

class HomeWorkflowController {
  final WidgetRef _ref;

  const HomeWorkflowController(this._ref);

  Future<bool> uploadSceneImage(SceneData scene) async {
    final imagePath = scene.capturedImage;
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }

    final wifiService = _ref.read(wifiServiceProvider);
    final result = await wifiService.uploadImageFromCamera(
      imagePath,
      sceneId: scene.id,
    );
    return result != null;
  }

  Future<SceneTransferResult> transferScene(SceneData scene) async {
    final imagePath = scene.capturedImage;
    if (imagePath == null || imagePath.isEmpty) {
      return const SceneTransferResult.failure('请先拍摄该场景');
    }

    try {
      final wifiService = _ref.read(wifiServiceProvider);
      final uploadResult = await wifiService.uploadImageFromCamera(
        imagePath,
        sceneId: scene.id,
      );

      if (uploadResult == null) {
        return const SceneTransferResult.failure('传输失败，请检查网络连接和服务器设置');
      }

      final normalizedResult = Map<String, dynamic>.from(uploadResult);
      await _persistTransferResult(scene: scene, result: normalizedResult);
      return const SceneTransferResult.success();
    } catch (e) {
      return SceneTransferResult.failure('传输出错: $e');
    }
  }

  Future<BatchTransferResult> transferScenes(
    List<SceneData> scenes, {
    required void Function(BatchTransferProgress progress) onProgress,
  }) async {
    var completed = 0;
    var failed = 0;

    final total = scenes.length;
    for (final scene in scenes) {
      final result = await transferScene(scene);
      if (result.success) {
        completed++;
      } else {
        failed++;
      }

      onProgress(
        BatchTransferProgress(
          completed: completed,
          failed: failed,
          total: total,
        ),
      );
    }

    return BatchTransferResult(
      completed: completed,
      failed: failed,
      total: total,
    );
  }

  Future<SyncDataResult> syncData() async {
    final wifiService = _ref.read(wifiServiceProvider);
    bool isOnline;
    try {
      isOnline = await wifiService.testConnection();
    } catch (_) {
      isOnline = false;
    }

    try {
      final homeVM = _ref.read(homeViewModelProvider.notifier);
      await homeVM
          .refreshData(forceOffline: !isOnline)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('请求超时，请检查网络或服务器状态'),
          );

      _ref.invalidate(styleImagesForSelectedSceneProvider);
      _ref.invalidate(referenceImageUrlProvider);

      return SyncDataResult(success: true, isOnline: isOnline);
    } catch (e) {
      var message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      _ref.read(loggerProvider).e('同步失败: $e');
      return SyncDataResult(
        success: false,
        isOnline: isOnline,
        errorMessage: message,
      );
    }
  }

  Future<void> _persistTransferResult({
    required SceneData scene,
    required Map<String, dynamic> result,
  }) async {
    final wifiService = _ref.read(wifiServiceProvider);

    final imageId =
        result['imageId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final relativePath =
        (result['path']?.toString() ?? result['accessPath']?.toString() ?? '');
    final fullUrl = _joinServerPath(wifiService.serverAddress, relativePath);

    final homeVM = _ref.read(homeViewModelProvider.notifier);
    final newRecord = InspectionRecord(
      id: imageId,
      sceneName: scene.name,
      imagePath: fullUrl.isNotEmpty ? fullUrl : (scene.capturedImage ?? ''),
      timestamp: DateTime.now(),
      status: '已上传',
    );

    await homeVM.addInspectionRecord(newRecord);
    await homeVM.updateSceneTransferStatus(scene.id, true);
  }

  String _joinServerPath(String base, String relativePath) {
    if (relativePath.isEmpty) {
      return '';
    }

    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedRelative = relativePath.startsWith('/')
        ? relativePath
        : '/$relativePath';
    return '$normalizedBase$normalizedRelative';
  }
}
