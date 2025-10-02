import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';

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
          Text(
            '拍摄记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          if (records.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(
                  Icons.chevron_left,
                  currentPage > 0 ? onPreviousPage : null,
                ),
                SizedBox(width: 16),
                _buildPageButton(
                  Icons.chevron_right,
                  currentPage < totalPages - 1 ? onNextPage : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    final startIndex = currentPage * recordsPerPage;
    final endIndex = (startIndex + recordsPerPage).clamp(0, records.length);
    final currentRecords = records.sublist(startIndex, endIndex);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: currentRecords.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(currentRecords[index]);
      },
    );
  }

  Widget _buildRecordCard(InspectionRecord record) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      width: 250,
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
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
              child: Center(
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