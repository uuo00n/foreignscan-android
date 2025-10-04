import 'package:flutter/material.dart';
import '../models/scene_data.dart';
import '../models/inspection_record.dart';
import '../widgets/scene_selector.dart';
import '../widgets/scene_display.dart';
import '../widgets/records_section.dart';
import 'camera_screen.dart';
import 'detection_result_screen.dart';
import '../utils/camera_manager.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedSceneIndex = 0;
  int currentRecordPage = 0;
  final int recordsPerPage = 4;

  // 场景数据
  final List<SceneData> scenes = [
    SceneData(id: '001', name: '管道闸口'),
    SceneData(id: '002', name: '主承轴区域'),
    SceneData(id: '003', name: '冷却系统出口'),
    SceneData(id: '004', name: '传动轴检测点'),
    SceneData(id: '005', name: '润滑系统'),
    SceneData(id: '006', name: '控制阀门'),
    SceneData(id: '007', name: '进气管道'),
    SceneData(id: '008', name: '排气系统'),
    SceneData(id: '009', name: '温控单元'),
  ];

  // 拍摄记录
  final List<InspectionRecord> inspectionRecords = [
    InspectionRecord(
      id: '001',
      sceneName: '管道闸口',
      imagePath: '',
      timestamp: DateTime(2025, 7, 11, 14, 30),
      status: '已确认',
    ),
    InspectionRecord(
      id: '002',
      sceneName: '主承轴区域',
      imagePath: '',
      timestamp: DateTime(2025, 7, 11, 14, 30),
      status: '已确认',
    ),
    InspectionRecord(
      id: '003',
      sceneName: '冷却系统出口',
      imagePath: '',
      timestamp: DateTime(2025, 7, 11, 14, 30),
      status: '已确认',
    ),
    InspectionRecord(
      id: '004',
      sceneName: '传动轴检测点',
      imagePath: '',
      timestamp: DateTime(2025, 7, 11, 14, 30),
      status: '已确认',
    ),
  ];

  void _selectScene(int index) {
    setState(() {
      selectedSceneIndex = index;
    });
  }

  void _navigateToCamera() async {
    if (!CameraManager.hasCameras()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未检测到摄像头')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        scenes[selectedSceneIndex].capturedImage = result;
        inspectionRecords.insert(
          0,
          InspectionRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sceneName: scenes[selectedSceneIndex].name,
            imagePath: result,
            timestamp: DateTime.now(),
            status: '待确认',
          ),
        );
      });
    }
  }

  void _confirmTransfer() {
    if (scenes[selectedSceneIndex].capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先拍摄该场景')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在传输数据...'),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('传输成功')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = inspectionRecords.isEmpty
        ? 0
        : (inspectionRecords.length / recordsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.menu, color: Colors.white),
        title: Text('智能防异物检测系统', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              onPressed: () {},
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetectionResultScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('检测结果'),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SceneSelector(
                    scenes: scenes,
                    selectedIndex: selectedSceneIndex,
                    onSceneSelected: _selectScene,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SceneDisplay(
                      scene: scenes[selectedSceneIndex],
                      onCaptureClick: _navigateToCamera,
                      onConfirmTransfer: _confirmTransfer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          RecordsSection(
            records: inspectionRecords,
            currentPage: currentRecordPage,
            recordsPerPage: recordsPerPage,
            totalPages: totalPages,
            onPreviousPage: () {
              if (currentRecordPage > 0) {
                setState(() => currentRecordPage--);
              }
            },
            onNextPage: () {
              if (currentRecordPage < totalPages - 1) {
                setState(() => currentRecordPage++);
              }
            },
          ),
        ],
      ),
    );
  }
}