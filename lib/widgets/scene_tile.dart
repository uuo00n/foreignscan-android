import 'package:flutter/material.dart';
import '../models/scene_data.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

class SceneTile extends StatelessWidget {
  final SceneData scene;
  final bool isSelected;
  final VoidCallback onTap;

  const SceneTile({
    super.key,
    required this.scene,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.05)
              : AppTheme.surfaceLight,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_rounded,
                size: 24,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // 显示场景名称，不再显示场景ID
            Text(
              scene.name, // 使用名称替代ID
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis, // 名称过长时省略
              maxLines: 1,
            ),
            // 新增：小圆点指示状态
            if (scene.latestStatus != null && scene.latestStatus != 'none')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (scene.latestStatus == '已检测')
                        ? ((scene.hasIssue == true)
                              ? AppTheme.errorColor
                              : AppTheme.successColor)
                        : AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
