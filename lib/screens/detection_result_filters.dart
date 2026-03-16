part of 'detection_result_screen.dart';

extension _DetectionResultFilters on _DetectionResultScreenState {
  Future<void> _showDateRangeDialog() async {
    // 中文注释：弹窗内部的本地状态（避免直接改动外部状态）
    bool isSingle = _isSingleDayMode;
    DateTime single = _singleDay ?? DateTime.now();
    DateTime start =
        _dateRange?.start ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime end = _dateRange?.end ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择日期'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 中文注释：筛选模式切换（单日/范围）
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('单日'),
                        selected: isSingle,
                        onSelected: (sel) => setStateDialog(() {
                          isSingle = true;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('范围'),
                        selected: !isSingle,
                        onSelected: (sel) => setStateDialog(() {
                          isSingle = false;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isSingle)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        '日期：${DateFormat('yyyy-MM-dd').format(single)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: single,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            single = picked;
                          });
                        }
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              '起始：${DateFormat('yyyy-MM-dd').format(start)}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: start,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  start = picked;
                                  if (end.isBefore(start)) {
                                    end = start;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              '结束：${DateFormat('yyyy-MM-dd').format(end)}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: end,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  end = picked;
                                  if (end.isBefore(start)) {
                                    final tmp = start;
                                    start = end;
                                    end = tmp;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _updateView(() {
                  _singleDay = null;
                  _dateRange = null;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () {
                _updateView(() {
                  if (isSingle) {
                    _isSingleDayMode = true;
                    _singleDay = single;
                    _dateRange = null;
                  } else {
                    _isSingleDayMode = false;
                    _dateRange = DateTimeRange(start: start, end: end);
                    _singleDay = null;
                  }
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSceneFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择场景'),
          content: SizedBox(
            width: double.maxFinite,
            child: _allScenes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('暂无场景数据', textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allScenes.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          title: const Text('全部场景'),
                          leading: _selectedSceneId == null
                              ? const Icon(
                                  Icons.check,
                                  color: AppTheme.primaryColor,
                                )
                              : null,
                          selected: _selectedSceneId == null,
                          onTap: () {
                            _updateView(() {
                              _selectedSceneId = null;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final scene = _allScenes[index - 1];
                      final isSelected = _selectedSceneId == scene.id;
                      return ListTile(
                        title: Text(scene.name),
                        leading: isSelected
                            ? const Icon(
                                Icons.check,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                        selected: isSelected,
                        onTap: () {
                          _updateView(() {
                            _selectedSceneId = scene.id;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateChip(String label, VoidCallback onClear) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
