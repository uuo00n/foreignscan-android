import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
  pointCandidatesFound,
  similarityTooLow,
  nativeUnavailable,
  uploadFailed,
  unexpected,
}

class PointMatchCandidate {
  final String sceneId;
  final String sceneName;
  final String? styleImageId;
  final int goodMatches;
  final double similarityPercent;

  const PointMatchCandidate({
    required this.sceneId,
    required this.sceneName,
    required this.styleImageId,
    required this.goodMatches,
    required this.similarityPercent,
  });
}

class SceneSimilarityResult {
  final bool passed;
  final String? matchedSceneId;
  final String? matchedSceneName;
  final String? bestStyleImageId;
  final double bestScore;
  final int bestGoodMatches;
  final double bestSimilarityPercent;
  final String reason;
  final SceneTransferFailureType failureType;
  final List<PointMatchCandidate> pointCandidates;

  const SceneSimilarityResult({
    required this.passed,
    required this.matchedSceneId,
    required this.matchedSceneName,
    required this.bestStyleImageId,
    required this.bestScore,
    required this.bestGoodMatches,
    required this.bestSimilarityPercent,
    required this.reason,
    required this.failureType,
    this.pointCandidates = const <PointMatchCandidate>[],
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
  static const int similarityThreshold = 90;
  static const int _maxCandidateCount = 2;
  static const int _orbDistanceThreshold = 50;
  static const int _orbMaxFeatures = 2000;

  final WidgetRef _ref;

  const HomeWorkflowController(this._ref);

  static double similarityPercent(num score) {
    if (similarityThreshold <= 0) {
      return 0;
    }
    return math.min(100.0, score.toDouble() / similarityThreshold * 100);
  }

  @visibleForTesting
  static SceneSimilarityResult decideSceneMatch({
    required SceneData currentScene,
    PointMatchCandidate? currentPointMatch,
    List<PointMatchCandidate> otherPointMatches = const <PointMatchCandidate>[],
  }) {
    if (currentPointMatch != null &&
        currentPointMatch.goodMatches >= similarityThreshold) {
      return SceneSimilarityResult(
        passed: true,
        matchedSceneId: currentScene.id,
        matchedSceneName: currentScene.name,
        bestStyleImageId: currentPointMatch.styleImageId,
        bestScore: currentPointMatch.goodMatches.toDouble(),
        bestGoodMatches: currentPointMatch.goodMatches,
        bestSimilarityPercent: currentPointMatch.similarityPercent,
        reason:
            '匹配成功，相似度 ${currentPointMatch.similarityPercent.toStringAsFixed(1)}%',
        failureType: SceneTransferFailureType.none,
      );
    }

    final filteredCandidates =
        otherPointMatches
            .where((candidate) => candidate.goodMatches >= similarityThreshold)
            .toList()
          ..sort((a, b) {
            final matchCompare = b.goodMatches.compareTo(a.goodMatches);
            if (matchCompare != 0) {
              return matchCompare;
            }
            return a.sceneName.compareTo(b.sceneName);
          });

    final topCandidates = filteredCandidates
        .take(_maxCandidateCount)
        .toList(growable: false);
    if (topCandidates.isNotEmpty) {
      final bestCandidate = topCandidates.first;
      return SceneSimilarityResult(
        passed: false,
        matchedSceneId: bestCandidate.sceneId,
        matchedSceneName: bestCandidate.sceneName,
        bestStyleImageId: bestCandidate.styleImageId,
        bestScore: bestCandidate.goodMatches.toDouble(),
        bestGoodMatches: bestCandidate.goodMatches,
        bestSimilarityPercent: bestCandidate.similarityPercent,
        reason: '已匹配到其他点位，请确认点位并提交，或重新拍摄。',
        failureType: SceneTransferFailureType.pointCandidatesFound,
        pointCandidates: topCandidates,
      );
    }

    final fallbackMatches = currentPointMatch?.goodMatches ?? 0;
    final fallbackPercent = currentPointMatch?.similarityPercent ?? 0.0;
    return SceneSimilarityResult(
      passed: false,
      matchedSceneId: currentScene.id,
      matchedSceneName: currentScene.name,
      bestStyleImageId: currentPointMatch?.styleImageId,
      bestScore: fallbackMatches.toDouble(),
      bestGoodMatches: fallbackMatches,
      bestSimilarityPercent: fallbackPercent,
      reason: '未匹配点位，请重新拍摄',
      failureType: SceneTransferFailureType.similarityTooLow,
    );
  }

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
        matchedSceneId: null,
        matchedSceneName: null,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        bestSimilarityPercent: 0,
        reason: '请先拍摄该场景',
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    final capturedFile = File(imagePath);
    if (!await capturedFile.exists()) {
      return SceneSimilarityResult(
        passed: false,
        matchedSceneId: null,
        matchedSceneName: null,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        bestSimilarityPercent: 0,
        reason: '拍摄图不存在：$imagePath',
        failureType: SceneTransferFailureType.noCapturedImage,
      );
    }

    final currentSceneReferences = await _loadReferenceCandidates(scene.id);
    if (currentSceneReferences.isEmpty) {
      return const SceneSimilarityResult(
        passed: false,
        matchedSceneId: null,
        matchedSceneName: null,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        bestSimilarityPercent: 0,
        reason: '当前场景没有可用的模板参考图，无法校验，请先同步样式图。',
        failureType: SceneTransferFailureType.noReferenceImages,
      );
    }

    final orbService = _tryGetOrbFfiService();
    if (orbService == null) {
      return const SceneSimilarityResult(
        passed: false,
        matchedSceneId: null,
        matchedSceneName: null,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        bestSimilarityPercent: 0,
        reason: '当前设备未启用 ORB 原生校验能力（仅支持 Android）。',
        failureType: SceneTransferFailureType.nativeUnavailable,
      );
    }

    final currentPointComparison = await _compareSceneReferences(
      scene: scene,
      imagePath: imagePath,
      referenceCandidates: currentSceneReferences,
      orbService: orbService,
    );
    if (currentPointComparison.successfulComparisons == 0 ||
        currentPointComparison.match == null) {
      return const SceneSimilarityResult(
        passed: false,
        matchedSceneId: null,
        matchedSceneName: null,
        bestStyleImageId: null,
        bestScore: 0,
        bestGoodMatches: 0,
        bestSimilarityPercent: 0,
        reason: '未能完成有效的 ORB 比对，请检查参考图与拍摄图是否可读。',
        failureType: SceneTransferFailureType.nativeUnavailable,
      );
    }

    final otherPointMatches = <PointMatchCandidate>[];
    for (final peerScene in _findOtherScenesInSameRoom(scene)) {
      final peerReferences = await _loadReferenceCandidates(peerScene.id);
      if (peerReferences.isEmpty) {
        continue;
      }

      final peerComparison = await _compareSceneReferences(
        scene: peerScene,
        imagePath: imagePath,
        referenceCandidates: peerReferences,
        orbService: orbService,
      );
      if (peerComparison.match != null) {
        otherPointMatches.add(peerComparison.match!);
      }
    }

    return decideSceneMatch(
      currentScene: scene,
      currentPointMatch: currentPointComparison.match,
      otherPointMatches: otherPointMatches,
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
        pointId: scene.id,
      );

      if (uploadResult == null || uploadResult['success'] != true) {
        final message = uploadResult != null && uploadResult['message'] != null
            ? uploadResult['message'].toString()
            : '传输失败，请检查网络连接和服务器设置';
        return SceneTransferResult.failure(
          message,
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

  Future<_PointComparisonSummary> _compareSceneReferences({
    required SceneData scene,
    required String imagePath,
    required List<_ReferenceCandidate> referenceCandidates,
    required OrbFfiService orbService,
  }) async {
    PointMatchCandidate? bestMatch;
    var successfulComparisons = 0;

    for (final candidate in referenceCandidates) {
      try {
        final score = await orbService.comparePairAsync(
          capturedPath: imagePath,
          referencePath: candidate.localPath,
          distanceThreshold: _orbDistanceThreshold,
          maxFeatures: _orbMaxFeatures,
        );
        successfulComparisons += 1;

        final pointMatch = PointMatchCandidate(
          sceneId: scene.id,
          sceneName: scene.name,
          styleImageId: candidate.styleImageId,
          goodMatches: score.goodMatches,
          similarityPercent: similarityPercent(score.goodMatches),
        );

        if (bestMatch == null ||
            pointMatch.goodMatches > bestMatch.goodMatches) {
          bestMatch = pointMatch;
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

    return _PointComparisonSummary(
      match: bestMatch,
      successfulComparisons: successfulComparisons,
    );
  }

  List<SceneData> _findOtherScenesInSameRoom(SceneData currentScene) {
    final scenes = _ref.read(homeViewModelProvider).scenes;
    return scenes
        .where(
          (scene) =>
              scene.id != currentScene.id &&
              _isSameRoom(currentScene: currentScene, targetScene: scene),
        )
        .toList();
  }

  bool _isSameRoom({
    required SceneData currentScene,
    required SceneData targetScene,
  }) {
    final currentRoomId = currentScene.roomId.trim();
    final targetRoomId = targetScene.roomId.trim();
    if (currentRoomId.isNotEmpty && targetRoomId.isNotEmpty) {
      return currentRoomId == targetRoomId;
    }

    final currentRoomName = currentScene.roomName.trim();
    final targetRoomName = targetScene.roomName.trim();
    if (currentRoomName.isNotEmpty && targetRoomName.isNotEmpty) {
      return currentRoomName == targetRoomName;
    }

    return false;
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
      pointId: scene.id,
      roomId: scene.roomId,
      roomName: scene.roomName,
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

final class _PointComparisonSummary {
  final PointMatchCandidate? match;
  final int successfulComparisons;

  const _PointComparisonSummary({
    required this.match,
    required this.successfulComparisons,
  });
}
