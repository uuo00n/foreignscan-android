import 'package:flutter/material.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

/// 统一的AppBar操作按钮组件
class AppBarActions extends StatelessWidget {
  final bool showNewDetection;
  final bool showDetectionResults;
  final VoidCallback? onNewDetectionPressed;
  final VoidCallback? onDetectionResultsPressed;

  const AppBarActions({
    super.key,
    this.showNewDetection = true,
    this.showDetectionResults = true,
    this.onNewDetectionPressed,
    this.onDetectionResultsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showNewDetection) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: onNewDetectionPressed ?? () => _handleNewDetection(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建检测'),
              style: ElevatedButton.styleFrom(
                // 中文注释：使用更协调的浅蓝（accentBlueLight）作为“新建检测”的背景色
                backgroundColor: AppTheme.accentBlueLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
        if (showDetectionResults) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: onDetectionResultsPressed ?? () => _handleDetectionResults(context),
              icon: const Icon(Icons.analytics, size: 18),
              label: const Text('检测结果'),
              style: ElevatedButton.styleFrom(
                // 中文注释：使用靛蓝（accentIndigo）作为“检测结果”的背景色，避免与主色完全一致导致视觉层级混乱
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
        if (showNewDetection || showDetectionResults) const SizedBox(width: 8),
      ],
    );
  }

  void _handleNewDetection(BuildContext context) {
    // 默认处理：显示新建检测的逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请选择检测场景开始检测'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleDetectionResults(BuildContext context) {
    // 默认处理：导航到检测结果页面
    AppRouter.navigateToDetectionResult(
      const DetectionResultArguments(
        imagePath: '',
        detectionType: '',
      ),
    );
  }
}

/// 统一的AppBar标题组件
class AppBarTitle extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const AppBarTitle({
    super.key,
    required this.title,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: style ?? const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 统一的返回按钮组件
class AppBarBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const AppBarBackButton({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: color ?? Colors.white),
      onPressed: onPressed ?? () => Navigator.pop(context),
    );
  }
}