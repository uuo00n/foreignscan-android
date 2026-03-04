import 'package:flutter/material.dart';
import 'package:foreignscan/config/app_constants.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/screens/home_page.dart';
import 'package:foreignscan/screens/camera_screen.dart';
import 'package:foreignscan/screens/detection_result_screen.dart';
import 'package:foreignscan/screens/image_upload_screen.dart';
import 'package:foreignscan/screens/settings_screen.dart';

class DetectionResultArguments {
  final String imagePath;
  final String detectionType;
  final Map<String, dynamic>? detectionResults;
  final String? imageId; // 中文注释：新增图片ID，用于按图片查询详细检测结果

  const DetectionResultArguments({
    required this.imagePath,
    required this.detectionType,
    this.detectionResults,
    this.imageId,
  });
}

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case AppConstants.routeHome:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );

      case AppConstants.routeCamera:
        return MaterialPageRoute(
          builder: (_) => CameraScreen(),
          settings: settings,
        );

      case AppConstants.routeDetectionResult:
        if (args is DetectionResultArguments) {
          return MaterialPageRoute(
            builder: (_) => DetectionResultScreen(arguments: args),
            settings: settings,
          );
        }
        return _errorRoute(settings);

      case AppConstants.routeImageUpload:
        if (args is Map<String, dynamic>) {
          final imagePath = args['imagePath'] as String?;
          return MaterialPageRoute(
            builder: (_) => ImageUploadScreen(imagePath: imagePath),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ImageUploadScreen(),
          settings: settings,
        );

      case AppConstants.routeSettings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      default:
        return _errorRoute(settings);
    }
  }

  static Route<dynamic> _errorRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('页面未找到')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                '页面未找到: ${settings.name}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => navigatorKey.currentState?.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 导航辅助方法
  static void navigateToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppConstants.routeHome,
      (route) => false,
    );
  }

  static void navigateToCamera() {
    navigatorKey.currentState?.pushNamed(AppConstants.routeCamera);
  }

  static Future<String?> navigateToCameraForResult() {
    return navigatorKey.currentState?.pushNamed<String>(
          AppConstants.routeCamera,
        ) ??
        Future.value(null);
  }

  static void navigateToDetectionResult(DetectionResultArguments arguments) {
    navigatorKey.currentState?.pushNamed(
      AppConstants.routeDetectionResult,
      arguments: arguments,
    );
  }

  static Future<void> navigateToImageUpload({String? imagePath}) async {
    await navigatorKey.currentState?.pushNamed(
      AppConstants.routeImageUpload,
      arguments: {'imagePath': imagePath},
    );
  }

  static void navigateToSettings() {
    navigatorKey.currentState?.pushNamed(AppConstants.routeSettings);
  }

  static void goBack() {
    navigatorKey.currentState?.pop();
  }

  static void goBackToHome() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
