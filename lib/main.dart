import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/config/app_config.dart';
import 'package:foreignscan/config/app_constants.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/utils/camera_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化相机
  await CameraManager.initialize();
  
  runApp(
    ProviderScope(
      child: IndustrialInspectionApp(),
    ),
  );
}

class IndustrialInspectionApp extends ConsumerWidget {
  const IndustrialInspectionApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听网络状态变化
    ref.listen(connectivityProvider, (previous, next) {
      next.whenData((isOnline) {
        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('网络连接已断开'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    });

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppConstants.routeHome,
      onGenerateRoute: AppRouter.onGenerateRoute,
      navigatorKey: AppRouter.navigatorKey,
    );
  }
}