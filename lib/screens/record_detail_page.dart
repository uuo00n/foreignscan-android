import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/record_detail/widgets/record_detail_sections.dart';

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
    final heroTagUser = record.id.isNotEmpty
        ? 'record-image-${record.id}'
        : 'record-image-${record.imagePath}';

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Text('拍摄记录详情'),
        actions: [
          RecordDetailFullscreenAction(
            record: record,
            heroTagUser: heroTagUser,
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
              RecordDetailHeaderCard(
                record: record,
                formattedTime: dateFormat.format(record.timestamp),
              ),
              const SizedBox(height: 20),
              RecordCompareSection(record: record, heroTagUser: heroTagUser),
              const SizedBox(height: 20),
              RecordVerificationInfoPanel(imageId: record.id),
              const SizedBox(height: 20),
              RecordDetectionDetailPanel(imageId: record.id),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
