import 'package:flutter/material.dart';
import '../models/scene_data.dart';
import 'scene_tile.dart';

class SceneSelector extends StatelessWidget {
  final List<SceneData> scenes;
  final int selectedIndex;
  final Function(int) onSceneSelected;

  const SceneSelector({
    Key? key,
    required this.scenes,
    required this.selectedIndex,
    required this.onSceneSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '场景选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
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

  Widget _buildPageButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null ? Colors.grey[300] : Colors.grey[200],
        disabledBackgroundColor: Colors.grey[200],
      ),
    );
  }
}
