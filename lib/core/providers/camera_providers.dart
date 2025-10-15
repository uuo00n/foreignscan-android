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
    try {
      state = const AsyncValue.loading();
      
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
        imageFormatGroup: ImageFormatGroup.yuv420, // Better compatibility with Impeller
      );

      await _currentController!.initialize();
      state = AsyncValue.data(_currentController);
      
      _ref.read(loggerProvider).i('相机初始化成功: ${camera.name}');
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

      // Ensure preview is ready before taking picture
      if (!controller.value.isPreviewPaused) {
        await controller.lockCaptureOrientation();
      }

      final image = await controller.takePicture();
      await controller.unlockCaptureOrientation();
      
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
      if (_currentController!.value.isInitialized) {
        await _currentController!.dispose();
      }
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