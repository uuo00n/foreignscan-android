import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';
import 'dart:io';
import 'package:foreignscan/screens/record_detail_page.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

class RecordsSection extends StatelessWidget {
  final List<InspectionRecord> records;
  final int currentPage;
  final int recordsPerPage;
  final int totalPages;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  const RecordsSection({
    super.key,
    required this.records,
    required this.currentPage,
    required this.recordsPerPage,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280, // Increased height to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Icons.history_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '拍摄记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (records.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swipe_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '左右滑动',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: AppTheme.dividerColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无拍摄记录',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return PageView.builder(
      controller: PageController(
        viewportFraction: 0.4,
        initialPage: currentPage,
      ),
      padEnds: false,
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(context, records[index]);
      },
    );
  }

  /// 构建单条拍摄记录卡片
  /// 中文说明：
  /// - 点击卡片跳转到“拍摄记录详情页”，查看大图与详细信息
  Widget _buildRecordCard(BuildContext context, InspectionRecord record) {
    final dateFormat = DateFormat('MM-dd HH:mm');

    return Container(
      margin: const EdgeInsets.only(
        right: 12,
        bottom: 8,
      ), // Added bottom margin for shadow
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点击进入详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordDetailPage(record: record),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: _buildImage(record.imagePath),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 文案优化：拍摄记录中不显示ID，仅展示场景名称
                      Text(
                        record.sceneName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dateFormat.format(record.timestamp),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusChip(record.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 中文注释：统一状态标签映射与颜色（首页与详情页保持一致）
  Widget _buildStatusChip(String rawStatus) {
    final statusType = InspectionStatusTypeParser.fromRaw(rawStatus);
    final String label;
    Color bg;
    Color fg;
    IconData icon;

    switch (statusType) {
      case InspectionStatusType.abnormal:
        label = '异常';
        bg = AppTheme.errorColor.withValues(alpha: 0.1);
        fg = AppTheme.errorColor;
        icon = Icons.warning_amber_rounded;
        break;
      case InspectionStatusType.detected:
      case InspectionStatusType.qualified:
      case InspectionStatusType.verified:
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border:
            statusType == InspectionStatusType.pending ||
                statusType == InspectionStatusType.unknown
            ? Border.all(color: AppTheme.dividerColor)
            : Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
    if (imagePath.isNotEmpty &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) {
            return Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: 32,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            );
          },
        ),
      );
    }

    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) {
            return Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: 32,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            );
          },
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 32,
        color: AppTheme.dividerColor,
      ),
    );
  }
}
