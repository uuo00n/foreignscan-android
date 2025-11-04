import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:foreignscan/config/app_config.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';

// 全局服务提供者
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );
});

final dioProvider = Provider<Dio>((ref) {
  // 使用统一的后端 API 基础地址与超时设置
  final dio = Dio(
    BaseOptions(
      // 说明：NetworkConfig 的字段是静态常量，必须通过类名访问，而不是通过实例访问
      baseUrl: NetworkConfig.apiBaseUrl, // 后端 API 基础地址
      connectTimeout: NetworkConfig.timeout, // 连接超时
      receiveTimeout: NetworkConfig.timeout, // 接收超时
      sendTimeout: NetworkConfig.timeout, // 发送超时
    ),
  );
  
  // 添加拦截器
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加公共请求头
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';
        
        // 记录请求日志
        ref.read(loggerProvider).d(
          'API Request: ${options.method} ${options.uri}',
        );
        
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 记录响应日志
        ref.read(loggerProvider).d(
          'API Response: ${response.statusCode} ${response.requestOptions.uri}',
        );
        
        return handler.next(response);
      },
      onError: (error, handler) {
        // 记录错误日志
        ref.read(loggerProvider).e(
          'API Error: ${error.message}',
          error: error,
          stackTrace: error.stackTrace,
        );
        
        return handler.next(error);
      },
    ),
  );
  
  return dio;
});

// 相机控制器提供者
final cameraControllerProvider = StateNotifierProvider<CameraControllerNotifier, AsyncValue<CameraController?>>((ref) {
  return CameraControllerNotifier(ref);
});

class CameraControllerNotifier extends StateNotifier<AsyncValue<CameraController?>> {
  final Ref _ref;
  
  CameraControllerNotifier(this._ref) : super(const AsyncValue.loading());
  
  Future<void> initializeCamera() async {
    try {
      state = const AsyncValue.loading();
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = const AsyncValue.error('没有可用的相机', StackTrace.empty);
        return;
      }
      
  final controller = CameraController(
    cameras.first,
    ResolutionPreset.high,
    enableAudio: false,
  );
  
  await controller.initialize();
  // 中文注释：
  // 初始化后显式关闭闪光灯，避免设备/插件默认自动闪光导致拍照时亮灯。
  try {
    await controller.setFlashMode(FlashMode.off);
  } catch (e) {
    _ref.read(loggerProvider).w('设置闪光灯为关闭失败: $e');
  }
  state = AsyncValue.data(controller);
      
      _ref.read(loggerProvider).i('相机初始化成功');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      _ref.read(loggerProvider).e('相机初始化失败', error: e, stackTrace: stackTrace);
    }
  }
  
  Future<void> disposeCamera() async {
    final controller = state.value;
    if (controller != null) {
      await controller.dispose();
      state = const AsyncValue.data(null);
    }
  }
  
  @override
  void dispose() {
    disposeCamera();
    super.dispose();
  }
}

// 网络连接状态提供者
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  
  return connectivity.onConnectivityChanged.map((results) {
    return !results.contains(ConnectivityResult.none);
  }).asBroadcastStream();
});

// 当前网络状态提供者
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);
  return connectivityAsync.value ?? true;
});

// WiFi通信服务提供者
final wifiCommunicationServiceProvider = Provider<WiFiCommunicationService>((ref) {
  return WiFiCommunicationService(ref.read(loggerProvider));
});