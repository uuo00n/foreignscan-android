// ==================== lib/widgets/scene_display.dart ====================
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:foreignscan/core/theme/app_theme.dart';
import '../models/scene_data.dart';
import '../screens/fullscreen_image_page.dart';

class SceneDisplay extends StatelessWidget {
  final SceneData scene;
  final VoidCallback onCaptureClick;
  final VoidCallback onConfirmTransfer;
  final VoidCallback? onTransferAll; // 中文注释：新增“全部传输”按钮回调，父组件实现批量传输逻辑
  final String? referenceImageUrl; // 模板参考图URL（来自后端样式图接口）
  final bool isReferenceLoading; // 模板参考图加载中标记（用于展示加载动画）

  const SceneDisplay({
    Key? key,
    required this.scene,
    required this.onCaptureClick,
    required this.onConfirmTransfer,
    this.onTransferAll,
    this.referenceImageUrl,
    this.isReferenceLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 中文注释：统一两个操作按钮的公共样式，避免尺寸不一致（统一最小尺寸与内边距）
    final ButtonStyle commonButtonStyle = ElevatedButton.styleFrom(
      foregroundColor: AppTheme.textInverse,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(120, 40), // 统一最小宽高，避免大小不一致
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scene.isTransferred 
                ? AppTheme.successColor.withValues(alpha: 0.1) 
                : AppTheme.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: scene.isTransferred ? AppTheme.successColor.withValues(alpha: 0.5) : Colors.transparent,
          width: scene.isTransferred ? 1.5 : 0,
        ),
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
                  Icons.image_search_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前场景',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${scene.id} - ${scene.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (scene.isTransferred) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '已传输',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 新增：检测状态展示
              if (scene.latestStatus != null && scene.latestStatus != 'none') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(scene).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(scene),
                        size: 14,
                        color: _getStatusColor(scene),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(scene),
                        style: TextStyle(
                          color: _getStatusColor(scene),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildReferenceImage(context)),
                SizedBox(width: 20),
                Expanded(child: _buildCaptureArea(context)),
              ],
            ),
          ),
          SizedBox(height: 24),
          // 中文注释：操作按钮行（右对齐）：左侧“全部传输”，右侧“确认/重新传输”
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onTransferAll != null) ...[
                ElevatedButton.icon(
                  onPressed: onTransferAll,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('全部传输'),
                  style: commonButtonStyle.copyWith(
                    // 中文注释：仅改变背景色，其他尺寸样式保持一致
                    backgroundColor: MaterialStateProperty.all(AppTheme.accentIndigo),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              ElevatedButton.icon(
                onPressed: onConfirmTransfer,
                icon: Icon(scene.isTransferred ? Icons.refresh_rounded : Icons.check_circle_outline),
                label: Text(scene.isTransferred ? '重新传输' : '确认传输'),
                style: commonButtonStyle.copyWith(
                  backgroundColor: MaterialStateProperty.all(
                    scene.isTransferred ? AppTheme.warningColor : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SceneData scene) {
    if (scene.latestStatus == '已检测') {
      return (scene.hasIssue == true) ? AppTheme.errorColor : AppTheme.successColor;
    }
    return AppTheme.warningColor; // 待检测
  }

  IconData _getStatusIcon(SceneData scene) {
    if (scene.latestStatus == '已检测') {
      return (scene.hasIssue == true) ? Icons.error_outline : Icons.check_circle_outline;
    }
    return Icons.hourglass_empty;
  }

  String _getStatusText(SceneData scene) {
    if (scene.latestStatus == '已检测') {
      return (scene.hasIssue == true) ? '检测未通过' : '检测通过';
    }
    return '待检测';
  }

  /// 模板参考图区域
  /// - 当存在 referenceImageUrl 时，支持点击全屏查看
  /// - 加入 Hero 动画以提升动效体验
  Widget _buildReferenceImage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              '模板参考图',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            // 中文说明：
            // 优先展示“加载动画”；若非加载且有URL/路径则展示图片；否则展示占位
            child: isReferenceLoading
                ? Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                  )
                : (referenceImageUrl != null && referenceImageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: referenceImageUrl!,
                                child: _buildReferenceImageContent(referenceImageUrl!),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 48, color: AppTheme.dividerColor),
                            SizedBox(height: 12),
                            Text(
                              '暂无模板参考图',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
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
                Icon(Icons.broken_image, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                SizedBox(height: 8),
                Text('参考图加载失败', style: TextStyle(color: AppTheme.textSecondary)),
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
                Icon(Icons.broken_image, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                SizedBox(height: 8),
                Text('参考图加载失败', style: TextStyle(color: AppTheme.textSecondary)),
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
          Icon(Icons.image, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          SizedBox(height: 8),
          Text('暂无模板参考图', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCaptureArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '实时拍摄',
            style: TextStyle(color: AppTheme.textInverse, fontSize: 12),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: scene.capturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          // 中文注释：点击实时拍摄区域中的已拍图片，进入全屏查看（支持缩放/拖拽）
                          onTap: () {
                            final path = scene.capturedImage!; // 已拍摄图片的本地路径
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullscreenImagePage(
                                  imageUrl: path,
                                  heroTag: path, // 中文注释：使用图片路径作为Hero标签，确保唯一性
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: scene.capturedImage!,
                            child: Image.file(
                              File(scene.capturedImage!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      )
                    : Center(
                  child: Text(
                    '请拍摄该场景',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.camera_alt, color: AppTheme.textInverse),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}