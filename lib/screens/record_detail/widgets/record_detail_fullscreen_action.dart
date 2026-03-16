part of 'record_detail_sections.dart';

class RecordDetailFullscreenAction extends ConsumerWidget {
  final InspectionRecord record;
  final String heroTagUser;

  const RecordDetailFullscreenAction({
    super.key,
    required this.record,
    required this.heroTagUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DetectionResult?>(
      future: ref
          .read(detectionServiceProvider)
          .getLatestDetectionByImage(record.id),
      builder: (context, snap) {
        final res = snap.data;
        final targetUrl = (res != null && res.imagePath.isNotEmpty)
            ? res.imagePath
            : record.imagePath;
        final targetHeroTag = (res != null && res.imagePath.isNotEmpty)
            ? 'verify-thumb-${res.id}'
            : heroTagUser;

        return IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImagePage(
                  imageUrl: targetUrl,
                  heroTag: targetHeroTag,
                ),
              ),
            );
          },
          icon: const Icon(Icons.fullscreen_rounded),
          tooltip: '全屏查看',
        );
      },
    );
  }
}
