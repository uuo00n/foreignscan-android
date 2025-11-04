import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/fullscreen_image_page.dart';

/// 拍摄记录详情页
/// 中文说明：
/// - 展示单条拍摄记录的图片（支持网络/本地）、场景名称、时间与状态
/// - 支持点击图片进入全屏查看（可缩放/拖动），并使用 Hero 动效
class RecordDetailPage extends StatelessWidget {
  final InspectionRecord record;

  const RecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final heroTag = record.id.isNotEmpty ? 'record-image-${record.id}' : 'record-image-${record.imagePath}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('拍摄记录详情'),
        actions: [
          // 右上角全屏查看按钮
          IconButton(
            onPressed: () {
              // 点击进入全屏查看页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenImagePage(
                    imageUrl: record.imagePath,
                    heroTag: heroTag,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen),
            tooltip: '全屏查看',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部图片：点击也可以进入全屏查看
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenImagePage(
                    imageUrl: record.imagePath,
                    heroTag: heroTag,
                  ),
                ),
              );
            },
            child: Hero(
              tag: heroTag,
              child: _buildImage(record.imagePath),
            ),
          ),
          const SizedBox(height: 16),
          // 信息卡片：场景名称、时间、状态
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.location_on, '场景', record.sceneName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, '时间', dateFormat.format(record.timestamp)),
                  const SizedBox(height: 8),
                  _buildStatus(record.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片组件：兼容网络图片与本地图片
  /// 中文注释：
  /// - 为避免多层嵌套，提前返回策略：
  ///   1) URL -> Image.network
  ///   2) 本地存在 -> Image.file
  ///   3) 其他 -> 占位图标
  Widget _buildImage(String imagePath) {
    // 网络图片
    if (imagePath.isNotEmpty && (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          height: 240,
          errorBuilder: (context, error, stack) {
            return _placeholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: 240,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    // 本地图片
    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            height: 240,
            errorBuilder: (context, error, stack) {
              return _placeholder();
            },
          ),
        );
      }
    }

    // 占位
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.orange),
      ),
    );
  }

  /// 信息行：左侧图标 + 标签 + 值
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// 状态标签：根据不同状态展示不同颜色
  Widget _buildStatus(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case '已检测':
        bg = Colors.blue[100]!;
        fg = Colors.blue[700]!;
        break;
      case '存在缺陷':
        bg = Colors.red[100]!;
        fg = Colors.red[700]!;
        break;
      default:
        bg = Colors.green[100]!;
        fg = Colors.green[700]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(color: fg, fontSize: 13)),
    );
  }
}