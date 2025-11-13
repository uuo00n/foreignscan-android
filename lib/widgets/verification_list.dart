import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/verification_record.dart';

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '核查记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
  Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      '请先选择一个实体',
                      style: TextStyle(
                        color: Colors.grey,
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 中文注释：顶部文字信息
          Text(
            '编号：${record.id}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(record.sceneName, style: TextStyle(fontSize: 13)),
          SizedBox(height: 4),
          Text(
            '时间：${dateFormat.format(record.timestamp)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          SizedBox(height: 4),
          Text('状态：${record.verificationResult}', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          // 中文注释：下方拍摄图片，点击进入全屏预览
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) {
                    return Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 5.0,
                              child: Image.network(
                                record.imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    '图片加载失败',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: Image.network(
                  record.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 28,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已确认':
        return Colors.green[100]!;
      case '异常':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case '已确认':
        return Colors.green[700]!;
      case '异常':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}
