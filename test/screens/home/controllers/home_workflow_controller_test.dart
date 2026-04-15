import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/screens/home/controllers/home_workflow_controller.dart';

void main() {
  group('HomeWorkflowController.decideSceneMatch', () {
    final currentScene = SceneData(
      id: 'point-1',
      name: '场景A / 点位1',
      roomId: 'room-a',
      roomName: '场景A',
    );

    test('当前点位相似度达到 15.0% 时直接返回匹配成功', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          matchedFeatureCount: 36,
          similarityPercent: 18.4,
          similarityLevel: '极高',
        ),
      );

      expect(result.passed, isTrue);
      expect(result.failureType, SceneTransferFailureType.none);
      expect(result.bestSimilarityPercent, 18.4);
      expect(result.bestSimilarityLevel, '极高');
      expect(result.bestMatchedFeatureCount, 36);
      expect(result.pointCandidates, isEmpty);
    });

    test('当前点位低于 15.0% 时继续返回全图库最相似前两个候选', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          matchedFeatureCount: 20,
          similarityPercent: 12.6,
          similarityLevel: '高',
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            matchedFeatureCount: 25,
            similarityPercent: 14.8,
            similarityLevel: '高',
          ),
          PointMatchCandidate(
            sceneId: 'point-3',
            sceneName: '场景A / 点位3',
            styleImageId: 'style-3',
            matchedFeatureCount: 18,
            similarityPercent: 9.9,
            similarityLevel: '较低',
          ),
          PointMatchCandidate(
            sceneId: 'point-4',
            sceneName: '场景A / 点位4',
            styleImageId: 'style-4',
            matchedFeatureCount: 24,
            similarityPercent: 13.5,
            similarityLevel: '高',
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.pointCandidatesFound);
      expect(result.pointCandidates.length, 2);
      expect(result.pointCandidates[0].sceneId, 'point-2');
      expect(result.pointCandidates[1].sceneId, 'point-4');
      expect(result.bestSimilarityLevel, '高');
    });

    test('当前点位未直通但图库仅一个候选时返回一个候选', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          matchedFeatureCount: 11,
          similarityPercent: 10.5,
          similarityLevel: '高',
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            matchedFeatureCount: 16,
            similarityPercent: 8.2,
            similarityLevel: '较低',
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.pointCandidatesFound);
      expect(result.pointCandidates.length, 1);
      expect(result.pointCandidates.single.sceneId, 'point-2');
    });

    test('当前点位低于 0.1% 时直接返回未匹配且不依赖图库候选', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          matchedFeatureCount: 0,
          similarityPercent: 0.0,
          similarityLevel: '极低',
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            matchedFeatureCount: 15,
            similarityPercent: 11.0,
            similarityLevel: '高',
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.similarityTooLow);
      expect(result.reason, '未匹配点位，请重新拍摄');
      expect(result.bestSimilarityLevel, '极低');
      expect(result.pointCandidates, isEmpty);
    });
  });

  test('similarityLevel 按四档等级规则返回结果', () {
    expect(HomeWorkflowController.similarityLevel(18.0), '极高');
    expect(HomeWorkflowController.similarityLevel(12.0), '高');
    expect(HomeWorkflowController.similarityLevel(3.5), '较低');
    expect(HomeWorkflowController.similarityLevel(0.0), '极低');
  });
}
