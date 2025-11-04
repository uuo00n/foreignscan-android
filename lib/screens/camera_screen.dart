import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:foreignscan/core/providers/camera_providers.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import 'package:foreignscan/core/widgets/error_widget.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // 添加闪光灯状态
  FlashMode _flashMode = FlashMode.off;
  
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      // 检查相机权限
      final hasPermission = await ref
          .read(cameraServiceProvider)
          .requestCameraPermission();

      if (!mounted) return; // 检查widget是否已被销毁

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要相机权限才能拍照'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 初始化相机
      if (mounted) {
        ref.read(cameraControllerProvider.notifier).refreshCamera();
      }
    } catch (e) {
      debugPrint('初始化相机错误: $e');
    }
  }

  @override
  void dispose() {
    ref.read(cameraControllerProvider.notifier).disposeCamera();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      // 获取当前相机控制器
      final controller = ref.read(cameraControllerProvider).value;
      
      if (controller != null) {
        // 拍照前记录当前闪光灯状态
        final currentFlashMode = _flashMode;
        // 中文注释：
        // 不再在“自动模式”下强行切换到常亮（torch），而是遵循控制器的自动策略：
        // - 如果当前为 FlashMode.auto，保持自动模式，由系统根据环境光决定是否触发闪光
        // - 如果当前为 FlashMode.off 或 FlashMode.torch，按用户选择执行，无需临时切换
        
        // 拍照
        final imagePath = await ref
            .read(cameraControllerProvider.notifier)
            .takePicture();
            
        // 中文注释：
        // 拍照完成后，不再强制恢复为关闭，保持用户选择的闪光灯模式，提升一致性。
        // 若需要拍完即关闭，可根据需求在此处恢复为 off。
        
        if (mounted && imagePath != null) {
          // 直接返回拍摄的照片路径
          Navigator.pop(context, imagePath);
        }
      } else {
        // 相机控制器为空，直接拍照
        final imagePath = await ref
            .read(cameraControllerProvider.notifier)
            .takePicture();
            
        if (mounted && imagePath != null) {
          Navigator.pop(context, imagePath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    final cameras = await ref.read(availableCamerasProvider.future);
    if (cameras.length <= 1) return;

    // 显示切换中提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在切换相机...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    }

    final currentIndex = ref.read(selectedCameraProvider);
    final nextIndex = (currentIndex + 1) % cameras.length;

    // 强制重新初始化相机
    await ref.read(cameraControllerProvider.notifier).switchCamera(nextIndex);
    
    // 如果相机初始化失败，尝试再次切换
    final cameraState = ref.read(cameraControllerProvider);
    if (cameraState is AsyncError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('相机切换失败，正在重试...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // 短暂延迟后再次尝试
      await Future.delayed(const Duration(milliseconds: 500));
      await ref.read(cameraControllerProvider.notifier).refreshCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final camerasAsync = ref.watch(availableCamerasProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('拍摄照片'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // 禁用自动添加的返回按钮
        actions: [
          camerasAsync.when(
            data: (cameras) {
              if (cameras.length > 1) {
                return IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  onPressed: _switchCamera,
                  tooltip: '切换相机',
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cameraState.when(
        loading: () =>
            const LoadingWidget(message: '正在初始化相机...', color: Colors.white),
        error: (error, stackTrace) => ErrorWidgetCustom(
          message: '相机初始化失败: $error',
          onRetry: () =>
              ref.read(cameraControllerProvider.notifier).refreshCamera(),
          icon: Icons.camera_alt,
        ),
        data: (controller) {
          if (controller == null) {
            return ErrorWidgetCustom(
              message: '无法访问相机设备',
              onRetry: () =>
                  ref.read(cameraControllerProvider.notifier).refreshCamera(),
              icon: Icons.camera_alt,
            );
          }

          return Stack(
            children: [
              // 相机预览
              Positioned.fill(child: CameraPreview(controller)),

              // 右侧控制面板
              Positioned(
                right: 30,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 闪光灯控制
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : (_flashMode == FlashMode.auto
                                    ? Icons.flash_auto
                                    : Icons.flash_on),
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (controller != null) {
                              // 循环切换闪光灯模式
                              setState(() {
                                _flashMode = _flashMode == FlashMode.off
                                    ? FlashMode.auto
                                    : (_flashMode == FlashMode.auto
                                        ? FlashMode.torch
                                        : FlashMode.off);
                              });
                               
                              // 应用闪光灯设置
                              await controller.setFlashMode(_flashMode);
                            }
                          },
                          tooltip: '闪光灯控制',
                        ),
                      ),
                      
                      // 拍照按钮
                      FloatingActionButton(
                        onPressed: _takePicture,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        child: const Icon(Icons.camera, size: 32),
                      ),
                    ],
                  ),
                ),
              ),

              // 返回按钮
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
