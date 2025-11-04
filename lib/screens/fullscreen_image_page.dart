// ==================== lib/screens/fullscreen_image_page.dart ====================
import 'package:flutter/material.dart';

/// 全屏图片查看页面
/// - 支持网络图片的缩放与拖拽查看（InteractiveViewer）
/// - 轻触返回或点击右上角关闭按钮关闭页面
class FullscreenImagePage extends StatelessWidget {
  final String imageUrl; // 图片的完整URL
  final String? heroTag; // Hero 动画的标签（与列表中的相同）

  const FullscreenImagePage({
    Key? key,
    required this.imageUrl,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // 使用 Stack 叠加关闭按钮与图片区域
        child: Stack(
          children: [
            // 外层包裹 GestureDetector：轻触任意空白区域返回
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                // 使用 InteractiveViewer 支持缩放与拖拽查看
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: heroTag != null
                      ? Hero(
                          tag: heroTag!,
                          child: _buildNetworkImage(),
                        )
                      : _buildNetworkImage(),
                ),
              ),
            ),
            // 右上角关闭按钮，提供明确的关闭入口
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '关闭',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建网络图片组件
  /// - 带加载中指示与加载失败兜底
  Widget _buildNetworkImage() {
    return Image.network(
      imageUrl,
      fit: BoxFit.contain, // 全屏查看时保持完整显示
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child; // 已完成加载，直接返回图片
        // 加载中展示进度圈
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // 加载失败时展示提示
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image, size: 64, color: Colors.white70),
            SizedBox(height: 12),
            Text(
              '图片加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        );
      },
    );
  }
}