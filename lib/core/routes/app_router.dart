import 'package:flutter/material.dart';
import 'package:foreignscan/config/app_constants.dart';
import 'package:foreignscan/screens/home_page.dart';
import 'package:foreignscan/screens/camera_screen.dart';
import 'package:foreignscan/screens/detection_result_screen.dart';

class DetectionResultArguments {
  final String imagePath;
  final String detectionType;
  final Map<String, dynamic>? detectionResults;
  
  const DetectionResultArguments({
    required this.imagePath,
    required this.detectionType,
    this.detectionResults,
  });
}

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
  
  static void navigateToDetectionResult(DetectionResultArguments arguments) {
    navigatorKey.currentState?.pushNamed(
      AppConstants.routeDetectionResult,
      arguments: arguments,
    );
  }
  
  static void goBack() {
    navigatorKey.currentState?.pop();
  }
  
  static void goBackToHome() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}