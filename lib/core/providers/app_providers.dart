import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:foreignscan/config/app_config.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';

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
  final svc = WiFiCommunicationService(ref.read(loggerProvider));
  // 中文注释：将当前 Dio 的 baseUrl 解析为 host/port，初始化 WiFi 服务的服务器地址，避免默认值不一致
  try {
    final dio = ref.read(dioProvider);
    final uri = Uri.parse(dio.options.baseUrl);
    if (uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      svc.setServerAddress(uri.host, port);
    }
  } catch (_) {}
  return svc;
});

// 本地图片缓存服务提供者
final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService(ref.read(dioProvider));
});