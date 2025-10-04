import 'package:flutter/material.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/verification_record.dart';
import 'package:foreignscan/widgets/verification_list.dart';

// 临时定义，避免类型冲突
typedef DetectionResultArguments = Map<String, dynamic>;

// 临时枚举定义
enum VerificationStatus { pending, verified, rejected }
enum VerificationResult { normal, abnormal, unknown }

class DetectionResultScreen extends StatefulWidget {
  final DetectionResultArguments? arguments;
  
  const DetectionResultScreen({super.key, this.arguments});
  
  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  late DetectionResult currentResult;
  List<VerificationRecord> verificationRecords = [];

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    // 模拟检测结果数据
    currentResult = DetectionResult(
      id: '001',
      sceneName: '管道闸口',
      imagePath: 'assets/mock_detection_image.jpg',
      timestamp: DateTime.now(),
      status: DetectionStatus.completed,
      issues: [
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
      ],
    );

    // 模拟核查记录数据
    verificationRecords = [
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
              child: VerificationList(records: verificationRecords),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('智能防异物检测系统', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.blue,
      actions: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: Text('新建检测'),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('检测结果'),
          ),
        ),
        SizedBox(width: 16),
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
      left: issue.x * 600, // 模拟图片宽度
      top: issue.y * 450,  // 模拟图片高度
      child: Container(
        width: issue.width * 600,
        height: issue.height * 450,
        decoration: BoxDecoration(
          border: Border.all(
            color: issue.isHighSeverity ? Colors.red : Colors.orange,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          padding: EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: (issue.isHighSeverity ? Colors.red : Colors.orange)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}