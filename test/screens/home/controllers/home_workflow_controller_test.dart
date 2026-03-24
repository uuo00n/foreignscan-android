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

    test('当前点位 goodMatches 达阈值时直接返回匹配成功', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          goodMatches: 95,
          similarityPercent: HomeWorkflowController.similarityPercent(95),
        ),
      );

      expect(result.passed, isTrue);
      expect(result.failureType, SceneTransferFailureType.none);
      expect(result.bestGoodMatches, 95);
      expect(result.bestSimilarityPercent, 100);
      expect(result.pointCandidates, isEmpty);
    });

    test('当前点位不通过且其他点位有多个达标时返回前两个候选', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          goodMatches: 65,
          similarityPercent: HomeWorkflowController.similarityPercent(65),
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            goodMatches: 110,
            similarityPercent: HomeWorkflowController.similarityPercent(110),
          ),
          PointMatchCandidate(
            sceneId: 'point-3',
            sceneName: '场景A / 点位3',
            styleImageId: 'style-3',
            goodMatches: 92,
            similarityPercent: HomeWorkflowController.similarityPercent(92),
          ),
          PointMatchCandidate(
            sceneId: 'point-4',
            sceneName: '场景A / 点位4',
            styleImageId: 'style-4',
            goodMatches: 105,
            similarityPercent: HomeWorkflowController.similarityPercent(105),
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.pointCandidatesFound);
      expect(result.pointCandidates.length, 2);
      expect(result.pointCandidates[0].sceneId, 'point-2');
      expect(result.pointCandidates[1].sceneId, 'point-4');
    });

    test('当前点位不通过且仅一个其他点位达标时返回一个候选', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          goodMatches: 70,
          similarityPercent: HomeWorkflowController.similarityPercent(70),
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            goodMatches: 93,
            similarityPercent: HomeWorkflowController.similarityPercent(93),
          ),
          PointMatchCandidate(
            sceneId: 'point-3',
            sceneName: '场景A / 点位3',
            styleImageId: 'style-3',
            goodMatches: 45,
            similarityPercent: HomeWorkflowController.similarityPercent(45),
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.pointCandidatesFound);
      expect(result.pointCandidates.length, 1);
      expect(result.pointCandidates.single.sceneId, 'point-2');
    });

    test('当前点位和其他点位都不达标时返回未匹配', () {
      final result = HomeWorkflowController.decideSceneMatch(
        currentScene: currentScene,
        currentPointMatch: PointMatchCandidate(
          sceneId: 'point-1',
          sceneName: '场景A / 点位1',
          styleImageId: 'style-1',
          goodMatches: 52,
          similarityPercent: HomeWorkflowController.similarityPercent(52),
        ),
        otherPointMatches: [
          PointMatchCandidate(
            sceneId: 'point-2',
            sceneName: '场景A / 点位2',
            styleImageId: 'style-2',
            goodMatches: 80,
            similarityPercent: HomeWorkflowController.similarityPercent(80),
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.failureType, SceneTransferFailureType.similarityTooLow);
      expect(result.reason, '未匹配点位，请重新拍摄');
      expect(result.pointCandidates, isEmpty);
    });
  });

  test('similarityPercent 按 Python 脚本口径计算百分比', () {
    expect(HomeWorkflowController.similarityPercent(45), 50);
    expect(HomeWorkflowController.similarityPercent(90), 100);
    expect(HomeWorkflowController.similarityPercent(120), 100);
  });
}
