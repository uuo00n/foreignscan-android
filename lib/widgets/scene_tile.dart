import 'package:flutter/material.dart';
import '../models/scene_data.dart';

class SceneTile extends StatelessWidget {
  final SceneData scene;
  final bool isSelected;
  final VoidCallback onTap;

  const SceneTile({
    Key? key,
    required this.scene,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 32, color: Colors.grey[600]),
            SizedBox(height: 4),
            // 显示场景名称，不再显示场景ID
            Text(
              scene.name, // 使用名称替代ID
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis, // 名称过长时省略
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
