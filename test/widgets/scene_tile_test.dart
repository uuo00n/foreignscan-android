import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/theme.dart';
import 'package:foreignscan/widgets/scene_tile.dart';

void main() {
  group('SceneTile.resolveIndicatorColor', () {
    test('有检测状态时优先显示检测结果颜色', () {
      final detectedPass = SceneData(
        id: '1',
        name: '点位1',
        latestStatus: '已检测',
        hasIssue: false,
        capturedImage: '/tmp/a.jpg',
        isTransferred: true,
      );
      final detectedFail = SceneData(
        id: '2',
        name: '点位2',
        latestStatus: '已检测',
        hasIssue: true,
        capturedImage: '/tmp/b.jpg',
        isTransferred: true,
      );
      final pending = SceneData(
        id: '3',
        name: '点位3',
        latestStatus: '待检测',
        capturedImage: '/tmp/c.jpg',
      );

      expect(
        SceneTile.resolveIndicatorColor(detectedPass),
        AppTheme.successColor,
      );
      expect(
        SceneTile.resolveIndicatorColor(detectedFail),
        AppTheme.errorColor,
      );
      expect(SceneTile.resolveIndicatorColor(pending), AppTheme.warningColor);
    });

    test('无检测状态时按未拍摄/已拍摄/已上传三态显示', () {
      final notCaptured = SceneData(id: '1', name: '点位1', latestStatus: 'none');
      final captured = SceneData(
        id: '2',
        name: '点位2',
        latestStatus: 'none',
        capturedImage: '/tmp/cap.jpg',
      );
      final transferred = SceneData(
        id: '3',
        name: '点位3',
        latestStatus: 'none',
        capturedImage: '/tmp/up.jpg',
        isTransferred: true,
      );

      expect(
        SceneTile.resolveIndicatorColor(notCaptured),
        AppTheme.textSecondary,
      );
      expect(SceneTile.resolveIndicatorColor(captured), AppTheme.warningColor);
      expect(
        SceneTile.resolveIndicatorColor(transferred),
        AppTheme.successColor,
      );
    });
  });
}
