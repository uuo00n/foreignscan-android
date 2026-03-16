part of 'record_detail_sections.dart';

class RecordCompareSection extends ConsumerWidget {
  final InspectionRecord record;
  final String heroTagUser;

  const RecordCompareSection({
    super.key,
    required this.record,
    required this.heroTagUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight = (constraints.maxWidth >= 1000)
            ? 420.0
            : (constraints.maxWidth >= 768 ? 380.0 : 280.0);

        if (constraints.maxWidth >= 900) {
          return SizedBox(
            height: panelHeight,
            child: Row(
              children: [
                Expanded(
                  child: _buildStyleImagePanel(context, ref, record.sceneName),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUserImagePanel(
                    context,
                    record.imagePath,
                    heroTagUser,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: panelHeight,
              child: _buildStyleImagePanel(context, ref, record.sceneName),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: panelHeight,
              child: _buildUserImagePanel(
                context,
                record.imagePath,
                heroTagUser,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStyleImagePanel(
    BuildContext context,
    WidgetRef ref,
    String sceneName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 14,
                color: AppTheme.secondaryColor,
              ),
              SizedBox(width: 4),
              Text(
                '样式参考图',
                style: TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<SceneData>>(
            future: ref.read(sceneServiceProvider).getScenes(),
            builder: (context, scenesSnap) {
              if (scenesSnap.connectionState != ConnectionState.done) {
                return _loadingPanel();
              }
              if (scenesSnap.hasError || !scenesSnap.hasData) {
                return _emptyPanel('暂无样式图');
              }

              final scenes = scenesSnap.data!;
              final normalizedTarget = sceneName.trim().toLowerCase();
              final matched = scenes.firstWhere(
                (s) => s.name.trim().toLowerCase() == normalizedTarget,
                orElse: () => SceneData(id: '', name: ''),
              );
              if (matched.id.isEmpty) {
                return _emptyPanel('暂无样式图');
              }

              return FutureBuilder<List<StyleImage>>(
                future: ref
                    .read(styleImageServiceProvider)
                    .getStyleImagesByScene(matched.id),
                builder: (context, imagesSnap) {
                  if (imagesSnap.connectionState != ConnectionState.done) {
                    return _loadingPanel();
                  }

                  final images = imagesSnap.data ?? const <StyleImage>[];
                  if (images.isEmpty) {
                    return _emptyPanel('暂无样式图');
                  }

                  final first = images.first;
                  final heroTag = 'style-image-$sceneName-${first.id}';

                  return FutureBuilder<String?>(
                    future: _getStyleImagePathOrUrl(ref, matched.id, first),
                    builder: (context, pathSnap) {
                      if (pathSnap.connectionState != ConnectionState.done) {
                        return _loadingPanel();
                      }

                      final pathOrUrl = pathSnap.data;
                      if (pathOrUrl == null || pathOrUrl.isEmpty) {
                        return _emptyPanel('暂无样式图');
                      }

                      final isRemote =
                          pathOrUrl.startsWith('http://') ||
                          pathOrUrl.startsWith('https://');

                      final imageWidget = isRemote
                          ? Image.network(
                              pathOrUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stack) =>
                                  _brokenImagePlaceholder(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                          : Image.file(
                              File(pathOrUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stack) =>
                                  _brokenImagePlaceholder(),
                            );

                      return _imagePanel(
                        imageWidget: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullscreenImagePage(
                                  imageUrl: pathOrUrl,
                                  heroTag: heroTag,
                                ),
                              ),
                            );
                          },
                          child: Hero(tag: heroTag, child: imageWidget),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<String?> _getStyleImagePathOrUrl(
    WidgetRef ref,
    String sceneId,
    StyleImage image,
  ) async {
    final styleService = ref.read(styleImageServiceProvider);
    final cacheService = ref.read(localCacheServiceProvider);
    final remoteUrl = styleService.buildImageUrl(image);
    if (remoteUrl.isEmpty) {
      return null;
    }

    final filename = '${image.id}_${image.filename ?? 'style.jpg'}';
    final localPath = await cacheService.buildLocalPath(
      subdir: 'style_images/$sceneId',
      filename: filename,
    );
    final file = File(localPath);
    if (await file.exists()) {
      return localPath;
    }

    final cached = await cacheService.ensureCachedImage(
      url: remoteUrl,
      subdir: 'style_images/$sceneId',
      filename: filename,
    );
    return cached ?? remoteUrl;
  }

  Widget _buildUserImagePanel(
    BuildContext context,
    String imagePath,
    String heroTag,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 14,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                '用户拍摄图',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _imagePanel(
            imageWidget: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImagePage(
                      imageUrl: imagePath,
                      heroTag: heroTag,
                    ),
                  ),
                );
              },
              child: Hero(tag: heroTag, child: _buildImage(imagePath)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePanel({required Widget imageWidget}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageWidget,
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    if (imagePath.isNotEmpty &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          height: 240,
          errorBuilder: (context, error, stack) => _placeholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    if (imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          height: 240,
          errorBuilder: (context, error, stack) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.image, size: 48, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _loadingPanel() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator()),
          SizedBox(height: 8),
          Text(
            '样式图加载中...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _brokenImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: AppTheme.warningColor),
          SizedBox(height: 8),
          Text(
            '图片加载失败',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
