import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/fullscreen_image_page.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/style_image_service.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/style_image.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/detection_service.dart';
import 'package:foreignscan/models/detection_result.dart';

import 'package:foreignscan/core/theme/app_theme.dart';

/// 拍摄记录详情页（对比图展示）
/// 中文说明：
/// - 左侧展示“场景样式图”（参考图，来自后端样式图接口）；
/// - 右侧展示“用户拍摄/上传的图片”；
/// - 两侧图片均支持点击进入全屏查看，带 Hero 动效；
class RecordDetailPage extends ConsumerWidget {
  final InspectionRecord record;

  const RecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final heroTagUser = record.id.isNotEmpty ? 'record-image-${record.id}' : 'record-image-${record.imagePath}';

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
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
                    heroTag: heroTagUser,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: '全屏查看',
          ),
        ],
      ),
      // 中文注释：为避免内容占满全屏导致无法上下滚动，这里改为使用可滚动容器
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部标题与说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
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
                            Icons.place_rounded,
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
                                record.sceneName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateFormat.format(record.timestamp),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatus(record.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // 对比图区域：左侧样式图（参考图） + 右侧用户图片（限定高度，整体页面可上下滚动）
              SizedBox(
                height: 360,
                child: Row(
                  children: [
                    // 左侧：样式图
                    Expanded(
                      child: _buildStyleImagePanel(context, ref, record.sceneName),
                    ),
                    const SizedBox(width: 16),
                    // 右侧：用户拍摄图片
                    Expanded(
                      child: _buildUserImagePanel(context, record.imagePath, heroTagUser),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 中文注释：核查记录信息（从检测结果获取摘要）
              _buildVerificationInfoPanel(context, ref, record.id),
              const SizedBox(height: 20),
              // 检测详情面板（来自 /api/images/{imageId}/detections）
              _buildDetectionDetailPanel(context, ref, record.id),
              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
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
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.image, size: 48, color: AppTheme.textSecondary),
      ),
    );
  }

  /// 信息行：左侧图标 + 标签 + 值
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
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
    String label = status;
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case '存在缺陷':
      case '异常':
        label = '异常';
        bg = AppTheme.errorColor.withValues(alpha: 0.1);
        fg = AppTheme.errorColor;
        icon = Icons.warning_amber_rounded;
        break;
      case '已检测':
      case '合格':
        label = '合格';
        bg = AppTheme.successColor.withValues(alpha: 0.1);
        fg = AppTheme.successColor;
        icon = Icons.check_circle_outline;
        break;
      default:
        label = '未检测';
        bg = AppTheme.surfaceLight;
        fg = AppTheme.textSecondary;
        icon = Icons.help_outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(6),
        border: status == '未检测' ? Border.all(color: AppTheme.dividerColor) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 左侧样式图（参考图）面板
  /// 中文注释：
  /// - 逻辑：先从场景列表中找到与记录场景名匹配的场景ID；再请求该场景的样式图列表；
  ///   若获取到样式图，取首图作为参考图；失败或为空则展示“暂无样式图”。
  /// - 交互：点击样式图进入全屏查看（支持缩放/拖拽），带 Hero 动效。
  Widget _buildStyleImagePanel(BuildContext context, WidgetRef ref, String sceneName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined, size: 14, color: AppTheme.secondaryColor),
              const SizedBox(width: 4),
              const Text('样式参考图', style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<SceneData>>(
            future: ref.read(sceneServiceProvider).getScenes(),
            builder: (context, scenesSnap) {
              if (scenesSnap.connectionState != ConnectionState.done) {
                return _loadingPanel();
              }
              if (scenesSnap.hasError || !scenesSnap.hasData) {
                return _emptyPanel('暂无样式图');
              }
              final scenes = scenesSnap.data!;
              // 根据场景名称匹配到场景ID（中文注释：若名称不唯一，则取第一个匹配项）
              final normalizedTarget = sceneName.trim().toLowerCase();
              final matched = scenes.firstWhere(
                (s) => s.name.trim().toLowerCase() == normalizedTarget,
                orElse: () => SceneData(id: '', name: ''),
              );
              if (matched.id.isEmpty) {
                return _emptyPanel('暂无样式图');
              }

              return FutureBuilder<List<StyleImage>>(
                future: ref.read(styleImageServiceProvider).getStyleImagesByScene(matched.id),
                builder: (context, imagesSnap) {
                  if (imagesSnap.connectionState != ConnectionState.done) {
                    return _loadingPanel();
                  }
                  final images = imagesSnap.data ?? const <StyleImage>[];
                  if (images.isEmpty) {
                    return _emptyPanel('暂无样式图');
                  }
                  // 取第一张样式图作为参考图，并优先使用本地缓存路径
                  final first = images.first;
                  final heroTag = 'style-image-$sceneName-${first.id}';
                  return FutureBuilder<String?>(
                    future: _getStyleImagePathOrUrl(ref, matched.id, first),
                    builder: (context, pathSnap) {
                      if (pathSnap.connectionState != ConnectionState.done) {
                        return _loadingPanel();
                      }
                      final pathOrUrl = pathSnap.data;
                      if (pathOrUrl == null || pathOrUrl.isEmpty) {
                        return _emptyPanel('暂无样式图');
                      }

                      final isRemote = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
                      final imageWidget = isRemote
                          ? Image.network(
                              pathOrUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stack) => _brokenImagePlaceholder(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : Image.file(
                              File(pathOrUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stack) => _brokenImagePlaceholder(),
                            );

                      return _imagePanel(
                        context: context,
                        imageWidget: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullscreenImagePage(
                                  imageUrl: pathOrUrl,
                                  heroTag: heroTag,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: heroTag,
                            child: imageWidget,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 解析样式图的本地缓存路径或远程URL（优先返回本地路径）
  /// 中文注释：
  /// - 先构造本地缓存路径：style_images/<sceneId>/<styleId>_<filename或style.jpg>
  /// - 若本地文件存在，直接返回本地路径；
  /// - 否则尝试下载缓存（ensureCachedImage），成功则返回本地路径；
  /// - 最后兜底返回远程URL。
  Future<String?> _getStyleImagePathOrUrl(WidgetRef ref, String sceneId, StyleImage image) async {
    final styleService = ref.read(styleImageServiceProvider);
    final cacheService = ref.read(localCacheServiceProvider);
    final remoteUrl = styleService.buildImageUrl(image);
    if (remoteUrl.isEmpty) return null;

    final filename = '${image.id}_${image.filename ?? 'style.jpg'}';
    final localPath = await cacheService.buildLocalPath(
      subdir: 'style_images/$sceneId',
      filename: filename,
    );
    final file = File(localPath);
    if (file.existsSync()) {
      return localPath; // 已缓存
    }
    // 尝试缓存下载
    final cached = await cacheService.ensureCachedImage(
      url: remoteUrl,
      subdir: 'style_images/$sceneId',
      filename: filename,
    );
    return cached ?? remoteUrl;
  }

  /// 右侧用户图片面板
  /// 中文注释：兼容网络图片与本地图片，并支持点击进入全屏查看。
  Widget _buildUserImagePanel(BuildContext context, String imagePath, String heroTag) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text('用户拍摄图', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _imagePanel(
            context: context,
            imageWidget: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImagePage(
                      imageUrl: imagePath,
                      heroTag: heroTag,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: _buildImage(imagePath),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 图片容器面板：统一封装边框与圆角风格
  Widget _imagePanel({required BuildContext context, required Widget imageWidget}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageWidget,
      ),
    );
  }

  /// 加载中面板占位
  Widget _loadingPanel() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator()),
          SizedBox(height: 8),
          Text('样式图加载中...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 空面板占位
  Widget _emptyPanel(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 破损图片占位图
  Widget _brokenImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.broken_image, size: 48, color: AppTheme.warningColor),
          SizedBox(height: 8),
          Text('图片加载失败', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 检测详情面板：按图片ID查询并展示检测问题列表
  /// 中文注释：
  /// - 无数据时显示“暂无数据”；
  /// - 失败时显示错误提示；
  /// - 列表展示每条问题的类型、严重程度与描述。
  Widget _buildDetectionDetailPanel(BuildContext context, WidgetRef ref, String imageId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.rule_folder_outlined, size: 20, color: AppTheme.errorColor),
              ),
              const SizedBox(width: 12),
              const Text(
                '检测详情',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<DetectionResult?>(
            future: ref.read(detectionServiceProvider).getLatestDetectionByImage(imageId),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator())),
                );
              }
              if (snap.hasError) {
                return Text('加载失败：${snap.error}', style: const TextStyle(color: Colors.red));
              }
              final res = snap.data;
              final issues = res?.issues ?? const <DetectionIssue>[];
              if (issues.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '暂无检测异常',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ),
                );
              }
              return Column(
                children: issues.map((issue) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: issue.severity.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: issue.severity.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: issue.severity.color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${issue.type.displayName} · ${issue.severity.displayName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: issue.severity.color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                issue.description,
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        if (issue.confidence != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              '${(issue.confidence! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 核查记录信息面板：展示模型、对象数、置信度、核查结果与缩略图
  Widget _buildVerificationInfoPanel(BuildContext context, WidgetRef ref, String imageId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<DetectionResult?>(
        future: ref.read(detectionServiceProvider).getLatestDetectionByImage(imageId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
          }
          final res = snap.data;
          if (res == null) {
            return Center(
              child: Text('暂无核查数据', style: TextStyle(color: Colors.grey[400])),
            );
          }
          final count = (res.metadata?['objectCount'] as int?) ?? res.issues.length;
          final verification = count > 0 ? '异常' : '已确认';
          final avg = res.confidence != null ? '${(res.confidence! * 100).toStringAsFixed(0)}%' : '-';
          final iou = res.metadata?['iouThreshold']?.toString() ?? '-';
          final thr = res.metadata?['confidenceThreshold']?.toString() ?? '-';
          final ms = res.metadata?['inferenceTimeMs']?.toString() ?? '-';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fact_check_outlined, size: 20, color: AppTheme.secondaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '核查记录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.confirmation_number_outlined, '编号', res.id),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.model_training, '模型', res.detectionType ?? '-'),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.category_outlined, '对象数量', '$count'),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.speed, '平均置信度', avg),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.filter_alt_outlined, 'IOU/阈值', '$iou / $thr'),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.timer_outlined, '推理耗时(ms)', ms),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.verified_outlined, '核查结果', verification),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 缩略图（点击全屏查看处理后图片）
              if (res.imagePath.isNotEmpty) ...[
                const Text(
                  '检测结果图',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullscreenImagePage(
                          imageUrl: res.imagePath,
                          heroTag: 'verify-thumb-${res.id}',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        () {
                          final path = res.imagePath;
                          if (path.isNotEmpty && (path.startsWith('http://') || path.startsWith('https://'))) {
                            return Image.network(path, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
                            );
                          }
                          if (path.isNotEmpty) {
                            final f = File(path);
                            return Image.file(f, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
                            );
                          }
                          return _brokenImagePlaceholder();
                        }(),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
