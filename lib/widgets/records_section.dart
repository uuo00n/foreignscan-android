import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';
import 'dart:io';

class RecordsSection extends StatelessWidget {
  final List<InspectionRecord> records;
  final int currentPage;
  final int recordsPerPage;
  final int totalPages;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  const RecordsSection({
    Key? key,
    required this.records,
    required this.currentPage,
    required this.recordsPerPage,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '拍摄记录',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (records.isNotEmpty)
                Text(
                  '左右滑动查看更多',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      '暂无拍摄记录',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
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
        viewportFraction: 0.35,
        initialPage: currentPage,
      ),
      padEnds: false,
      // 移除onPageChanged回调，避免滑动时的状态更新导致卡顿
      // PageView自身会处理页面切换，不需要额外的状态更新
      
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(records[index]);
      },
    );
  }

  Widget _buildRecordCard(InspectionRecord record) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: record.imagePath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.file(
                      File(record.imagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.orange,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.image,
                      size: 48,
                      color: Colors.orange,
                    ),
                  ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.id} - ${record.sceneName}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  dateFormat.format(record.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null ? Colors.grey[300] : Colors.grey[200],
        disabledBackgroundColor: Colors.grey[200],
      ),
    );
  }
}