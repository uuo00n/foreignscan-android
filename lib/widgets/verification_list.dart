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
                      '暂无核查记录',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(VerificationRecord record) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          // 左侧图片
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.grey[800],
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 32,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // 右侧信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.id} - ${record.sceneName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  dateFormat.format(record.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.verificationResult),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.verificationResult,
                    style: TextStyle(
                      color: _getStatusTextColor(record.verificationResult),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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