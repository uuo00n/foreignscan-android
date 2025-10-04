import 'package:flutter/material.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/verification_record.dart';
import 'package:foreignscan/widgets/verification_list.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';

class DetectionResultScreen extends StatefulWidget {
  final DetectionResultArguments? arguments;
  
  const DetectionResultScreen({super.key, this.arguments});
  
  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  late DetectionResult currentResult;
  
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
    currentResult = args != null 
        ? _createResultFromArguments(args)
        : _createMockDetectionResult();
  }

  DetectionResult _createResultFromArguments(DetectionResultArguments args) {
    return DetectionResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sceneName: args.imagePath.isNotEmpty ? '检测结果' : '未知场景',
      imagePath: args.imagePath,
      timestamp: DateTime.now(),
      status: DetectionStatus.completed,
      detectionType: args.detectionType,
      issues: _createIssuesFromDetectionResults(args.detectionResults),
    );
  }

  DetectionResult _createMockDetectionResult() {
    return DetectionResult(
      id: '001',
      sceneName: '管道闸口',
      imagePath: 'assets/mock_detection_image.jpg',
      timestamp: DateTime.now(),
      status: DetectionStatus.completed,
      issues: _createMockIssues(),
    );
  }

  List<DetectionIssue> _createIssuesFromDetectionResults(Map<String, dynamic>? results) {
    // 这里应该根据实际的检测结果生成问题列表
    // 暂时返回模拟数据
    return [
      DetectionIssue(
        id: 'issue_1',
        type: IssueType.foreignObject,
        description: '检测到金属异物',
        x: 0.6,
        y: 0.4,
        width: 0.08,
        height: 0.08,
        severity: IssueSeverity.high,
      ),
      DetectionIssue(
        id: 'issue_2',
        type: IssueType.foreignObject,
        description: '检测到异物',
        x: 0.3,
        y: 0.7,
        width: 0.06,
        height: 0.06,
        severity: IssueSeverity.medium,
      ),
    ];
  }

  List<DetectionIssue> _createMockIssues() {
    return [
      DetectionIssue(
        id: 'issue_1',
        type: IssueType.foreignObject,
        description: '检测到金属异物',
        x: 0.6,
        y: 0.4,
        width: 0.08,
        height: 0.08,
        severity: IssueSeverity.high,
      ),
      DetectionIssue(
        id: 'issue_2',
        type: IssueType.foreignObject,
        description: '检测到异物',
        x: 0.3,
        y: 0.7,
        width: 0.06,
        height: 0.06,
        severity: IssueSeverity.medium,
      ),
    ];
  }

  List<VerificationRecord> _createMockVerificationRecords() {
    return [
      VerificationRecord(
        id: '001',
        sceneName: '管道闸口',
        imagePath: '',
        timestamp: DateTime(2025, 7, 11, 14, 30),
        status: 'verified',
        verificationResult: 'normal',
      ),
      VerificationRecord(
        id: '002',
        sceneName: '主承轴区域',
        imagePath: '',
        timestamp: DateTime(2025, 7, 11, 14, 30),
        status: 'verified',
        verificationResult: 'abnormal',
      ),
      VerificationRecord(
        id: '003',
        sceneName: '冷却系统出口',
        imagePath: '',
        timestamp: DateTime(2025, 7, 11, 14, 30),
        status: 'verified',
        verificationResult: 'normal',
      ),
      VerificationRecord(
        id: '004',
        sceneName: '传动轴检测点',
        imagePath: '',
        timestamp: DateTime(2025, 7, 11, 14, 30),
        status: 'verified',
        verificationResult: 'normal',
      ),
    ];
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
              child: VerificationList(records: _createMockVerificationRecords()),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: AppBarBackButton(),
      title: const AppBarTitle(title: '智能防异物检测系统'),
      actions: [
        AppBarActions(
          onNewDetectionPressed: () => Navigator.pop(context),
          onDetectionResultsPressed: () {
            // 当前已经在检测结果页面，可以显示提示或刷新
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('当前已在检测结果页面'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetectionResultArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '问题：${currentResult.id} - ${currentResult.sceneName}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                // 检测图片
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
                      child: Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Text(
                            '检测图片\n(模拟工业设备检测图)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 检测框标注
                ...currentResult.issues.map((issue) => _buildDetectionBox(issue)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '检测到 ${currentResult.issues.length} 个问题',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('确认核查完成')),
                  );
                },
                icon: Icon(Icons.check_circle),
                label: Text('确认核查'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
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