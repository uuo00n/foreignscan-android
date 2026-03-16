import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/core/services/orb_ffi_service.dart';
import 'package:foreignscan/core/services/style_image_service.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/models/scene_data.dart';

enum SceneTransferFailureType {
  none,
  noCapturedImage,
  noReferenceImages,
  similarityTooLow,
  nativeUnavailable,
  uploadFailed,
  unexpected,
}

class SceneSimilarityResult {
  final bool passed;
  final String? bestStyleImageId;
  final double bestScore;
  final int bestGoodMatches;
  final String reason;
  final SceneTransferFailureType failureType;

  const SceneSimilarityResult({
    required this.passed,
    required this.bestStyleImageId,
    required this.bestScore,
    required this.bestGoodMatches,
    required this.reason,
    required this.failureType,
  });
}

class SceneTransferResult {
  final bool success;
  final String? errorMessage;
  final SceneSimilarityResult? similarity;
  final SceneTransferFailureType failureType;

  const SceneTransferResult._({
    required this.success,
    this.errorMessage,
    this.similarity,
    this.failureType = SceneTransferFailureType.none,
  });

  factory SceneTransferResult.success({SceneSimilarityResult? similarity}) {
    return SceneTransferResult._(success: true, similarity: similarity);
  }

  factory SceneTransferResult.failure(
    String message, {
    SceneSimilarityResult? similarity,
    SceneTransferFailureType failureType = SceneTransferFailureType.unexpected,
  }) {
    return SceneTransferResult._(
      success: false,
      errorMessage: message,
      similarity: similarity,
      failureType: failureType,
    );
  }
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
  static const double similarityThreshold = 0.18;
  static const int _orbDistanceThreshold = 50;
  static const int _orbMaxFeatures = 2000;

  final WidgetRef _ref;

  const HomeWorkflowController(this._ref);

