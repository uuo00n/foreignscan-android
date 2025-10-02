// ==================== lib/widgets/scene_display.dart ====================
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/scene_data.dart';

class SceneDisplay extends StatelessWidget {
  final SceneData scene;
  final VoidCallback onCaptureClick;
  final VoidCallback onConfirmTransfer;

  const SceneDisplay({
    Key? key,
    required this.scene,
    required this.onCaptureClick,
    required this.onConfirmTransfer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
            '场景：${scene.id} - ${scene.name}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildReferenceImage()),
                SizedBox(width: 16),
                Expanded(child: _buildCaptureArea()),
              ],
            ),
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onConfirmTransfer,
              icon: Icon(Icons.check_circle),
              label: Text('确认传输'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '模板参考图',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Icon(Icons.image, size: 64, color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '实时拍摄',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: scene.capturedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(scene.capturedImage!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
                    : Center(
                  child: Text(
                    '请拍摄该场景',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: onCaptureClick,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}