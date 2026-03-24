import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:foreignscan/core/services/detection_service.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/record_detail_page.dart';

enum RecordsStatusFilter { all, qualified, abnormal, pending }

enum RecordsSortOrder { latestFirst, oldestFirst }

@visibleForTesting
List<InspectionRecord> buildVisibleRecords(
  List<InspectionRecord> records, {
  String query = '',
  RecordsStatusFilter statusFilter = RecordsStatusFilter.all,
  RecordsSortOrder sortOrder = RecordsSortOrder.latestFirst,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  final filtered = records
      .where((record) {
        final statusMatches = _matchesStatusFilter(record, statusFilter);
        if (!statusMatches) {
          return false;
        }

        if (normalizedQuery.isEmpty) {
          return true;
        }

        final haystacks = <String>[
          record.sceneName,
          record.roomName,
          record.pointId,
          record.status,
        ];

        return haystacks.any(
          (value) => value.trim().toLowerCase().contains(normalizedQuery),
        );
      })
      .toList(growable: false);

  filtered.sort((a, b) {
    final comparison = a.timestamp.compareTo(b.timestamp);
    if (comparison == 0) {
      return a.sceneName.compareTo(b.sceneName);
    }
    return sortOrder == RecordsSortOrder.latestFirst ? -comparison : comparison;
  });

  return filtered;
}

@visibleForTesting
int countTodayRecords(List<InspectionRecord> records, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final start = DateTime(current.year, current.month, current.day);
  final end = start.add(const Duration(days: 1));
  return records.where((record) {
    final timestamp = record.timestamp;
    return !timestamp.isBefore(start) && timestamp.isBefore(end);
  }).length;
}

bool _matchesStatusFilter(
  InspectionRecord record,
  RecordsStatusFilter statusFilter,
) {
  final statusType = record.statusType;
  switch (statusFilter) {
    case RecordsStatusFilter.all:
      return true;
    case RecordsStatusFilter.qualified:
      return statusType == InspectionStatusType.detected ||
          statusType == InspectionStatusType.qualified ||
          statusType == InspectionStatusType.verified;
    case RecordsStatusFilter.abnormal:
      return statusType == InspectionStatusType.abnormal;
    case RecordsStatusFilter.pending:
      return statusType == InspectionStatusType.pending ||
          statusType == InspectionStatusType.uploaded ||
          statusType == InspectionStatusType.unknown;
  }
}

class RecordsSection extends StatefulWidget {
  final List<InspectionRecord> records;

  const RecordsSection({super.key, required this.records});

  @override
  State<RecordsSection> createState() => _RecordsSectionState();
}

class _RecordsSectionState extends State<RecordsSection> {
  late final TextEditingController _searchController;
  RecordsStatusFilter _selectedStatusFilter = RecordsStatusFilter.all;
  RecordsSortOrder _sortOrder = RecordsSortOrder.latestFirst;
  String? _selectedRecordId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = buildVisibleRecords(
      widget.records,
      query: _searchController.text,
      statusFilter: _selectedStatusFilter,
      sortOrder: _sortOrder,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitLayout = constraints.maxWidth >= 600;
        final selectedRecord = _resolveSelectedRecord(visibleRecords);

        return Container(
          width: double.infinity,
          color: AppTheme.backgroundLight,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(context),
              const SizedBox(height: 10),
              Expanded(
                child: isSplitLayout
                    ? _buildSplitLayout(
                        context,
                        visibleRecords: visibleRecords,
                        selectedRecord: selectedRecord,
                        maxWidth: constraints.maxWidth,
                      )
                    : _buildSingleColumnLayout(
                        context,
                        visibleRecords: visibleRecords,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 8),
        _buildFilterButton(context),
      ],
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: '搜索场景、房间或点位',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: () => _openFilterSheet(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _hasActiveSheetFilters
                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                : AppTheme.dividerColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          Icons.tune_rounded,
          size: 18,
          color: _hasActiveSheetFilters
              ? AppTheme.primaryColor
              : AppTheme.textSecondary,
        ),
        label: Text(
          _hasActiveSheetFilters ? '筛选中' : '筛选',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _hasActiveSheetFilters
                ? AppTheme.primaryColor
                : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    var draftStatus = _selectedStatusFilter;
    var draftSort = _sortOrder;

    final result = await showModalBottomSheet<_FilterSheetSelection>(
      context: context,
      backgroundColor: AppTheme.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '筛选',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '状态',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RecordsStatusFilter.values
                          .map((filter) {
                            final selected = draftStatus == filter;
                            return FilterChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(_statusFilterLabel(filter)),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  draftStatus = filter;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '排序',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RecordsSortOrder.values
                          .map((sortOrder) {
                            final selected = draftSort == sortOrder;
                            return ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(_sortOrderLabel(sortOrder)),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  draftSort = sortOrder;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              draftStatus = RecordsStatusFilter.all;
                              draftSort = RecordsSortOrder.latestFirst;
                            });
                          },
                          child: const Text('重置'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              _FilterSheetSelection(
                                statusFilter: draftStatus,
                                sortOrder: draftSort,
                              ),
                            );
                          },
                          child: const Text('应用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedStatusFilter = result.statusFilter;
      _sortOrder = result.sortOrder;
    });
  }

  Widget _buildSplitLayout(
    BuildContext context, {
    required List<InspectionRecord> visibleRecords,
    required InspectionRecord? selectedRecord,
    required double maxWidth,
  }) {
    final listPaneWidth = math.max(308.0, math.min(360.0, maxWidth * 0.36));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: listPaneWidth,
          child: _buildRecordsPane(
            context,
            visibleRecords: visibleRecords,
            isSplitLayout: true,
            selectedRecordId: selectedRecord?.id,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _RecordPreviewPane(record: selectedRecord)),
      ],
    );
  }

  Widget _buildSingleColumnLayout(
    BuildContext context, {
    required List<InspectionRecord> visibleRecords,
  }) {
    return _buildRecordsPane(
      context,
      visibleRecords: visibleRecords,
      isSplitLayout: false,
      selectedRecordId: null,
    );
  }

  Widget _buildRecordsPane(
    BuildContext context, {
    required List<InspectionRecord> visibleRecords,
    required bool isSplitLayout,
    required String? selectedRecordId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: visibleRecords.isEmpty
          ? _buildEmptyState(hasFilters: _hasActiveFilters)
          : Scrollbar(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: visibleRecords.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = visibleRecords[index];
                  final isSelected =
                      isSplitLayout && selectedRecordId == record.id;
                  return _buildRecordTile(
                    context,
                    record,
                    isSplitLayout: isSplitLayout,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState({required bool hasFilters}) {
    final title = hasFilters ? '没有找到符合条件的拍摄记录' : '暂无拍摄记录';
    final message = hasFilters ? '试试清空搜索词或切换状态筛选。' : '拍摄完成后，这里会按时间展示最近的记录。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    InspectionRecord record, {
    required bool isSplitLayout,
    required bool isSelected,
  }) {
    final theme = _statusThemeForRecord(record);
    final timeText = DateFormat('MM-dd HH:mm').format(record.timestamp);
    final roomText = record.roomName.isNotEmpty ? record.roomName : '未绑定房间';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleRecordTap(context, record, isSplitLayout),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.28)
                  : AppTheme.dividerColor,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _buildRecordImage(
                    record.imagePath,
                    emptyIcon: Icons.image_not_supported_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.sceneName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusChip(theme),
                        _buildMetaTag(
                          icon: Icons.access_time_rounded,
                          text: timeText,
                        ),
                        if (record.pointId.isNotEmpty)
                          _buildMetaTag(
                            icon: Icons.pin_drop_outlined,
                            text: record.pointId,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            roomText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (!isSplitLayout)
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(_RecordStatusTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: 14, color: theme.foregroundColor),
          const SizedBox(width: 6),
          Text(
            theme.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  InspectionRecord? _resolveSelectedRecord(List<InspectionRecord> records) {
    if (records.isEmpty) {
      return null;
    }

    final selectedId = _selectedRecordId;
    if (selectedId == null) {
      return records.first;
    }

    for (final record in records) {
      if (record.id == selectedId) {
        return record;
      }
    }
    return records.first;
  }

  void _handleRecordTap(
    BuildContext context,
    InspectionRecord record,
    bool isSplitLayout,
  ) {
    if (isSplitLayout) {
      setState(() {
        _selectedRecordId = record.id;
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordDetailPage(record: record)),
    );
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty || _hasActiveSheetFilters;
  }

  bool get _hasActiveSheetFilters {
    return _selectedStatusFilter != RecordsStatusFilter.all ||
        _sortOrder != RecordsSortOrder.latestFirst;
  }
}

class _FilterSheetSelection {
  final RecordsStatusFilter statusFilter;
  final RecordsSortOrder sortOrder;

  const _FilterSheetSelection({
    required this.statusFilter,
    required this.sortOrder,
  });
}

class _RecordPreviewPane extends ConsumerStatefulWidget {
  final InspectionRecord? record;

  const _RecordPreviewPane({required this.record});

  @override
  ConsumerState<_RecordPreviewPane> createState() => _RecordPreviewPaneState();
}

class _RecordPreviewPaneState extends ConsumerState<_RecordPreviewPane> {
  Future<DetectionResult?>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  @override
  void didUpdateWidget(covariant _RecordPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record?.id != widget.record?.id) {
      _summaryFuture = _loadSummary();
    }
  }

  Future<DetectionResult?>? _loadSummary() {
    final record = widget.record;
    if (record == null || record.id.isEmpty) {
      return null;
    }
    return ref
        .read(detectionServiceProvider)
        .getLatestDetectionByImage(record.id);
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    if (record == null) {
      return _buildPreviewPlaceholder();
    }

    final previewTime = DateFormat('yyyy-MM-dd HH:mm').format(record.timestamp);
    final statusTheme = _statusThemeForRecord(record);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildRecordImage(
                  record.imagePath,
                  emptyIcon: Icons.camera_alt_outlined,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.sceneName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.roomName.isNotEmpty ? record.roomName : '未绑定房间',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusPill(theme: statusTheme),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreviewMetaPill(
                  icon: Icons.access_time_rounded,
                  text: previewTime,
                ),
                _PreviewMetaPill(
                  icon: Icons.pin_drop_outlined,
                  text: record.pointId.isNotEmpty ? record.pointId : '未记录点位',
                ),
                _PreviewMetaPill(
                  icon: Icons.meeting_room_outlined,
                  text: record.roomName.isNotEmpty ? record.roomName : '未绑定房间',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordDetailPage(record: record),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('查看详情'),
              ),
            ),
            const SizedBox(height: 10),
            _buildDetectionSummaryCard(record),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 40,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 14),
              Text(
                '请选择一条拍摄记录查看详情',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '从左侧选中一条记录后，这里会展示图片和检测摘要。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionSummaryCard(InspectionRecord record) {
    final future = _summaryFuture;
    if (future == null) {
      return _SummaryPanel(
        title: '检测摘要',
        child: const Text(
          '当前记录缺少检测摘要数据。',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      );
    }

    return FutureBuilder<DetectionResult?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SummaryPanel(
            title: '检测摘要',
            child: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return _SummaryPanel(
            title: '检测摘要',
            child: const Text(
              '核查摘要暂时不可用，请进入详情页查看完整信息。',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          );
        }

        final detection = snapshot.data;
        if (detection == null) {
          return _SummaryPanel(
            title: '检测摘要',
            child: const Text(
              '暂无核查数据。',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          );
        }

        final objectCount =
            (detection.metadata?['objectCount'] as int?) ??
            detection.issues.length;
        final isPass = _isPassByIssues(detection.issues);
        final resultText = isPass ? '合格' : '异常';
        final resultColor = isPass
            ? AppTheme.successColor
            : AppTheme.errorColor;
        final modelName = detection.detectionType?.isNotEmpty == true
            ? detection.detectionType!
            : '未记录模型';

        return _SummaryPanel(
          title: '检测摘要',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      resultText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      modelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PreviewInfoCard(
                    icon: Icons.category_outlined,
                    label: '对象数量',
                    value: '$objectCount',
                    compact: true,
                  ),
                  _PreviewInfoCard(
                    icon: Icons.rule_folder_outlined,
                    label: '异常项',
                    value: '${detection.issues.length}',
                    compact: true,
                  ),
                  _PreviewInfoCard(
                    icon: Icons.timer_outlined,
                    label: '推理耗时',
                    value:
                        '${detection.metadata?['inferenceTimeMs']?.toString() ?? '-'} ms',
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isPassByIssues(List<DetectionIssue> issues) {
    if (issues.isEmpty) {
      return true;
    }

    for (final issue in issues) {
      final className =
          issue.metadata?['class']?.toString().toLowerCase() ?? '';
      if (className != 'bolts' && className != 'bolt') {
        return false;
      }
    }
    return true;
  }
}

class _SummaryPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _SummaryPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PreviewMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreviewMetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _PreviewInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 150 : 180),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _RecordStatusTheme theme;

  const _StatusPill({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: 14, color: theme.foregroundColor),
          const SizedBox(width: 6),
          Text(
            theme.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordStatusTheme {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final IconData icon;

  const _RecordStatusTheme({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.icon,
  });
}

_RecordStatusTheme _statusThemeForRecord(InspectionRecord record) {
  switch (record.statusType) {
    case InspectionStatusType.abnormal:
      return _RecordStatusTheme(
        label: '异常',
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.08),
        borderColor: AppTheme.errorColor.withValues(alpha: 0.24),
        foregroundColor: AppTheme.errorColor,
        icon: Icons.warning_amber_rounded,
      );
    case InspectionStatusType.detected:
    case InspectionStatusType.qualified:
    case InspectionStatusType.verified:
      return _RecordStatusTheme(
        label: '合格',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.08),
        borderColor: AppTheme.successColor.withValues(alpha: 0.24),
        foregroundColor: AppTheme.successColor,
        icon: Icons.check_circle_outline_rounded,
      );
    default:
      return _RecordStatusTheme(
        label: '未检测',
        backgroundColor: AppTheme.backgroundLight,
        borderColor: AppTheme.dividerColor,
        foregroundColor: AppTheme.textSecondary,
        icon: Icons.hourglass_empty_rounded,
      );
  }
}

String _statusFilterLabel(RecordsStatusFilter filter) {
  switch (filter) {
    case RecordsStatusFilter.all:
      return '全部';
    case RecordsStatusFilter.qualified:
      return '合格';
    case RecordsStatusFilter.abnormal:
      return '异常';
    case RecordsStatusFilter.pending:
      return '未检测';
  }
}

String _sortOrderLabel(RecordsSortOrder sortOrder) {
  switch (sortOrder) {
    case RecordsSortOrder.latestFirst:
      return '最新优先';
    case RecordsSortOrder.oldestFirst:
      return '最早优先';
  }
}

Widget _buildRecordImage(String imagePath, {required IconData emptyIcon}) {
  if (imagePath.isNotEmpty &&
      (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildBrokenImageState(emptyIcon),
    );
  }

  if (imagePath.isNotEmpty) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildBrokenImageState(emptyIcon),
    );
  }

  return _buildBrokenImageState(emptyIcon);
}

Widget _buildBrokenImageState(IconData emptyIcon) {
  return Container(
    color: AppTheme.backgroundLight,
    alignment: Alignment.center,
    child: Icon(
      emptyIcon,
      size: 30,
      color: AppTheme.textSecondary.withValues(alpha: 0.5),
    ),
  );
}
