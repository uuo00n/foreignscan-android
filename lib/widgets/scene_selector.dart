import 'package:flutter/material.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import '../models/scene_data.dart';
import 'scene_tile.dart';

class SceneSelector extends StatelessWidget {
  final List<SceneData> scenes;
  final int selectedIndex;
  final Function(int) onSceneSelected;
  final double? panelWidth;

  const SceneSelector({
    super.key,
    required this.scenes,
    required this.selectedIndex,
    required this.onSceneSelected,
    this.panelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: panelWidth ?? 280,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '场景选择',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Changed to 3 for better visibility
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: scenes.length,
              itemBuilder: (context, index) {
                return SceneTile(
                  scene: scenes[index],
                  isSelected: index == selectedIndex,
                  onTap: () => onSceneSelected(index),
                );
              },
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
