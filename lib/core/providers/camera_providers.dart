import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:foreignscan/core/services/camera_service.dart';
import 'package:foreignscan/core/providers/app_providers.dart';

// 相机服务提供者
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService(ref.read(loggerProvider));
});

// 相机控制器提供者
final cameraControllerProvider = StateNotifierProvider<CameraControllerNotifier, AsyncValue<CameraController?>>((ref) {
  return CameraControllerNotifier(ref);
});

// 相机初始化状态提供者
final cameraInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    final cameras = await availableCameras();
    return cameras.isNotEmpty;
  } catch (e) {
    return false;
  }
});

// 可用相机列表提供者
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    return await availableCameras();
  } catch (e) {
    return [];
  }
});

// 当前选中相机提供者
final selectedCameraProvider = StateProvider<int>((ref) => 0);

// 相机控制器状态管理器
class CameraControllerNotifier extends StateNotifier<AsyncValue<CameraController?>> {
  final Ref _ref;
  CameraController? _currentController;

  CameraControllerNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    const int maxRetries = 3;
    int retryCount = 0;
    
    try {
      while (retryCount < maxRetries) {
        try {
          state = const AsyncValue.loading();
          
          // 先释放旧的相机资源
          if (_currentController != null) {
            await _currentController!.dispose();
            _currentController = null;
          }
          
          // 添加延迟，确保旧相机资源完全释放
          await Future.delayed(const Duration(milliseconds: 500));
          
          final cameras = await availableCameras();
          if (cameras.isEmpty) {
            state = const AsyncValue.error('没有可用的相机', StackTrace.empty);
            return;
          }

          final selectedCameraIndex = _ref.read(selectedCameraProvider);
          final camera = cameras[selectedCameraIndex.clamp(0, cameras.length - 1)];
          
          _currentController = CameraController(
            camera,
            ResolutionPreset.high,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );

          // 使用超时处理初始化
          bool initialized = false;
          try {
            await _currentController!.initialize().timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                throw Exception('相机初始化超时');
              },
            );
            initialized = true;
          } catch (initError) {
            _ref.read(loggerProvider).e('相机初始化失败 (尝试 ${retryCount + 1}/$maxRetries)', error: initError);
            if (_currentController != null) {
              await _currentController!.dispose();
              _currentController = null;
            }
            
            // 如果是最后一次尝试，则抛出错误
            if (retryCount == maxRetries - 1) {
              throw initError;
            }
            
            // 否则继续重试
            retryCount++;
            continue;
          }
          
          if (initialized && _currentController != null) {
            // 中文注释：
            // 初始化完成后，显式设置闪光灯为关闭状态，避免某些设备或插件默认使用自动闪光导致拍照时自动亮灯。
            try {
              await _currentController!.setFlashMode(FlashMode.off);
            } catch (e) {
              // 设置闪光灯失败不影响整体初始化，仅记录日志
              _ref.read(loggerProvider).w('设置闪光灯为关闭失败: $e');
            }
            state = AsyncValue.data(_currentController);
            _ref.read(loggerProvider).i('相机初始化成功: ${camera.name}');
            return; // 成功初始化，退出循环
          }
        } catch (e, stackTrace) {
          if (retryCount == maxRetries - 1) {
            // 最后一次尝试失败，设置错误状态
            state = AsyncValue.error(e, stackTrace);
            _ref.read(loggerProvider).e('相机初始化失败，已达到最大重试次数', error: e);
            return;
          }
          
          retryCount++;
        }
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      _ref.read(loggerProvider).e('相机初始化失败', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> switchCamera(int cameraIndex) async {
    try {
      final cameras = await availableCameras();
      if (cameraIndex < 0 || cameraIndex >= cameras.length) {
        throw Exception('无效的相机索引: $cameraIndex');
      }

      // 保存新的相机索引
      _ref.read(selectedCameraProvider.notifier).state = cameraIndex;
      
      // 重新初始化相机
      await _initializeCamera();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      _ref.read(loggerProvider).e('切换相机失败', error: e, stackTrace: stackTrace);
    }
  }

  Future<String?> takePicture() async {
    try {
      final controller = state.value;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('相机未初始化');
      }

      if (controller.value.isTakingPicture) {
        throw Exception('正在拍照中');
      }

      final image = await controller.takePicture();
      _ref.read(loggerProvider).i('拍照成功: ${image.path}');
      return image.path;
    } catch (e, stackTrace) {
      _ref.read(loggerProvider).e('拍照失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> refreshCamera() async {
    await _initializeCamera();
  }

  Future<void> disposeCamera() async {
    if (_currentController != null) {
      await _currentController!.dispose();
      _currentController = null;
      state = const AsyncValue.data(null);
    }
  }

  @override
  void dispose() {
    disposeCamera();
    super.dispose();
  }
}

// 相机权限状态提供者
final cameraPermissionProvider = StateProvider<bool>((ref) => false);

// 相机错误信息提供者
final cameraErrorProvider = StateProvider<String?>((ref) => null);