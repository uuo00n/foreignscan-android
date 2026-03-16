part of 'detection_result_screen.dart';

extension _DetectionResultData on _DetectionResultScreenState {
  Future<void> _fetchScenes() async {
    try {
      final service = ref.read(sceneServiceProvider);
      final scenes = await service.getScenes();
      if (mounted) {
        _updateView(() {
          _allScenes = scenes;
        });
      }
    } catch (_) {
      // 忽略场景加载错误
    }
  }

  void _loadData() {
    final args = widget.arguments;
    // 中文注释：根据是否传入 imageId 决定调用哪个真实接口
    if (args?.imageId != null && args!.imageId!.isNotEmpty) {
      _fetchIssuesByImage(args.imageId!);
      return;
    }
    _fetchDetectionList();
  }

  Future<void> _fetchDetectionList({bool forceNetwork = false}) async {
    _updateView(() {
      isLoading = true;
      errorMessage = null;
      currentResult = null;
      imageIssues = const [];
    });

    try {
      final service = ref.read(detectionServiceProvider);
      final list = await service.getDetectionResultsHybrid(
        forceNetwork: forceNetwork,
      );
      if (list.isEmpty) {
        _updateView(() {
          isLoading = false;
        });
        return; // 中文注释：无数据直接走空态
      }
      _updateView(() {
        detectionList = list;
        isLoading = false;
      });
    } catch (e) {
      _updateView(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  List<DetectionResult> _getDisplayedList() {
    var filtered = detectionList;

    // 1. 场景筛选
    if (_selectedSceneId != null) {
      filtered = filtered.where((r) {
        // 优先匹配 metadata 中的 sceneId
        final sceneId = r.metadata?['sceneId']?.toString();
        if (sceneId != null && sceneId.isNotEmpty) {
          return sceneId == _selectedSceneId;
        }
        // 兜底：匹配场景名称（防止旧数据只有名称）
        final selectedScene = _allScenes.firstWhere(
          (s) => s.id == _selectedSceneId,
          orElse: () => SceneData(id: '', name: ''),
        );
        return r.sceneName == selectedScene.name;
      }).toList();
    }

    // 2. 日期筛选
    // 中文注释：优先使用单日筛选；否则使用范围筛选；都为空则返回原列表
    if (_isSingleDayMode && _singleDay != null) {
      final start = DateTime(
        _singleDay!.year,
        _singleDay!.month,
        _singleDay!.day,
      );
      final end = DateTime(
        _singleDay!.year,
        _singleDay!.month,
        _singleDay!.day,
        23,
        59,
        59,
        999,
      );
      filtered = filtered.where((r) {
        final t = r.timestamp;
        return (t.isAtSameMomentAs(start) || t.isAfter(start)) &&
            (t.isAtSameMomentAs(end) || t.isBefore(end));
      }).toList();
    } else if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      filtered = filtered.where((r) {
        final t = r.timestamp;
        return (t.isAtSameMomentAs(start) || t.isAfter(start)) &&
            (t.isAtSameMomentAs(end) || t.isBefore(end));
      }).toList();
    }

    return filtered;
  }

  Future<void> _fetchIssuesByImage(String imageId) async {
    _updateView(() {
      isLoading = true;
      errorMessage = null;
      currentResult = null;
      imageIssues = const [];
    });

    try {
      final service = ref.read(detectionServiceProvider);
      final issues = await service.getDetectionsByImage(imageId);
      _updateView(() {
        imageIssues = issues;
        // 中文注释：若路由携带 imagePath，用其作为展示背景
        currentResult = DetectionResult(
          id: imageId,
          sceneName: '检测结果',
          imagePath: widget.arguments?.imagePath ?? '',
          timestamp: DateTime.now(),
          issues: issues,
          status: DetectionStatus.completed,
          detectionType: widget.arguments?.detectionType,
        );
        isLoading = false;
      });
    } catch (e) {
      _updateView(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 中文注释：将当前选择的检测结果转换为核查记录列表（单条）
  List<VerificationRecord> _buildVerificationRecords() {
    final selected = currentResult;
    if (selected == null) return [];

    // 判断是否合格：仅 Bolts 为合格，其他（如 hole）均为异常
    var isQualified = true;
    if (selected.issues.isNotEmpty) {
      for (final issue in selected.issues) {
        final className =
            issue.metadata?['class']?.toString().toLowerCase() ?? '';
        if (className != 'bolts' && className != 'bolt') {
          isQualified = false;
          break;
        }
      }
    } else {
      // 如果 issues 为空但 metadata 显示有对象，且无法判断类型，暂视为异常（或者如果没有 issues 也没有对象，则是合格）
      final count = (selected.metadata?['objectCount'] as int?) ?? 0;
      if (count > 0) {
        isQualified = false;
      }
    }

    final result = isQualified ? '合格' : '异常';
    return [
      VerificationRecord(
        id: selected.id,
        sceneName: '模型：${selected.detectionType ?? ''}',
        imagePath: selected.imagePath,
        timestamp: selected.timestamp,
        status: '已检测',
        verificationResult: result,
      ),
    ];
  }
}
