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
        title: const Text('拍摄记录详情（对比图）'),
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
            icon: const Icon(Icons.fullscreen),
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
            Row(
              children: [
                Text(
                  '场景：${record.sceneName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Text(
                  dateFormat.format(record.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                _buildStatus(record.status),
              ],
            ),
            const SizedBox(height: 16),
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
          const SizedBox(height: 16),
            // 中文注释：核查记录信息（从检测结果获取摘要）
            _buildVerificationInfoPanel(context, ref, record.id),
            const SizedBox(height: 16),
            // 检测详情面板（来自 /api/images/{imageId}/detections）
            _buildDetectionDetailPanel(context, ref, record.id),
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
    String label = status;
    Color bg;
    Color fg;
    switch (status) {
      case '存在缺陷':
      case '异常':
        label = '已检测·异常';
        bg = Colors.red[100]!;
        fg = Colors.red[700]!;
        break;
      case '已检测':
      case '合格':
        label = '已检测·合格';
        bg = Colors.green[100]!;
        fg = Colors.green[700]!;
        break;
      default:
        label = '未检测';
        bg = Colors.grey[200]!;
        fg = Colors.grey[700]!;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 13)),
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
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('样式参考图', style: TextStyle(color: Colors.white, fontSize: 12)),
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
            color: Colors.blue[600],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('用户拍摄图', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
          Text('样式图加载中...', style: TextStyle(color: Colors.black54, fontSize: 12)),
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
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.black45, fontSize: 12)),
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
          Icon(Icons.broken_image, size: 48, color: Colors.orange),
          SizedBox(height: 8),
          Text('图片加载失败', style: TextStyle(color: Colors.black45, fontSize: 12)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_folder, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              const Text('检测详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<DetectionResult?>(
            future: ref.read(detectionServiceProvider).getLatestDetectionByImage(imageId),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('加载失败：${snap.error}', style: const TextStyle(color: Colors.red));
              }
              final res = snap.data;
              final issues = res?.issues ?? const <DetectionIssue>[];
              if (issues.isEmpty) {
                return Text('暂无数据', style: TextStyle(color: Colors.grey[600]));
              }
              return Column(
                children: issues.map((issue) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: issue.severity.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('[${issue.type.displayName} · ${issue.severity.displayName}] ${issue.description}',
                            style: const TextStyle(fontSize: 14)),
                        ),
                        () {
                          final conf = issue.confidence;
                          if (conf == null) return const SizedBox.shrink();
                          return Text('${(conf * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12));
                        }(),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: FutureBuilder<DetectionResult?>(
        future: ref.read(detectionServiceProvider).getLatestDetectionByImage(imageId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
          }
          final res = snap.data;
          if (res == null) {
            return Text('暂无数据', style: TextStyle(color: Colors.grey[600]));
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
                children: const [
                  Icon(Icons.fact_check, size: 18, color: Colors.teal),
                  SizedBox(width: 6),
                  Text('核查记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.confirmation_number, '编号', res.id),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.model_training, '模型', res.detectionType ?? '-'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.category, '对象数量', '$count'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.speed, '平均置信度', avg),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.filter_alt, 'IOU/阈值', '$iou / $thr'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.timer, '推理耗时(ms)', ms),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.verified, '核查结果', verification),
              const SizedBox(height: 8),
              // 缩略图（点击全屏查看处理后图片）
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
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: () {
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
