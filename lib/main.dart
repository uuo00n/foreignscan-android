import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/config/app_config.dart';
import 'package:foreignscan/config/app_constants.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/providers/camera_providers.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ProviderScope(child: IndustrialInspectionApp()));
}

class IndustrialInspectionApp extends ConsumerStatefulWidget {
  const IndustrialInspectionApp({super.key});

  @override
  ConsumerState<IndustrialInspectionApp> createState() =>
      _IndustrialInspectionAppState();
}

class _IndustrialInspectionAppState
    extends ConsumerState<IndustrialInspectionApp> {
  ProviderSubscription<AsyncValue<bool>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = ref.listenManual<AsyncValue<bool>>(
      connectivityProvider,
      (previous, next) {
        next.whenData((isOnline) {
          if (isOnline) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = AppRouter.navigatorKey.currentContext;
            if (navContext == null) return;
            ScaffoldMessenger.maybeOf(navContext)?.showSnackBar(
              const SnackBar(
                content: Text('网络连接已断开'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          });
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCameraPermissionOnStartup();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.close();
    super.dispose();
  }

  Future<void> _requestCameraPermissionOnStartup() async {
    if (!Platform.isAndroid) return;

    ref.read(cameraPermissionStateProvider.notifier).state =
        CameraPermissionState.requesting;
    final status = await ref
        .read(cameraServiceProvider)
        .requestCameraPermissionStatus();
    if (!mounted) return;

    ref.read(cameraPermissionStateProvider.notifier).state =
        cameraPermissionStateFromStatus(status);
  }

  @override
  Widget build(BuildContext context) {
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
