import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // 使用WillPopScope处理返回手势
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // 显示退出确认对话框
        _showExitConfirmDialog(context);
      },
      child: Scaffold(
        // 中文注释：移除每次 build 重新创建的 GlobalKey，避免频繁重建带来的潜在问题。
        appBar: _buildAppBar(context, ref),
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      // 中文注释：使用 Builder 获取位于 Scaffold 之下的上下文，
      // 通过 Scaffold.of(context).openDrawer() 打开抽屉，避免对 GlobalKey 的依赖。
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(ctx).openDrawer();
          },
        ),
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
  
  // 显示退出确认对话框
  Future<void> _showExitConfirmDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出应用吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    ).then((value) {
      if (value == true) {
        // 如果用户确认退出，则使用SystemNavigator.pop()完全退出应用
        SystemNavigator.pop();
      }
    });
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
                  child: Builder(
                    builder: (_) {
                      // 中文说明：
                      // 传入加载状态以在SceneDisplay中显示加载动画，同时传入已解析的URL/路径。
                      final refImageAsync = ref.watch(referenceImageUrlProvider);
                      return SceneDisplay(
                        scene: selectedScene,
                        onCaptureClick: () => _navigateToCamera(context, ref),
                        onConfirmTransfer: () => _confirmTransfer(context, ref),
                        referenceImageUrl: refImageAsync.maybeWhen(
                          data: (v) => v,
                          orElse: () => null,
                        ),
                        isReferenceLoading: refImageAsync.isLoading,
                      );
                    },
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
          
          // 添加检测记录（改造为使用后端返回的 imageId 与图片访问URL）
          // 中文说明：
          // - 后端返回 result['imageId'] 与 result['path']（形如 /uploads/images/<scene>/<file>）
          // - WiFi 服务提供 serverAddress（例如 http://172.20.10.3:3000），拼接形成完整URL
          final wifiSvc = ref.read(wifiServiceProvider);
          final String imageId = (result['imageId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());
          final String relativePath = (result['path']?.toString() ?? result['accessPath']?.toString() ?? '');
          String fullUrl = relativePath;
          if (relativePath.isNotEmpty) {
            final String base = wifiSvc.serverAddress; // 不包含 /api
            // 确保 relativePath 以 '/' 开头
            final String normalizedRel = relativePath.startsWith('/') ? relativePath : '/$relativePath';
            // 避免 base 末尾有 '/' 时重复斜杠
            final String normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
            fullUrl = '$normalizedBase$normalizedRel';
          }

          final newRecord = InspectionRecord(
            id: imageId,
            sceneName: selectedScene.name,
            imagePath: fullUrl.isNotEmpty ? fullUrl : selectedScene.capturedImage!,
            timestamp: DateTime.now(),
            status: '已上传',
          );

          await homeViewModel.addInspectionRecord(newRecord);

          // 上传成功后，标记场景为已传输并记录传输时间
          // 中文说明：
          // - 更新 isTransferred=true，使按钮文案切换为“重新传输”，卡片边框变为绿色
          // - 记录 transferTime=now，便于后续审计或显示
          await homeViewModel.updateSceneTransferStatus(selectedScene.id, true);
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