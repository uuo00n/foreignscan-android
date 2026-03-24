import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/services/detection_service.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/verification_record.dart';
import 'package:foreignscan/widgets/verification_list.dart';
import 'package:intl/intl.dart';

part 'detection_result_data.dart';
part 'detection_result_filters.dart';
part 'detection_result_widgets.dart';

class DetectionResultScreen extends ConsumerStatefulWidget {
  final DetectionResultArguments? arguments;

  const DetectionResultScreen({super.key, this.arguments});

  @override
  ConsumerState<DetectionResultScreen> createState() =>
      _DetectionResultScreenState();
}

class _DetectionResultScreenState extends ConsumerState<DetectionResultScreen> {
  DetectionResult? currentResult;
  List<DetectionIssue> imageIssues = const [];
  List<DetectionResult> detectionList = const [];
  bool isLoading = true;
  String? errorMessage;
  DateTimeRange? _dateRange;
  DateTime? _singleDay; // 中文注释：单日模式下选择的日期
  bool _isSingleDayMode = false; // 中文注释：筛选模式（true=单日，false=范围）

  // 场景筛选相关
  String? _selectedSceneId;
  List<SceneData> _allScenes = [];

  // UI 常量
  static const double _imageWidth = 600.0;
  static const double _imageHeight = 450.0;
  static const double _borderRadius = 4.0;
  static const double _borderWidth = 3.0;
  static const double _paddingSmall = 2.0;
  static const double _statusCardMaxWidth = 520.0;

  void _updateView(VoidCallback updater) {
    setState(updater);
  }

  bool get _isDetailMode {
    final imageId = widget.arguments?.imageId;
    return imageId != null && imageId.isNotEmpty;
  }

  String? get _currentImageId {
    final imageId = widget.arguments?.imageId;
    if (imageId == null || imageId.isEmpty) return null;
    return imageId;
  }

  String _normalizeErrorDetail(String? raw) {
    var text = (raw ?? '').trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isOfflineErrorMessage(String? raw) {
    final text = _normalizeErrorDetail(raw).toLowerCase();
    const offlineMarkers = <String>[
      'socketexception',
      'dioexception',
      'connection failed',
      'connection error',
      'connection errored',
      'network is unreachable',
      'network+本地均不可用',
      '网络+本地均不可用',
      'failed host lookup',
      'errno = 101',
    ];
    return offlineMarkers.any(text.contains);
  }

  Future<void> _retryCurrentView() async {
    final imageId = _currentImageId;
    if (imageId != null) {
      await _fetchIssuesByImage(imageId);
      return;
    }
    await _fetchDetectionList(forceNetwork: true);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchScenes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1000) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildDetectionResultArea()),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: VerificationList(
                      records: _buildVerificationRecords(),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(child: _buildDetectionResultArea()),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: VerificationList(records: _buildVerificationRecords()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
