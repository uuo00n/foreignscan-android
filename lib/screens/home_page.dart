import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import 'package:foreignscan/core/widgets/error_widget.dart';
import 'package:foreignscan/widgets/scene_selector.dart';
import 'package:foreignscan/widgets/scene_display.dart';
import 'package:foreignscan/widgets/records_section.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/camera_screen.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/widgets/app_drawer.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    // 监听错误状态
    ref.listen(homeViewModelProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () {
                homeViewModel.clearError();
                homeViewModel.refreshData();
              },
            ),
          ),
        );
      }
    });

    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context, ref, _scaffoldKey),
      drawer: AppDrawer(
        onUploadPressed: () => _uploadLatestImage(context, ref),
      ),
      body: homeState.isLoading 
          ? const LoadingWidget(message: '正在加载数据...')
          : homeState.errorMessage != null
              ? ErrorWidgetCustom(
                  message: homeState.errorMessage!,
                  onRetry: () => homeViewModel.refreshData(),
                )
              : _buildBody(context, ref, homeState, homeViewModel),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, GlobalKey<ScaffoldState> scaffoldKey) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          scaffoldKey.currentState?.openDrawer();
        },
      ),
      title: const Text('智能防异物检测系统'),
      actions: [
        AppBarActions(
          onNewDetectionPressed: () => _startNewInspection(context, ref),
          onDetectionResultsPressed: () => AppRouter.navigateToDetectionResult(
            const DetectionResultArguments(
              imagePath: '',
              detectionType: '',
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _uploadLatestImage(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.scenes[homeState.selectedSceneIndex];
    
    if (selectedScene.capturedImage == null || selectedScene.capturedImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可上传的图片，请先拍摄照片'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 显示上传进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('正在上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在通过WiFi上传图片，请稍候...'),
          ],
        ),
      ),
    );
    
    try {
      final wifiService = ref.read(wifiServiceProvider);
      final result = await wifiService.uploadImageFromCamera(
        selectedScene.capturedImage!,
        sceneId: selectedScene.id,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片上传成功'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片上传失败，请检查网络连接和服务器设置'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    HomeState homeState,
    HomeViewModel homeViewModel,
  ) {
    if (homeState.scenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '暂无场景数据',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请联系管理员添加检测场景',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => homeViewModel.refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    final selectedScene = homeState.scenes[homeState.selectedSceneIndex];

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SceneSelector(
                  scenes: homeState.scenes,
                  selectedIndex: homeState.selectedSceneIndex,
                  onSceneSelected: (index) => homeViewModel.selectScene(index),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SceneDisplay(
                    scene: selectedScene,
                    onCaptureClick: () => _navigateToCamera(context, ref),
                    onConfirmTransfer: () => _confirmTransfer(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
        RecordsSection(
          records: homeState.inspectionRecords,
          currentPage: homeState.currentRecordPage,
          recordsPerPage: homeState.recordsPerPage,
          totalPages: homeState.totalPages,
          onPreviousPage: () => homeViewModel.previousRecordPage(),
          onNextPage: () => homeViewModel.nextRecordPage(),
        ),
      ],
    );
  }

  Future<void> _startNewInspection(BuildContext context, WidgetRef ref) async {
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    
    if (ref.read(homeViewModelProvider).scenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无可用检测场景'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 重置到第一个场景
    homeViewModel.selectScene(0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请选择检测场景开始检测'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _navigateToCamera(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.scenes[homeState.selectedSceneIndex];
    
    try {
      // 使用新的路由系统导航到相机页面
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(),
        ),
      );
      
      // 处理相机返回的结果
      if (imagePath != null) {
        final homeViewModel = ref.read(homeViewModelProvider.notifier);
        await homeViewModel.updateSceneImage(selectedScene.id, imagePath);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('照片拍摄成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('相机初始化失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmTransfer(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.scenes[homeState.selectedSceneIndex];
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    if (selectedScene.capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先拍摄该场景'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 显示上传进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('正在传输'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在通过WiFi传输图片，请稍候...'),
          ],
        ),
      ),
    );

    try {
      // 使用WiFi服务上传图片
      final wifiService = ref.read(wifiServiceProvider);
      final result = await wifiService.uploadImageFromCamera(
        selectedScene.capturedImage!,
        sceneId: selectedScene.id,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('传输成功'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 添加检测记录
          final newRecord = InspectionRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sceneName: selectedScene.name,
            imagePath: selectedScene.capturedImage!,
            timestamp: DateTime.now(),
            status: '已确认',
          );

          await homeViewModel.addInspectionRecord(newRecord);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('传输失败，请检查网络连接和服务器设置'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('传输出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}