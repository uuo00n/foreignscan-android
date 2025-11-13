import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/verification_record.dart';
import 'package:foreignscan/widgets/verification_list.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/core/services/detection_service.dart';

class DetectionResultScreen extends ConsumerStatefulWidget {
  final DetectionResultArguments? arguments;
  
  const DetectionResultScreen({super.key, this.arguments});
  
  @override
  ConsumerState<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends ConsumerState<DetectionResultScreen> {
  DetectionResult? currentResult;
  List<DetectionIssue> imageIssues = const [];
  List<DetectionResult> detectionList = const [];
  bool isLoading = true;
  String? errorMessage;
  
  // UI 常量
  static const double _imageWidth = 600.0;
  static const double _imageHeight = 450.0;
  static const double _borderRadius = 4.0;
  static const double _borderWidth = 3.0;
  static const double _paddingSmall = 2.0;
  static const Color _highSeverityColor = Colors.red;
  static const Color _mediumSeverityColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _fetchDetectionList() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      currentResult = null;
      imageIssues = const [];
    });

    try {
      final service = ref.read(detectionServiceProvider);
      final list = await service.getDetectionResults();
      if (list.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return; // 中文注释：无数据直接走空态
      }
      setState(() {
        detectionList = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _fetchIssuesByImage(String imageId) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      currentResult = null;
      imageIssues = const [];
    });

    try {
      final service = ref.read(detectionServiceProvider);
      final issues = await service.getDetectionsByImage(imageId);
      setState(() {
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
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧检测结果区域
            Expanded(
              flex: 2,
              child: _buildDetectionResultArea(),
            ),
            SizedBox(width: 16),
            // 右侧核查记录列表
            Expanded(
              flex: 1,
              // 中文注释：根据左侧选择的检测项，在核查记录中展示其信息与缩略图
              child: VerificationList(records: _buildVerificationRecords()),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: AppBarBackButton(),
      title: const AppBarTitle(title: '检测结果'),
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
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final isDetailMode = widget.arguments?.imageId != null && widget.arguments!.imageId!.isNotEmpty;
    if (isDetailMode) {
      final hasDetail = (currentResult != null && currentResult!.issues.isNotEmpty) || imageIssues.isNotEmpty;
      if (!hasDetail) {
        return Center(
          child: Text(
            '暂无数据',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
          ),
        );
      }
      return _buildDetectionDetailView();
    }

    if (detectionList.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
        ),
      );
    }
    return _buildDetectionListView();
  }

  Widget _buildDetectionDetailView() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '问题：${currentResult?.id ?? ''} - ${currentResult?.sceneName ?? ''}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _buildImageOrPlaceholder(currentResult?.imagePath ?? ''),
                    ),
                  ),
                ),
                ...((currentResult?.issues ?? imageIssues)).map((issue) => _buildDetectionBox(issue)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '检测到 ${(currentResult?.issues.length ?? imageIssues.length)} 个问题',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.check_circle),
                label: Text('确认核查'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 中文注释：将当前选择的检测结果转换为核查记录列表（单条）
  List<VerificationRecord> _buildVerificationRecords() {
    final selected = currentResult;
    if (selected == null) return [];
    final count = (selected.metadata?['objectCount'] as int?) ?? selected.issues.length;
    final result = count > 0 ? '异常' : '已确认';
    return [
      VerificationRecord(
        id: selected.id,
        sceneName: '模型：${selected.detectionType ?? ''}',
        imagePath: selected.imagePath,
        timestamp: selected.timestamp,
        status: '已检测',
        verificationResult: result,
      )
    ];
  }

  Widget _buildDetectionListView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ListView.separated(
        itemCount: detectionList.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, index) {
          final item = detectionList[index];
          final count = (item.metadata?['objectCount'] as int?) ?? item.issues.length;
          return ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 80,
                height: 60,
                child: _buildImageOrPlaceholder(item.imagePath),
              ),
            ),
            title: Text(item.id, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('对象数：$count · 模型：${item.detectionType ?? ''}'),
            onTap: () {
              setState(() {
                currentResult = item;
                imageIssues = item.issues;
              });
            },
          );
        },
      ),
    );
  }

  // 中文注释：根据是否存在图片URL/路径显示图片；为空时显示占位“暂无数据”
  Widget _buildImageOrPlaceholder(String path) {
    if (path.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Text(
              '图片加载失败',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetectionBox(DetectionIssue issue) {
    return Positioned(
      left: issue.x * _imageWidth,
      top: issue.y * _imageHeight,
      child: Container(
        width: issue.width * _imageWidth,
        height: issue.height * _imageHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: issue.isHighSeverity ? _highSeverityColor : _mediumSeverityColor,
            width: _borderWidth,
          ),
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: Container(
          padding: const EdgeInsets.all(_paddingSmall),
          decoration: BoxDecoration(
            color: (issue.isHighSeverity ? _highSeverityColor : _mediumSeverityColor)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(_paddingSmall),
          ),
        ),
      ),
    );
  }
}
