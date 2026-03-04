part of 'record_detail_sections.dart';

class RecordDetailHeaderCard extends StatelessWidget {
  final InspectionRecord record;
  final String formattedTime;

  const RecordDetailHeaderCard({
    super.key,
    required this.record,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.place_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.sceneName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildStatus(record.status),
        ],
      ),
    );
  }

  Widget _buildStatus(String status) {
    String label = status;
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case '存在缺陷':
      case '异常':
        label = '异常';
        bg = AppTheme.errorColor.withValues(alpha: 0.1);
        fg = AppTheme.errorColor;
        icon = Icons.warning_amber_rounded;
        break;
      case '已检测':
      case '合格':
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: status == '未检测'
            ? Border.all(color: AppTheme.dividerColor)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
