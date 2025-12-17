import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/verification_record.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

import 'package:foreignscan/screens/fullscreen_image_page.dart';

class VerificationList extends StatelessWidget {
  final List<VerificationRecord> records;

  const VerificationList({
    Key? key,
    required this.records,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '核查记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      '请先选择一个实体',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(context, records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 中文注释：渲染核查记录卡片，左侧为缩略图，点击可全屏查看
  Widget _buildRecordCard(BuildContext context, VerificationRecord record) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // 中文注释：将文字信息置顶，图片在下方，占据整行宽度
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 中文注释：顶部文字信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '编号：${record.id}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.verificationResult),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record.verificationResult,
                  style: TextStyle(
                    color: _getStatusTextColor(record.verificationResult),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            record.sceneName,
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
              SizedBox(width: 4),
              Text(
                dateFormat.format(record.timestamp),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 12),
          // 中文注释：下方拍摄图片，点击进入全屏预览
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImagePage(
                      imageUrl: record.imagePath,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: _buildImage(record.imagePath, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path, {BoxFit fit = BoxFit.cover}) {
    final bool isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final Widget error = Container(
      color: AppTheme.backgroundLight,
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 28,
          color: AppTheme.warningColor,
        ),
      ),
    );
    if (isNetwork) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => error,
      );
    } else {
      final file = File(path);
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (_, __, ___) => error,
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已确认':
      case '合格':
        return AppTheme.successColor.withValues(alpha: 0.1);
      case '异常':
        return AppTheme.errorColor.withValues(alpha: 0.1);
      default:
        return AppTheme.textSecondary.withValues(alpha: 0.1);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case '已确认':
      case '合格':
        return AppTheme.successColor;
      case '异常':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
