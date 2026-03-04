part of 'record_detail_sections.dart';

class RecordDetectionDetailPanel extends ConsumerWidget {
  final String imageId;

  const RecordDetectionDetailPanel({super.key, required this.imageId});

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
                child: Icon(
                  Icons.rule_folder_outlined,
                  size: 20,
                  color: AppTheme.errorColor,
                ),
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
            future: ref
                .read(detectionServiceProvider)
                .getLatestDetectionByImage(imageId),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Text(
                  '加载失败：${snap.error}',
                  style: const TextStyle(color: Colors.red),
                );
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
                  final className =
                      issue.metadata?['class']?.toString().toLowerCase() ?? '';
                  final isPass = (className == 'bolts' || className == 'bolt');
                  final statusColor = isPass
                      ? AppTheme.successColor
                      : AppTheme.errorColor;
                  final statusText = isPass ? '合格' : '异常';
                  final objectName =
                      issue.metadata?['class']?.toString() ?? issue.description;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isPass
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                objectName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
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
}
