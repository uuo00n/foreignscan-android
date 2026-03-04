part of 'record_detail_sections.dart';

class RecordVerificationInfoPanel extends ConsumerWidget {
  final String imageId;

  const RecordVerificationInfoPanel({super.key, required this.imageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        future: ref
            .read(detectionServiceProvider)
            .getLatestDetectionByImage(imageId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final res = snap.data;
          if (res == null) {
            return Center(
              child: Text('暂无核查数据', style: TextStyle(color: Colors.grey[400])),
            );
          }

          final count =
              (res.metadata?['objectCount'] as int?) ?? res.issues.length;
          final isPass = _isPassByIssues(res.issues);
          final verification = isPass ? '合格' : '异常';
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
                    child: Icon(
                      Icons.fact_check_outlined,
                      size: 20,
                      color: AppTheme.secondaryColor,
                    ),
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
                    _buildInfoRow(
                      Icons.confirmation_number_outlined,
                      '编号',
                      res.id,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      Icons.model_training,
                      '模型',
                      res.detectionType ?? '-',
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.category_outlined, '对象数量', '$count'),
                    const Divider(height: 16),
                    _buildInfoRow(
                      Icons.filter_alt_outlined,
                      'IOU/阈值',
                      '$iou / $thr',
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.timer_outlined, '推理耗时(ms)', ms),
                    const Divider(height: 16),
                    _buildInfoRow(
                      Icons.verified_outlined,
                      '核查结果',
                      verification,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (res.imagePath.isNotEmpty) ...[
                const Text(
                  '检测结果图',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                      children: [
                        _buildVerifyImage(res.imagePath),
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

  bool _isPassByIssues(List<DetectionIssue> issues) {
    if (issues.isEmpty) {
      return true;
    }

    for (final issue in issues) {
      final className =
          issue.metadata?['class']?.toString().toLowerCase() ?? '';
      if (className != 'bolts' && className != 'bolt') {
        return false;
      }
    }
    return true;
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        ),
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

  Widget _buildVerifyImage(String path) {
    if (path.isNotEmpty &&
        (path.startsWith('http://') || path.startsWith('https://'))) {
      return Image.network(
        path,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        errorBuilder: (_, __, ___) =>
            SizedBox(height: 160, child: _brokenImagePlaceholder()),
      );
    }

    if (path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.fitWidth,
        width: double.infinity,
        errorBuilder: (_, __, ___) =>
            SizedBox(height: 160, child: _brokenImagePlaceholder()),
      );
    }

    return SizedBox(height: 160, child: _brokenImagePlaceholder());
  }

  Widget _brokenImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: AppTheme.warningColor),
          SizedBox(height: 8),
          Text(
            '图片加载失败',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
