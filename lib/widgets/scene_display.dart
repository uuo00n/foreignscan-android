// ==================== lib/widgets/scene_display.dart ====================
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/scene_data.dart';
import '../screens/fullscreen_image_page.dart';

class SceneDisplay extends StatelessWidget {
  final SceneData scene;
  final VoidCallback onCaptureClick;
  final VoidCallback onConfirmTransfer;
  final String? referenceImageUrl; // 模板参考图URL（来自后端样式图接口）
  final bool isReferenceLoading; // 模板参考图加载中标记（用于展示加载动画）

  const SceneDisplay({
    Key? key,
    required this.scene,
    required this.onCaptureClick,
    required this.onConfirmTransfer,
    this.referenceImageUrl,
    this.isReferenceLoading = false,
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
            color: scene.isTransferred ? Colors.green[200]! : Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: scene.isTransferred ? Colors.green : Colors.grey[300]!,
          width: scene.isTransferred ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '场景：${scene.id} - ${scene.name}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (scene.isTransferred) ...[
                SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  '已传输',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildReferenceImage(context)),
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
              icon: Icon(scene.isTransferred ? Icons.refresh : Icons.check_circle),
              label: Text(scene.isTransferred ? '重新传输' : '确认传输'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scene.isTransferred ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 模板参考图区域
  /// - 当存在 referenceImageUrl 时，支持点击全屏查看
  /// - 加入 Hero 动画以提升动效体验
  Widget _buildReferenceImage(BuildContext context) {
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
            // 中文说明：
            // 优先展示“加载动画”；若非加载且有URL/路径则展示图片；否则展示占位
            child: isReferenceLoading
                ? const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(),
                    ),
                  )
                : (referenceImageUrl != null && referenceImageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            final pathOrUrl = referenceImageUrl!;
                            // 点击参考图 -> 进入全屏查看页面（兼容本地文件与网络图片）
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullscreenImagePage(
                                  imageUrl: pathOrUrl,
                                  heroTag: pathOrUrl, // 使用路径或URL作为Hero标签，保证唯一性
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: referenceImageUrl!,
                            child: _buildReferenceImageContent(referenceImageUrl!),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 8),
                            Text('暂无模板参考图', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  /// 构建参考图内容：
  /// 中文注释：
  /// - 若为 http/https 则使用 Image.network；
  /// - 否则尝试当成本地文件路径使用 Image.file；
  /// - 加载失败时显示兜底占位，避免多层嵌套逻辑。
  Widget _buildReferenceImageContent(String pathOrUrl) {
    final isNetwork = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        pathOrUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? (loadingProgress.cumulativeBytesLoaded /
                      (loadingProgress.expectedTotalBytes ?? 1))
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                SizedBox(height: 8),
                Text('参考图加载失败', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        },
      );
    }

    // 尝试作为本地文件路径
    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                SizedBox(height: 8),
                Text('参考图加载失败', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        },
      );
    }

    // 兜底占位
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 64, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text('暂无模板参考图', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
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