  /// 拍摄后立即校验场景相似度（不触发上传）
  Future<SceneTransferResult> validateCapturedScene(
    SceneData scene,
    String imagePath,
  ) async {
    if (imagePath.isEmpty) {
      return SceneTransferResult.failure(
        '请先拍摄该场景',
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    final sceneForValidation = scene.copyWith(capturedImage: imagePath);
    final similarity = await validateSceneSimilarity(sceneForValidation);
    if (!similarity.passed) {
      return SceneTransferResult.failure(
        similarity.reason,
        similarity: similarity,
        failureType: similarity.failureType,
      );
    }
    return SceneTransferResult.success(similarity: similarity);
  }

  Future<SceneTransferResult> uploadSceneImage(SceneData scene) {
    return _validateAndUpload(scene: scene, persistResult: false);
  }

  Future<SceneTransferResult> transferScene(SceneData scene) {
    return _validateAndUpload(scene: scene, persistResult: true);
  }

  Future<SceneSimilarityResult> validateSceneSimilarity(SceneData scene) async {
    final imagePath = scene.capturedImage;
    if (imagePath == null || imagePath.isEmpty) {
      return const SceneSimilarityResult(
        passed: false,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        reason: '请先拍摄该场景',
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    final capturedFile = File(imagePath);
    if (!await capturedFile.exists()) {
      return SceneSimilarityResult(
        passed: false,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        reason: '拍摄图不存在：$imagePath',
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    final candidates = await _loadReferenceCandidates(scene.id);
    if (candidates.isEmpty) {
      return const SceneSimilarityResult(
        passed: false,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        reason: '当前场景没有可用的模板参考图，无法校验，请先同步样式图。',
        failureType: SceneTransferFailureType.noReferenceImages,
      );
    }

    final orbService = _tryGetOrbFfiService();
    if (orbService == null) {
      return const SceneSimilarityResult(
        passed: false,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        reason: '当前设备未启用 ORB 原生校验能力（仅支持 Android）。',
        failureType: SceneTransferFailureType.nativeUnavailable,
      );
    }

    OrbPairScore? bestScore;
    String? bestStyleImageId;
    var successfulComparisons = 0;

    for (final candidate in candidates) {
      try {
        final score = await orbService.comparePairAsync(
          capturedPath: imagePath,
          referencePath: candidate.localPath,
          distanceThreshold: _orbDistanceThreshold,
          maxFeatures: _orbMaxFeatures,
        );
        successfulComparisons += 1;

        if (bestScore == null || score.similarity > bestScore.similarity) {
          bestScore = score;
          bestStyleImageId = candidate.styleImageId;
        }
      } on OrbFfiException catch (e) {
        _ref
            .read(loggerProvider)
            .w(
              'ORB compare failed, scene=${scene.id}, style=${candidate.styleImageId}, error=$e',
            );
      } catch (e) {
        _ref
            .read(loggerProvider)
            .w(
              'ORB compare unexpected error, scene=${scene.id}, style=${candidate.styleImageId}, error=$e',
            );
      }
    }

    if (bestScore == null || successfulComparisons == 0) {
      return const SceneSimilarityResult(
        passed: false,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        reason: '未能完成有效的 ORB 比对，请检查参考图与拍摄图是否可读。',
        failureType: SceneTransferFailureType.nativeUnavailable,
      );
    }

    final passed = bestScore.similarity >= similarityThreshold;
    final thresholdText = similarityThreshold.toStringAsFixed(2);
    final scoreText = bestScore.similarity.toStringAsFixed(3);
    final reason = passed
        ? '场景校验通过（分数: $scoreText，模板ID: ${bestStyleImageId ?? '未知'}）'
        : '场景相似度过低（$scoreText < $thresholdText），最佳模板ID: ${bestStyleImageId ?? '未知'}，请重新拍摄。';

    return SceneSimilarityResult(
      passed: passed,
      bestStyleImageId: bestStyleImageId,
      bestScore: bestScore.similarity,
      bestGoodMatches: bestScore.inlierCount,
      reason: reason,
      failureType: passed
          ? SceneTransferFailureType.none
          : SceneTransferFailureType.similarityTooLow,
    );
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

  Future<SceneTransferResult> _validateAndUpload({
    required SceneData scene,
    required bool persistResult,
  }) async {
    final similarity = await validateSceneSimilarity(scene);
    if (!similarity.passed) {
      return SceneTransferResult.failure(
        similarity.reason,
        similarity: similarity,
        failureType: similarity.failureType,
      );
    }

    final imagePath = scene.capturedImage;
    if (imagePath == null || imagePath.isEmpty) {
      return SceneTransferResult.failure(
        '请先拍摄该场景',
        similarity: similarity,
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    try {
      final wifiService = _ref.read(wifiServiceProvider);
      final uploadResult = await wifiService.uploadImageFromCamera(
        imagePath,
        sceneId: scene.id,
      );

      if (uploadResult == null) {
        return SceneTransferResult.failure(
          '传输失败，请检查网络连接和服务器设置',
          similarity: similarity,
          failureType: SceneTransferFailureType.uploadFailed,
        );
      }

      if (persistResult) {
        final normalizedResult = Map<String, dynamic>.from(uploadResult);
        await _persistTransferResult(scene: scene, result: normalizedResult);
      }

      return SceneTransferResult.success(similarity: similarity);
    } catch (e) {
      return SceneTransferResult.failure(
        '传输出错: $e',
        similarity: similarity,
        failureType: SceneTransferFailureType.unexpected,
      );
    }
  }

  OrbFfiService? _tryGetOrbFfiService() {
    try {
      return _ref.read(orbFfiServiceProvider);
    } on UnsupportedError catch (e) {
      _ref.read(loggerProvider).w('ORB service unsupported: $e');
      return null;
    } catch (e) {
      _ref.read(loggerProvider).w('ORB service init failed: $e');
      return null;
    }
  }

  Future<List<_ReferenceCandidate>> _loadReferenceCandidates(
    String sceneId,
  ) async {
    final styleService = _ref.read(styleImageServiceProvider);
    final cacheService = _ref.read(localCacheServiceProvider);

    final styleImages = await styleService.getStyleImagesByScene(sceneId);
    if (styleImages.isEmpty) {
      return <_ReferenceCandidate>[];
    }

    final candidates = <_ReferenceCandidate>[];
    for (final style in styleImages) {
      final remoteUrl = styleService.buildImageUrl(style);
      final filename = '${style.id}_${style.filename ?? 'style.jpg'}';
      final localPath = await cacheService.ensureCachedImage(
        url: remoteUrl,
        subdir: 'style_images/$sceneId',
        filename: filename,
      );

      if (localPath == null || localPath.isEmpty) {
        _ref
            .read(loggerProvider)
            .w(
              'Skip style image cache miss: scene=$sceneId, style=${style.id}',
            );
        continue;
      }

      final file = File(localPath);
      if (await file.exists()) {
        candidates.add(
          _ReferenceCandidate(styleImageId: style.id, localPath: localPath),
        );
      }
    }

    return candidates;
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

final class _ReferenceCandidate {
  final String styleImageId;
  final String localPath;

  const _ReferenceCandidate({
    required this.styleImageId,
    required this.localPath,
  });
}
