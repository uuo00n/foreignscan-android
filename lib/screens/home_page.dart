import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/providers/camera_providers.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import 'package:foreignscan/core/widgets/error_widget.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/core/widgets/dialog_safety.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/widgets/app_drawer.dart';
import 'package:foreignscan/screens/home/controllers/home_workflow_controller.dart';
import 'package:foreignscan/screens/home/widgets/home_main_layout.dart';
import 'package:foreignscan/screens/home/widgets/server_setup_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hasPromptedSetup = false; // 防止重复弹窗
  ProviderSubscription<HomeState>? _homeStateSubscription;

  HomeWorkflowController _workflow(WidgetRef ref) {
    return HomeWorkflowController(ref);
  }

  @override
  void initState() {
    super.initState();
    _homeStateSubscription = ref.listenManual<HomeState>(
      homeViewModelProvider,
      (previous, next) {
        final errorMessage = next.errorMessage;
        if (!mounted || errorMessage == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '重试',
                textColor: AppTheme.textInverse,
                onPressed: () {
                  final homeViewModel = ref.read(
                    homeViewModelProvider.notifier,
                  );
                  homeViewModel.clearError();
                  homeViewModel.refreshData();
                },
              ),
            ),
          );
        });
      },
    );
    // 中文注释：首帧后检查是否已配置服务器，未配置则弹出设置对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptServerSetupIfNeeded();
    });
  }

  @override
  void dispose() {
    _homeStateSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    // 使用WillPopScope处理返回手势
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 显示退出确认对话框
        _showExitConfirmDialog(context);
      },
      child: Scaffold(
        // 中文注释：移除每次 build 重新创建的 GlobalKey，避免频繁重建带来的潜在问题。
        appBar: _buildAppBar(context, ref),
        drawer: AppDrawer(
          onUploadPressed: () => _uploadLatestImage(context, ref),
          onSyncPressed: _handleSync,
        ),
        body: homeState.isLoading
            ? const LoadingWidget(message: '正在加载数据...')
            : homeState.errorMessage != null
            ? ErrorWidgetCustom(
                message: homeState.errorMessage!,
                onRetry: () => homeViewModel.refreshData(),
              )
            : _buildBody(context, ref, homeState, homeViewModel),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      // 中文注释：使用 Builder 获取位于 Scaffold 之下的上下文，
      // 通过 Scaffold.of(context).openDrawer() 打开抽屉，避免对 GlobalKey 的依赖。
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(ctx).openDrawer();
          },
        ),
      ),
      title: const Text('智能防异物检测系统'),
      actions: [
        // 中文注释：屏蔽首页的“新建检测”按钮，仅保留“检测结果”入口
        AppBarActions(
          showNewDetection: false,
          showRecords: true,
          onNewDetectionPressed: () => _startNewInspection(context, ref),
          onDetectionResultsPressed: () => AppRouter.navigateToDetectionResult(
            const DetectionResultArguments(imagePath: '', detectionType: ''),
          ),
          onRecordsPressed: () => AppRouter.navigateToRecords(),
        ),
      ],
    );
  }

  // 中文注释：检查是否已配置服务器；若未配置，则弹出引导对话框
  Future<void> _promptServerSetupIfNeeded() async {
    if (_hasPromptedSetup) return; // 防止重复执行
    try {
      final serverConfigService = ref.read(serverConfigServiceProvider);
      final config = await serverConfigService.load();
      if (!mounted) return;
      if (!config.isConfigured) {
        _hasPromptedSetup = true;
        await _showServerSetupDialog(
          initialIp: config.ip ?? '',
          initialPort: config.port,
        );
      } else {
        // 配置已存在，统一应用并初始化数据
        final dio = ref.read(dioProvider);
        final wifiService = ref.read(wifiServiceProvider);
        await serverConfigService.applyToClients(
          dio: dio,
          wifiService: wifiService,
          config: config,
        );
        _schedulePostConfigRefresh();
      }
    } catch (e) {
      ref.read(loggerProvider).w('首次启动配置检查失败: $e');
    }
  }

  void _schedulePostConfigRefresh({bool showSuccess = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(styleImagesForSelectedSceneProvider);
      ref.read(homeViewModelProvider.notifier).initializeData();
      if (!showSuccess) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('服务器已配置成功'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // 中文注释：首次安装的服务器设置弹窗
  Future<void> _showServerSetupDialog({
    required String initialIp,
    required int? initialPort,
    String initialBindKey = '',
  }) async {
    final result = await showServerSetupDialog(
      context: context,
      initialIp: initialIp,
      initialPort: initialPort,
      initialBindKey: initialBindKey,
      onTestConnection: (ip, port) async {
        final wifiService = ref.read(wifiServiceProvider);
        wifiService.setServerAddress(ip, port);
        try {
          return await wifiService.testConnection();
        } catch (e) {
          ref.read(loggerProvider).w('连接测试异常: $e');
          return false;
        }
      },
    );

    if (!mounted || result == null) return;

    final serverConfigService = ref.read(serverConfigServiceProvider);
    final dio = ref.read(dioProvider);
    final wifiService = ref.read(wifiServiceProvider);

    try {
      final bindResult = await serverConfigService.bindPadWithKey(
        ip: result.ip,
        port: result.port,
        isWiredMode: result.isWiredMode,
        bindKey: result.bindKey,
      );
      if (!bindResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(bindResult.message),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      await serverConfigService.applyToClients(
        dio: dio,
        wifiService: wifiService,
      );
    } catch (e) {
      ref.read(loggerProvider).w('保存服务器配置失败: $e');
    }
    _schedulePostConfigRefresh(showSuccess: true);
  }

  // 显示退出确认对话框
  Future<void> _showExitConfirmDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出应用吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    ).then((value) {
      if (value == true) {
        // 如果用户确认退出，则使用SystemNavigator.pop()完全退出应用
        SystemNavigator.pop();
      }
    });
  }

  Future<void> _uploadLatestImage(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.selectedScene;

    if (selectedScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('场景索引异常，请刷新重试'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (selectedScene.capturedImage == null ||
        selectedScene.capturedImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可上传的图片，请先拍摄照片'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // 显示上传进度对话框
    BuildContext? progressDialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressDialogContext = dialogContext;
        return const AlertDialog(
          title: Text('正在校验并上传'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在进行场景一致性校验并上传图片，请稍候...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await _workflow(ref).uploadSceneImage(selectedScene);
      if (!context.mounted) {
        return;
      }

      if (result.success) {
        final similarity = result.similarity;
        if (similarity != null) {
          await ref
              .read(homeViewModelProvider.notifier)
              .updateSceneSimilarityStatus(
                selectedScene.id,
                passed: true,
                similarityPercent: HomeWorkflowController.similarityPercent(
                  similarity.bestScore,
                ),
                styleImageId: similarity.bestStyleImageId,
              );
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _buildTransferSuccessMessage(result, successLabel: '图片上传成功'),
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        return;
      }

      if (_hasPointCandidates(result)) {
        await ref
            .read(homeViewModelProvider.notifier)
            .updateSceneSimilarityStatus(selectedScene.id, passed: false);
        if (!context.mounted) return;
        await _showPointCandidatesDialog(
          context,
          ref,
          sourceScene: selectedScene,
          imagePath: selectedScene.capturedImage!,
          result: result,
        );
        return;
      }

      if (_isSimilarityFailure(result)) {
        await ref
            .read(homeViewModelProvider.notifier)
            .updateSceneSimilarityStatus(selectedScene.id, passed: false);
        if (!context.mounted) return;
        await _showSimilarityFailedDialog(context, ref, result);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '图片上传失败，请检查网络连接和服务器设置'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      DialogSafety.popIfMounted(progressDialogContext);
    }
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    HomeState homeState,
    HomeViewModel homeViewModel,
  ) {
    if (homeState.scenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: AppTheme.dividerColor),
            const SizedBox(height: 16),
            Text(
              '暂无场景数据',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '请联系管理员添加检测场景',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => homeViewModel.refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    final selectedScene = homeState.selectedScene;
    if (selectedScene == null) {
      return Center(
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
              '场景索引异常',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => homeViewModel.refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    final refImageAsync = ref.watch(referenceImageUrlProvider);
    return HomeMainLayout(
      homeState: homeState,
      homeViewModel: homeViewModel,
      selectedScene: selectedScene,
      onCaptureClick: () => _navigateToCamera(context, ref),
      onConfirmTransfer: () => _confirmTransfer(context, ref),
      onTransferAll: () => _transferAll(context, ref),
      referenceImageUrl: refImageAsync.maybeWhen(
        data: (v) => v,
        orElse: () => null,
      ),
      isReferenceLoading: refImageAsync.isLoading,
    );
  }

  Future<void> _startNewInspection(BuildContext context, WidgetRef ref) async {
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    if (ref.read(homeViewModelProvider).scenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无可用检测场景'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // 重置到第一个场景
    homeViewModel.selectScene(0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请选择检测场景开始检测'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<CameraPermissionState> _refreshCameraPermissionState(
    WidgetRef ref,
  ) async {
    final status = await ref
        .read(cameraServiceProvider)
        .checkCameraPermissionStatus();
    final mapped = cameraPermissionStateFromStatus(status);
    ref.read(cameraPermissionStateProvider.notifier).state = mapped;
    return mapped;
  }

  Future<CameraPermissionState> _requestCameraPermission(WidgetRef ref) async {
    ref.read(cameraPermissionStateProvider.notifier).state =
        CameraPermissionState.requesting;
    final status = await ref
        .read(cameraServiceProvider)
        .requestCameraPermissionStatus();
    final mapped = cameraPermissionStateFromStatus(status);
    ref.read(cameraPermissionStateProvider.notifier).state = mapped;
    return mapped;
  }

  Future<bool> _ensureCameraPermissionBeforeCapture(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var permissionState = ref.read(cameraPermissionStateProvider);

    if (permissionState == CameraPermissionState.unknown ||
        permissionState == CameraPermissionState.requesting) {
      permissionState = await _refreshCameraPermissionState(ref);
    }
    if (!context.mounted) return false;

    if (permissionState == CameraPermissionState.granted) {
      return true;
    }

    if (permissionState == CameraPermissionState.denied) {
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要相机权限'),
          content: const Text('未授予相机权限，是否重新授权？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('重新授权'),
            ),
          ],
        ),
      );
      if (shouldRetry != true || !context.mounted) return false;

      permissionState = await _requestCameraPermission(ref);
      if (!context.mounted) return false;
      if (permissionState == CameraPermissionState.granted) {
        return true;
      }
    }

    if (permissionState == CameraPermissionState.permanentlyDenied) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('相机权限已被禁用'),
          content: const Text('请前往系统设置开启相机权限后再拍照。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await ref.read(cameraServiceProvider).openCameraPermissionSettings();
        permissionState = await _refreshCameraPermissionState(ref);
      }
    }

    if (!context.mounted) return false;
    if (permissionState == CameraPermissionState.granted) {
      return true;
    }

    final message = permissionState == CameraPermissionState.permanentlyDenied
        ? '请在系统设置中开启相机权限后再试'
        : '未获得相机权限，无法拍照';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.warningColor),
    );
    return false;
  }

  void _showCaptureValidationProgressDialog(
    BuildContext context,
    ValueChanged<BuildContext> onDialogReady,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        onDialogReady(ctx);
        return const AlertDialog(
          title: Text('正在校验场景'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在进行场景一致性比对，请稍候...'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToCamera(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.selectedScene;

    if (selectedScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('场景索引异常，请刷新重试'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final hasPermission = await _ensureCameraPermissionBeforeCapture(
      context,
      ref,
    );
    if (!hasPermission) return;

    try {
      // 使用统一路由系统导航到相机页面
      final imagePath = await AppRouter.navigateToCameraForResult();

      // 处理相机返回的结果
      if (imagePath != null) {
        if (!context.mounted) return;
        var validationDialogShown = false;
        BuildContext? validationDialogContext;
        SceneTransferResult validationResult;
        try {
          _showCaptureValidationProgressDialog(context, (dialogCtx) {
            validationDialogContext = dialogCtx;
          });
          validationDialogShown = true;
          validationResult = await _workflow(
            ref,
          ).validateCapturedScene(selectedScene, imagePath);
          if (context.mounted && validationDialogShown) {
            DialogSafety.popIfMounted(validationDialogContext);
            validationDialogShown = false;
          }
        } catch (e) {
          if (context.mounted && validationDialogShown) {
            DialogSafety.popIfMounted(validationDialogContext);
          }
          rethrow;
        }
        if (!context.mounted) return;

        if (_hasPointCandidates(validationResult)) {
          await _showPointCandidatesDialog(
            context,
            ref,
            sourceScene: selectedScene,
            imagePath: imagePath,
            result: validationResult,
          );
          return;
        }

        if (_isSimilarityFailure(validationResult)) {
          await ref
              .read(homeViewModelProvider.notifier)
              .updateSceneSimilarityStatus(selectedScene.id, passed: false);
          if (!context.mounted) return;
          await _showSimilarityFailedDialog(context, ref, validationResult);
          return;
        }
        if (!validationResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validationResult.errorMessage ?? '场景校验失败'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        final homeViewModel = ref.read(homeViewModelProvider.notifier);
        await homeViewModel.updateSceneImage(selectedScene.id, imagePath);
        final similarity = validationResult.similarity;
        if (similarity != null) {
          await homeViewModel.updateSceneSimilarityStatus(
            selectedScene.id,
            passed: true,
            similarityPercent: HomeWorkflowController.similarityPercent(
              similarity.bestScore,
            ),
            styleImageId: similarity.bestStyleImageId,
          );
        }

        if (!context.mounted) return;
        await _showMatchSuccessDialog(context, ref, validationResult);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍摄流程失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmTransfer(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.selectedScene;

    if (selectedScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('场景索引异常，请刷新重试'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (selectedScene.capturedImage == null ||
        selectedScene.capturedImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先拍摄该场景'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // 中文注释：若该场景图片已传输过，提示用户是否重复上传
    if (selectedScene.isTransferred) {
      final shouldRetransfer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('重复传输提示'),
          content: const Text('该照片已经上传过了，是否再次传输？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('再次传输'),
            ),
          ],
        ),
      );

      if (shouldRetransfer != true) return;
    }

    if (!context.mounted) return;

    // 显示上传进度对话框
    BuildContext? progressDialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressDialogContext = dialogContext;
        return const AlertDialog(
          title: Text('正在校验并传输'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在进行场景一致性校验并传输图片，请稍候...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await _workflow(ref).transferScene(selectedScene);
      if (!context.mounted) {
        return;
      }

      if (_hasPointCandidates(result)) {
        await ref
            .read(homeViewModelProvider.notifier)
            .updateSceneSimilarityStatus(selectedScene.id, passed: false);
        if (!context.mounted) return;
        await _showPointCandidatesDialog(
          context,
          ref,
          sourceScene: selectedScene,
          imagePath: selectedScene.capturedImage!,
          result: result,
        );
        return;
      }

      if (_isSimilarityFailure(result)) {
        await ref
            .read(homeViewModelProvider.notifier)
            .updateSceneSimilarityStatus(selectedScene.id, passed: false);
        if (!context.mounted) return;
        await _showSimilarityFailedDialog(context, ref, result);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? _buildTransferSuccessMessage(result, successLabel: '传输成功')
                : (result.errorMessage ?? '传输失败'),
          ),
          backgroundColor: result.success
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    } finally {
      DialogSafety.popIfMounted(progressDialogContext);
    }
  }

  bool _isSimilarityFailure(SceneTransferResult result) {
    return result.failureType == SceneTransferFailureType.similarityTooLow;
  }

  bool _hasPointCandidates(SceneTransferResult result) {
    final similarity = result.similarity;
    return result.failureType ==
            SceneTransferFailureType.pointCandidatesFound &&
        similarity != null &&
        similarity.pointCandidates.isNotEmpty;
  }

  String _buildTransferSuccessMessage(
    SceneTransferResult result, {
    required String successLabel,
  }) {
    final similarity = result.similarity;
    if (similarity == null) {
      return successLabel;
    }
    final percentText = similarity.bestSimilarityPercent.toStringAsFixed(1);
    return '$successLabel（匹配成功，相似度 $percentText%）';
  }

  Future<void> _showMatchSuccessDialog(
    BuildContext context,
    WidgetRef ref,
    SceneTransferResult result,
  ) async {
    final similarity = result.similarity;
    if (similarity == null) {
      return;
    }

    final matchedSceneName = similarity.matchedSceneName ?? '当前点位';
    final percentText = similarity.bestSimilarityPercent.toStringAsFixed(1);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('匹配成功'),
        content: Text(
          '已匹配点位：$matchedSceneName\n'
          '相似度：$percentText%\n'
          '请提交或重新拍摄。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('稍后处理'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _navigateToCamera(context, ref);
            },
            child: const Text('重新拍摄'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _confirmTransfer(context, ref);
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPointCandidatesDialog(
    BuildContext context,
    WidgetRef ref, {
    required SceneData sourceScene,
    required String imagePath,
    required SceneTransferResult result,
  }) async {
    final similarity = result.similarity;
    final candidates =
        similarity?.pointCandidates ?? const <PointMatchCandidate>[];
    if (candidates.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现匹配点位'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前照片与当前点位不一致，请确认匹配到的点位：'),
              const SizedBox(height: 16),
              ...candidates.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _handlePointCandidateSelected(
                          context,
                          ref,
                          sourceScene: sourceScene,
                          imagePath: imagePath,
                          candidate: candidate,
                        );
                      },
                      child: Text(
                        '${candidate.sceneName}（相似度 ${candidate.similarityPercent.toStringAsFixed(1)}%）',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _navigateToCamera(context, ref);
            },
            child: const Text('重新拍摄'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePointCandidateSelected(
    BuildContext context,
    WidgetRef ref, {
    required SceneData sourceScene,
    required String imagePath,
    required PointMatchCandidate candidate,
  }) async {
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    await homeViewModel.reassignSceneImage(
      fromSceneId: sourceScene.id,
      toSceneId: candidate.sceneId,
      imagePath: imagePath,
    );
    await homeViewModel.updateSceneSimilarityStatus(
      candidate.sceneId,
      passed: true,
      similarityPercent: candidate.similarityPercent,
      styleImageId: candidate.styleImageId,
    );
    homeViewModel.selectSceneById(candidate.sceneId);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已切换到点位「${candidate.sceneName}」，相似度 ${candidate.similarityPercent.toStringAsFixed(1)}%，请确认传输或重新拍摄。',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _showSimilarityFailedDialog(
    BuildContext context,
    WidgetRef ref,
    SceneTransferResult result,
  ) async {
    final similarity = result.similarity;
    final matchCount = similarity?.bestGoodMatches ?? 0;
    final percentText =
        similarity?.bestSimilarityPercent.toStringAsFixed(1) ?? '0.0';
    final thresholdText = HomeWorkflowController.similarityThreshold.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未匹配点位'),
        content: Text(
          '当前照片未匹配到有效点位，请重新拍摄。\n'
          '匹配点数：$matchCount\n'
          '相似度百分比：$percentText%\n'
          '通过阈值：$thresholdText 个匹配点',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _navigateToCamera(context, ref);
            },
            child: const Text('重新拍摄'),
          ),
        ],
      ),
    );
  }

  /// 批量传输：对所有“已拍摄且未传输”的场景执行图片传输
  /// 交互流程：
  /// 1) 弹出确认框“是否全部传输？”；
  /// 2) 用户确认后，显示带进度条的对话框，逐个场景执行传输；
  /// 3) 每个场景成功后添加检测记录并标记 isTransferred=true；
  /// 4) 完成后弹出汇总提示（成功/失败数量）。
  Future<void> _transferAll(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);

    // 选择目标：已拍摄且未传输的场景
    final targets = homeState.scenes
        .where(
          (s) =>
              s.capturedImage != null &&
              s.capturedImage!.isNotEmpty &&
              !s.isTransferred,
        )
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有需要传输的场景'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('确认全部传输'),
        content: Text('将对 ${targets.length} 个未传输且已拍摄的场景进行图片传输，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // 进度对话框 + 异步循环，逐一上传并刷新进度
    int completed = 0;
    int failed = 0;
    bool started = false; // 防止重复启动

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            if (!started) {
              started = true;
              // 在首帧后启动上传循环，避免阻塞构建
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final summary = await _workflow(ref).transferScenes(
                  targets,
                  onProgress: (progress) {
                    completed = progress.completed;
                    failed = progress.failed;
                    if (!dialogCtx.mounted) {
                      return;
                    }
                    setState(() {}); // 刷新进度条
                  },
                );

                completed = summary.completed;
                failed = summary.failed;

                // 关闭进度对话框并提示结果
                if (dialogCtx.mounted) {
                  DialogSafety.popIfMounted(dialogCtx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('全部传输完成：成功 $completed，失败 $failed'),
                      backgroundColor: failed == 0
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                  );
                }
              });
            }

            final progress = targets.isEmpty
                ? 0.0
                : (completed / targets.length);
            return AlertDialog(
              title: const Text('正在全部传输'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('进度：$completed/${targets.length}'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSync(bool isWiredMode) async {
    if (!mounted) return;

    // 弹出进度对话框
    BuildContext? progressDialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressDialogContext = dialogContext;
        return AlertDialog(
          title: const Text('正在同步数据'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('正在通过${isWiredMode ? "有线" : "无线"}连接尝试拉取最新场景与检测记录...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await _workflow(ref).syncData();

      if (!mounted) return;

      // 显示 SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? (result.isOnline ? '同步完成：已与服务器通信并更新数据' : '离线刷新完成：已更新本地缓存数据')
                : '同步失败：${result.errorMessage ?? '未知错误'}',
          ),
          backgroundColor: result.success
              ? (result.isOnline
                    ? AppTheme.successColor
                    : AppTheme.warningColor)
              : AppTheme.errorColor,
        ),
      );
    } finally {
      final dialogCtx = progressDialogContext;
      if (dialogCtx != null && dialogCtx.mounted) {
        DialogSafety.popIfMounted(dialogCtx);
      }
    }
  }
}
