import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/models/scene_data.dart';

void main() {
  group('SceneData', () {
    test('skipSimilarityCheck 默认值为 false', () {
      final scene = SceneData(id: '1', name: '场景1');
      expect(scene.skipSimilarityCheck, isFalse);
    });

    test('toJson/fromJson 可以保留 skipSimilarityCheck', () {
      final original = SceneData(
        id: '1',
        name: '场景1',
        skipSimilarityCheck: true,
      );
      final parsed = SceneData.fromJson(original.toJson());
      expect(parsed.skipSimilarityCheck, isTrue);
    });

    test('copyWith 支持更新 skipSimilarityCheck', () {
      final scene = SceneData(id: '1', name: '场景1');
      final updated = scene.copyWith(skipSimilarityCheck: true);
      expect(updated.skipSimilarityCheck, isTrue);
    });
  });
}
