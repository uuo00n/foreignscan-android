part of 'detection_result_screen.dart';

extension _DetectionResultWidgets on _DetectionResultScreenState {
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      ),
      leading: const AppBarBackButton(),
      title: const AppBarTitle(title: '检测结果'),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildDetectionResultArea() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Text(
          '加载失败：$errorMessage',
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      );
    }

    final isDetailMode =
        widget.arguments?.imageId != null &&
        widget.arguments!.imageId!.isNotEmpty;
    if (isDetailMode) {
      final hasDetail =
          (currentResult != null && currentResult!.issues.isNotEmpty) ||
          imageIssues.isNotEmpty;
      if (!hasDetail) {
        return Center(
          child: Text(
            '暂无数据',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
          ),
        );
      }
      return _buildDetectionDetailView();
    }

    if (detectionList.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }
    return _buildDetectionListView();
  }

  Widget _buildDetectionDetailView() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${currentResult?.id ?? ''} - ${currentResult?.sceneName ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _buildImageOrPlaceholder(
                        currentResult?.imagePath ?? '',
                      ),
                    ),
                  ),
                ),
                ...((currentResult?.issues ?? imageIssues)).map(
                  _buildDetectionBox,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '检测到 ${(currentResult?.issues.length ?? imageIssues.length)} 个对象',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check_circle),
                label: const Text('确认核查'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionListView() {
    return Container(
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
        children: [
          // 顶部同步按钮（混合本地/网络同步，离线展示本地缓存）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showSceneFilterDialog,
                          icon: const Icon(Icons.filter_alt, size: 18),
                          label: Text(
                            _selectedSceneId != null
                                ? _allScenes
                                      .firstWhere(
                                        (s) => s.id == _selectedSceneId,
                                        orElse: () =>
                                            SceneData(id: '', name: '未知'),
                                      )
                                      .name
                                : '场景',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: BorderSide(
                              color: _selectedSceneId != null
                                  ? AppTheme.primaryColor
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                            backgroundColor: _selectedSceneId != null
                                ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showDateRangeDialog,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: const Text('日期'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: BorderSide(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isSingleDayMode && _singleDay != null)
                          _buildDateChip(
                            DateFormat('yyyy-MM-dd').format(_singleDay!),
                            () => _updateView(() {
                              _singleDay = null;
                            }),
                          )
                        else if (_dateRange != null)
                          _buildDateChip(
                            '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
                            () => _updateView(() => _dateRange = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _fetchDetectionList(forceNetwork: true),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('同步'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerColor),
          Expanded(
            child: Builder(
              builder: (context) {
                // 中文注释：根据当前筛选模式获取展示列表，若为空则显示“暂无数据”
                final displayed = _getDisplayedList();
                if (displayed.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: AppTheme.dividerColor,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '暂无数据',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: displayed.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppTheme.dividerColor),
                  itemBuilder: (context, index) {
                    final item = displayed[index];
                    final count =
                        (item.metadata?['objectCount'] as int?) ??
                        item.issues.length;
                    final isSelected = currentResult?.id == item.id;

                    return Material(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.05)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _updateView(() {
                            currentResult = item;
                            imageIssues = item.issues;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 80,
                                  height: 60,
                                  child: _buildImageOrPlaceholder(
                                    item.imagePath,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.id,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '场景：${item.sceneName.isNotEmpty ? item.sceneName : '未知场景'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.bug_report_outlined,
                                          size: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count 个对象',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.model_training,
                                          size: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.detectionType ?? '通用模型',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 中文注释：根据是否存在图片URL/路径显示图片；为空时显示占位“暂无数据”
  Widget _buildImageOrPlaceholder(String path) {
    if (path.isEmpty) {
      return Container(
        color: AppTheme.backgroundLight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 24,
                color: AppTheme.dividerColor,
              ),
              const SizedBox(height: 4),
              const Text(
                '暂无图片',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final error = Container(
      color: AppTheme.backgroundLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 24,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            const Text(
              '加载失败',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    if (isNetwork) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => error,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => error,
    );
  }

  Widget _buildDetectionBox(DetectionIssue issue) {
    final color = issue.isHighSeverity
        ? AppTheme.errorColor
        : AppTheme.warningColor;
    return Positioned(
      left: issue.x * _DetectionResultScreenState._imageWidth,
      top: issue.y * _DetectionResultScreenState._imageHeight,
      child: Container(
        width: issue.width * _DetectionResultScreenState._imageWidth,
        height: issue.height * _DetectionResultScreenState._imageHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: _DetectionResultScreenState._borderWidth,
          ),
          borderRadius: BorderRadius.circular(
            _DetectionResultScreenState._borderRadius,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(
            _DetectionResultScreenState._paddingSmall,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(
              _DetectionResultScreenState._paddingSmall,
            ),
          ),
        ),
      ),
    );
  }
}
