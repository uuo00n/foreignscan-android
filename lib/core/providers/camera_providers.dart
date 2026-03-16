import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:foreignscan/core/services/camera_service.dart';
import 'package:foreignscan/core/providers/app_providers.dart';

enum CameraPermissionState {
  unknown,
  requesting,
  granted,
  denied,
  permanentlyDenied,
}

CameraPermissionState cameraPermissionStateFromStatus(PermissionStatus status) {
  if (status.isGranted) return CameraPermissionState.granted;
  if (status.isPermanentlyDenied) {
    return CameraPermissionState.permanentlyDenied;
  }
  return CameraPermissionState.denied;
}

// 相机服务提供者
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService(ref.read(loggerProvider));
});

// 相机权限状态提供者
final cameraPermissionStateProvider = StateProvider<CameraPermissionState>(
  (ref) => CameraPermissionState.unknown,
);

// 相机控制器提供者
final cameraControllerProvider =
    StateNotifierProvider.autoDispose<
      CameraControllerNotifier,
      AsyncValue<CameraController?>
    >((ref) {
      return CameraControllerNotifier(ref);
    });

// 相机初始化状态提供者
final cameraInitializationProvider = FutureProvider<bool>((ref) async {
  final permissionState = ref.watch(cameraPermissionStateProvider);
  if (permissionState != CameraPermissionState.granted) {
    return false;
  }
  try {
    final cameras = await availableCameras();
    return cameras.isNotEmpty;
  } catch (e) {
    return false;
  }
});

// 可用相机列表提供者
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((
  ref,
) async {
  final permissionState = ref.watch(cameraPermissionStateProvider);
  if (permissionState != CameraPermissionState.granted) {
    return <CameraDescription>[];
  }
  try {
    return await availableCameras();
  } catch (e) {
    return [];
  }
});

// 当前选中相机提供者
final selectedCameraProvider = StateProvider<int>((ref) => 0);

// 相机控制器状态管理器
class CameraControllerNotifier
    extends StateNotifier<AsyncValue<CameraController?>> {
  final Ref _ref;
  CameraController? _currentController;
  bool _isInitializing = false;

  // 不在构造函数中自动初始化，等待权限获得后由外部调用 initializeAfterPermission()
  CameraControllerNotifier(this._ref) : super(const AsyncValue.data(null));

  String _permissionErrorMessage(CameraPermissionState permissionState) {
    switch (permissionState) {
      case CameraPermissionState.permanentlyDenied:
        return '相机权限已被永久拒绝，请前往系统设置开启后重试';
      case CameraPermissionState.denied:
        return '相机权限未授予，请授权后再试';
      case CameraPermissionState.requesting:
        return '正在请求相机权限，请稍候';
      case CameraPermissionState.unknown:
        return '尚未获取相机权限状态，请稍后重试';
      case CameraPermissionState.granted:
        return '';
    }
  }

  bool _ensurePermissionGranted() {
    final permissionState = _ref.read(cameraPermissionStateProvider);
    if (permissionState == CameraPermissionState.granted) {
      return true;
    }

    final message = _permissionErrorMessage(permissionState);
    _ref.read(cameraErrorProvider.notifier).state = message;
    state = AsyncValue.error(message, StackTrace.empty);
    return false;
  }

  /// 权限获得后调用此方法初始化相机
  Future<void> initializeAfterPermission() async {
    if (_isInitializing) return;
    if (!_ensurePermissionGranted()) return;

    _ref.read(cameraErrorProvider.notifier).state = null;
    state = const AsyncValue.loading();
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    if (!_ensurePermissionGranted()) return;

    _isInitializing = true;
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
            const message = '没有可用的相机';
            state = const AsyncValue.error(message, StackTrace.empty);
            _ref.read(cameraErrorProvider.notifier).state = message;
            _isInitializing = false;
            return;
          }

          final selectedCameraIndex = _ref.read(selectedCameraProvider);
          final camera =
              cameras[selectedCameraIndex.clamp(0, cameras.length - 1)];

          _currentController = CameraController(
            camera,
            ResolutionPreset.max,
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
            _ref
                .read(loggerProvider)
                .e(
                  '相机初始化失败 (尝试 ${retryCount + 1}/$maxRetries)',
                  error: initError,
                );
            if (_currentController != null) {
              await _currentController!.dispose();
              _currentController = null;
            }

            // 如果是最后一次尝试，则抛出错误
            if (retryCount == maxRetries - 1) {
              rethrow;
            }

            // 否则继续重试
            retryCount++;
            continue;
          }

          if (initialized && _currentController != null) {
            try {
              await _currentController!.setFlashMode(FlashMode.off);
            } catch (e) {
              _ref.read(loggerProvider).w('设置闪光灯为关闭失败: $e');
            }
            _ref.read(cameraErrorProvider.notifier).state = null;
            state = AsyncValue.data(_currentController);
            _ref.read(loggerProvider).i('相机初始化成功: ${camera.name}');
            _isInitializing = false;
            return;
          }
        } catch (e, stackTrace) {
          if (retryCount == maxRetries - 1) {
            state = AsyncValue.error(e, stackTrace);
            _ref.read(cameraErrorProvider.notifier).state = '相机初始化失败: $e';
            _ref.read(loggerProvider).e('相机初始化失败，已达到最大重试次数', error: e);
            _isInitializing = false;
            return;
          }

          retryCount++;
        }
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      _ref.read(cameraErrorProvider.notifier).state = '相机初始化失败: $e';
      _ref.read(loggerProvider).e('相机初始化失败', error: e, stackTrace: stackTrace);
    }
    _isInitializing = false;
  }

  Future<void> switchCamera(int cameraIndex) async {
    if (!_ensurePermissionGranted()) return;
    try {
      final cameras = await availableCameras();
      if (cameraIndex < 0 || cameraIndex >= cameras.length) {
        throw Exception('无效的相机索引: $cameraIndex');
      }

      // 保存新的相机索引
      _ref.read(selectedCameraProvider.notifier).state = cameraIndex;

      // 重新初始化相机
      _isInitializing = false; // 重置标志，允许重新初始化
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

  /// 刷新相机 — 重置初始化标志，确保不被阻塞
  Future<void> refreshCamera() async {
    if (!_ensurePermissionGranted()) return;
    _isInitializing = false;
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

// 相机错误信息提供者
final cameraErrorProvider = StateProvider<String?>((ref) => null);
