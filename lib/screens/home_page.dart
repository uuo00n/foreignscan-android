import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/core/providers/home_providers.dart' hide loggerProvider;
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import 'package:foreignscan/core/widgets/error_widget.dart';
import 'package:foreignscan/widgets/scene_selector.dart';
import 'package:foreignscan/widgets/scene_display.dart';
import 'package:foreignscan/widgets/records_section.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/screens/camera_screen.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/widgets/app_drawer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // 中文注释：首次安装时提示配置服务器的输入框与状态
  final TextEditingController _serverIpController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  bool _hasPromptedSetup = false; // 防止重复弹窗
  bool _isTestingServer = false; // 测试连接中的状态
  String? _testMsg; // 测试结果提示文案

  @override
  void initState() {
    super.initState();
    // 中文注释：首帧后检查是否已配置服务器，未配置则弹出设置对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptServerSetupIfNeeded();
    });
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    // 监听错误状态
    ref.listen(homeViewModelProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重试',
              textColor: AppTheme.textInverse,
              onPressed: () {
                homeViewModel.clearError();
                homeViewModel.refreshData();
              },
            ),
          ),
        );
      }
    });

    // 使用WillPopScope处理返回手势
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
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
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
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
          onNewDetectionPressed: () => _startNewInspection(context, ref),
          onDetectionResultsPressed: () => AppRouter.navigateToDetectionResult(
            const DetectionResultArguments(
              imagePath: '',
              detectionType: '',
            ),
          ),
        ),
      ],
    );
  }

  // 中文注释：检查是否已配置服务器；若未配置，则弹出引导对话框
  Future<void> _promptServerSetupIfNeeded() async {
    if (_hasPromptedSetup) return; // 防止重复执行
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final savedIp = prefs.getString('server_ip');
      final savedPort = prefs.getInt('server_port');
      if (savedIp == null || savedIp.isEmpty || savedPort == null) {
        _hasPromptedSetup = true;
        _serverIpController.text = savedIp ?? '';
        _serverPortController.text = savedPort?.toString() ?? '';
        _showServerSetupDialog();
      } else {
        // 配置已存在，应用配置并初始化数据
        final dio = ref.read(dioProvider);
        dio.options.baseUrl = 'http://$savedIp:$savedPort/api';
        
        final wifiService = ref.read(wifiServiceProvider);
        wifiService.setServerAddress(savedIp, savedPort);
        
        // 延迟初始化数据，避免在build过程中触发状态更新
        Future.microtask(() {
          ref.read(homeViewModelProvider.notifier).initializeData();
        });
      }
    } catch (e) {
      ref.read(loggerProvider).w('首次启动配置检查失败: $e');
    }
  }

  // 中文注释：首次安装的服务器设置弹窗
  Future<void> _showServerSetupDialog() async {
    // 临时状态变量，用于在弹窗内部管理模式切换
    bool isWiredMode = false;
    String lastWirelessIp = '';
    String lastWiredIp = '';

    await showDialog(
      context: context,
      barrierDismissible: false, // 首次安装强制配置，禁止点击遮罩关闭
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_ethernet_rounded,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '配置服务器',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '首次使用需连接服务器以同步数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 模式选择
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('无线模式')),
                            selected: !isWiredMode,
                            onSelected: (selected) {
                              if (selected && isWiredMode) {
                                setState(() {
                                  // 切换前保存有线IP
                                  lastWiredIp = _serverIpController.text;
                                  
                                  isWiredMode = false;
                                  // 恢复无线IP
                                  _serverIpController.text = lastWirelessIp;
                                  // 重置状态
                                  _isTestingServer = false;
                                  _testMsg = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('有线模式')),
                            selected: isWiredMode,
                            onSelected: (selected) {
                              if (selected && !isWiredMode) {
                                setState(() {
                                  // 切换前保存无线IP
                                  lastWirelessIp = _serverIpController.text;
                                  
                                  isWiredMode = true;
                                  // 恢复有线IP
                                  _serverIpController.text = lastWiredIp;
                                  
                                  // 重置状态
                                  _isTestingServer = false;
                                  _testMsg = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverIpController,
                      decoration: InputDecoration(
                        labelText: '服务器IP',
                        hintText: '例如: 192.168.1.100',
                        prefixIcon: const Icon(Icons.computer_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverPortController,
                      decoration: InputDecoration(
                        labelText: '端口',
                        hintText: '例如: 3000',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    // 状态反馈区域
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _testMsg == null
                            ? Colors.transparent
                            : (_isTestingServer
                                ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                : (_testMsg == '连接成功' ? AppTheme.successColor.withValues(alpha: 0.05) : AppTheme.errorColor.withValues(alpha: 0.05))),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testMsg == null
                              ? Colors.transparent
                              : (_isTestingServer
                                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                  : (_testMsg == '连接成功' ? AppTheme.successColor.withValues(alpha: 0.3) : AppTheme.errorColor.withValues(alpha: 0.3))),
                        ),
                      ),
                      child: _testMsg == null
                          ? const SizedBox.shrink()
                          : Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: _isTestingServer
                                      ? const CircularProgressIndicator(strokeWidth: 2)
                                      : Icon(
                                          _testMsg == '连接成功'
                                              ? Icons.check_circle_rounded
                                              : Icons.error_rounded,
                                          size: 20,
                                          color: _testMsg == '连接成功'
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isTestingServer ? '正在测试连接...' : _testMsg!,
                                    style: TextStyle(
                                      color: _isTestingServer
                                          ? AppTheme.primaryColor
                                          : (_testMsg == '连接成功'
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: AppTheme.textSecondary,
                        ),
                        child: const Text('稍后再说'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2, // 让确认按钮占据更多空间
                      child: ElevatedButton(
                        onPressed: _isTestingServer
                            ? null
                            : () async {
                                setState(() {
                                  _isTestingServer = true;
                                  _testMsg = null;
                                });
                                final ip = _serverIpController.text.trim();
                                final port = int.tryParse(_serverPortController.text.trim());
                                if (ip.isEmpty || port == null || port <= 0) {
                                  setState(() {
                                    _isTestingServer = false;
                                    _testMsg = '请输入有效的IP和端口';
                                  });
                                  return;
                                }
                                // 更新WiFi服务地址并测试连接
                                final wifiService = ref.read(wifiServiceProvider);
                                wifiService.setServerAddress(ip, port);
                                bool ok = false;
                                try {
                                  ok = await wifiService.testConnection();
                                } catch (e) {
                                  ref.read(loggerProvider).w('连接测试异常: $e');
                                  ok = false;
                                }
                                if (!mounted) return;
                                if (ok) {
                                  // 成功：更新 Dio baseUrl、持久化、刷新相关Provider
                                  final dio = ref.read(dioProvider);
                                  dio.options.baseUrl = 'http://$ip:$port/api';
                                  try {
                                    final prefs = await ref.read(sharedPreferencesProvider.future);
                                    await prefs.setString('server_ip', ip);
                                    await prefs.setInt('server_port', port);
                                    
                                    // 保存当前模式
                                    await prefs.setBool('is_wired_mode', isWiredMode);
                                    
                                    // 分别保存对应模式的IP
                                    if (isWiredMode) {
                                      await prefs.setString('wired_server_ip', ip);
                                    } else {
                                      await prefs.setString('wireless_server_ip', ip);
                                    }
                                  } catch (e) {
                                    ref.read(loggerProvider).w('保存服务器配置失败: $e');
                                  }
                                  ref.invalidate(styleImagesForSelectedSceneProvider);
                                  // 初始化首页数据
                                  ref.read(homeViewModelProvider.notifier).initializeData();
                                  setState(() {
                                    _testMsg = '连接成功';
                                    _isTestingServer = false;
                                  });
                                  
                                  // 延迟关闭，让用户看到成功状态
                                  await Future.delayed(const Duration(milliseconds: 500));
                                  if (!dCtx.mounted) return;
                                  
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('服务器已配置成功'),
                                      backgroundColor: AppTheme.successColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  setState(() {
                                    _isTestingServer = false;
                                    _testMsg = '连接失败，请检查IP与端口';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: AppTheme.textInverse,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '测试连接并保存',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
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

    if (selectedScene.capturedImage == null || selectedScene.capturedImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可上传的图片，请先拍摄照片'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    
    // 显示上传进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('正在上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在通过WiFi上传图片，请稍候...'),
          ],
        ),
      ),
    );
    
    try {
      final wifiService = ref.read(wifiServiceProvider);
      final result = await wifiService.uploadImageFromCamera(
        selectedScene.capturedImage!,
        sceneId: selectedScene.id,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片上传成功'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片上传失败，请检查网络连接和服务器设置'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传出错: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请联系管理员添加检测场景',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
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
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              '场景索引异常',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
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

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SceneSelector(
                  scenes: homeState.scenes,
                  selectedIndex: homeState.selectedSceneIndex,
                  onSceneSelected: (index) => homeViewModel.selectScene(index),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      // 中文说明：
                      // 传入加载状态以在SceneDisplay中显示加载动画，同时传入已解析的URL/路径。
                      final refImageAsync = ref.watch(referenceImageUrlProvider);
                      return SceneDisplay(
                        scene: selectedScene,
                        onCaptureClick: () => _navigateToCamera(context, ref),
                        onConfirmTransfer: () => _confirmTransfer(context, ref),
                        onTransferAll: () => _transferAll(context, ref), // 中文注释：新增“全部传输”入口，触发批量传输逻辑
                        referenceImageUrl: refImageAsync.maybeWhen(
                          data: (v) => v,
                          orElse: () => null,
                        ),
                        isReferenceLoading: refImageAsync.isLoading,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        RecordsSection(
          records: homeState.inspectionRecords,
          currentPage: homeState.currentRecordPage,
          recordsPerPage: homeState.recordsPerPage,
          totalPages: homeState.totalPages,
          onPreviousPage: () => homeViewModel.previousRecordPage(),
          onNextPage: () => homeViewModel.nextRecordPage(),
        ),
      ],
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

    try {
      // 使用新的路由系统导航到相机页面
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(),
        ),
      );
      
      // 处理相机返回的结果
      if (imagePath != null) {
        final homeViewModel = ref.read(homeViewModelProvider.notifier);
        await homeViewModel.updateSceneImage(selectedScene.id, imagePath);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('照片拍摄成功'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('相机初始化失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmTransfer(BuildContext context, WidgetRef ref) async {
    final homeState = ref.read(homeViewModelProvider);
    final selectedScene = homeState.selectedScene;
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    if (selectedScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('场景索引异常，请刷新重试'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (selectedScene.capturedImage == null) {
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

    // 显示上传进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('正在传输'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在通过WiFi传输图片，请稍候...'),
          ],
        ),
      ),
    );

    try {
      // 使用WiFi服务上传图片
      final wifiService = ref.read(wifiServiceProvider);
      final result = await wifiService.uploadImageFromCamera(
        selectedScene.capturedImage!,
        sceneId: selectedScene.id,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('传输成功'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // 添加检测记录（改造为使用后端返回的 imageId 与图片访问URL）
          // 中文说明：
          // - 后端返回 result['imageId'] 与 result['path']（形如 /uploads/images/<scene>/<file>）
          // - WiFi 服务提供 serverAddress（例如 http://172.20.10.3:3000），拼接形成完整URL
          final wifiSvc = ref.read(wifiServiceProvider);
          final String imageId = (result['imageId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());
          final String relativePath = (result['path']?.toString() ?? result['accessPath']?.toString() ?? '');
          String fullUrl = relativePath;
          if (relativePath.isNotEmpty) {
            final String base = wifiSvc.serverAddress; // 不包含 /api
            // 确保 relativePath 以 '/' 开头
            final String normalizedRel = relativePath.startsWith('/') ? relativePath : '/$relativePath';
            // 避免 base 末尾有 '/' 时重复斜杠
            final String normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
            fullUrl = '$normalizedBase$normalizedRel';
          }

          final newRecord = InspectionRecord(
            id: imageId,
            sceneName: selectedScene.name,
            imagePath: fullUrl.isNotEmpty ? fullUrl : selectedScene.capturedImage!,
            timestamp: DateTime.now(),
            status: '已上传',
          );

          await homeViewModel.addInspectionRecord(newRecord);

          // 上传成功后，标记场景为已传输并记录传输时间
          // 中文说明：
          // - 更新 isTransferred=true，使按钮文案切换为“重新传输”，卡片边框变为绿色
          // - 记录 transferTime=now，便于后续审计或显示
          await homeViewModel.updateSceneTransferStatus(selectedScene.id, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('传输失败，请检查网络连接和服务器设置'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('传输出错: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// 批量传输：对所有“已拍摄且未传输”的场景执行图片传输
  /// 交互流程：
  /// 1) 弹出确认框“是否全部传输？”；
  /// 2) 用户确认后，显示带进度条的对话框，逐个场景执行传输；
  /// 3) 每个场景成功后添加检测记录并标记 isTransferred=true；
  /// 4) 完成后弹出汇总提示（成功/失败数量）。
  Future<void> _transferAll(BuildContext context, WidgetRef ref) async {
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    final homeState = ref.read(homeViewModelProvider);

    // 选择目标：已拍摄且未传输的场景
    final targets = homeState.scenes.where((s) => s.capturedImage != null && !s.isTransferred).toList();
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
      builder: (_) => AlertDialog(
        title: const Text('确认全部传输'),
        content: Text('将对 ${targets.length} 个未传输且已拍摄的场景进行图片传输，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
                final wifiService = ref.read(wifiServiceProvider);
                for (final scene in targets) {
                  try {
                    final result = await wifiService.uploadImageFromCamera(
                      scene.capturedImage!,
                      sceneId: scene.id,
                    );
                    if (result != null) {
                      // 构建完整图片URL（如果后端返回相对路径）
                      final wifiSvc = ref.read(wifiServiceProvider);
                      final String imageId = (result['imageId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());
                      final String relativePath = (result['path']?.toString() ?? result['accessPath']?.toString() ?? '');
                      String fullUrl = relativePath;
                      if (relativePath.isNotEmpty) {
                        final String base = wifiSvc.serverAddress; // 不包含 /api
                        final String normalizedRel = relativePath.startsWith('/') ? relativePath : '/$relativePath';
                        final String normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
                        fullUrl = '$normalizedBase$normalizedRel';
                      }

                      final newRecord = InspectionRecord(
                        id: imageId,
                        sceneName: scene.name,
                        imagePath: fullUrl.isNotEmpty ? fullUrl : scene.capturedImage!,
                        timestamp: DateTime.now(),
                        status: '已上传',
                      );
                      await homeViewModel.addInspectionRecord(newRecord);
                      await homeViewModel.updateSceneTransferStatus(scene.id, true);

                      completed++;
                    } else {
                      failed++;
                    }
                  } catch (e) {
                    failed++;
                  }
                  setState(() {}); // 刷新进度条
                }

                // 关闭进度对话框并提示结果
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('全部传输完成：成功 $completed，失败 $failed'),
                      backgroundColor: failed == 0 ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  );
                }
              });
            }

            final progress = targets.isEmpty ? 0.0 : (completed / targets.length);
            return AlertDialog(
              title: const Text('正在全部传输'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('进度：$completed/${targets.length}')
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSync(bool isWiredMode) async {
    // 先检测当前是否可与服务器通信（在线/离线）
    final wifiService = ref.read(wifiServiceProvider);
    bool isOnline = false;
    try {
      isOnline = await wifiService.testConnection();
    } catch (_) {
      isOnline = false;
    }

    if (!mounted) return;

    // 弹出进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(isOnline ? '正在与服务器同步' : '离线刷新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(isOnline
                ? '正在通过${isWiredMode ? "有线" : "无线"}连接从服务器拉取最新场景与检测记录...'
                : '当前离线，仅刷新本地缓存数据'),
          ],
        ),
      ),
    );

    bool success = true;
    String? errorMessage;
    try {
      final homeVM = ref.read(homeViewModelProvider.notifier);
      await homeVM.refreshData(forceOffline: !isOnline).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('请求超时，请检查网络或服务器状态');
        },
      );
      
      ref.invalidate(styleImagesForSelectedSceneProvider);
      ref.invalidate(referenceImageUrlProvider);
    } catch (e) {
      success = false;
      errorMessage = e.toString();
      if (errorMessage!.startsWith('Exception: ')) {
        errorMessage = errorMessage!.substring(11);
      }
      ref.read(loggerProvider).e('同步失败: $e');
    }

    if (!mounted) return;

    // 关闭进度对话框
    Navigator.of(context).pop();

    // 显示 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success 
          ? (isOnline ? '同步完成：已与服务器通信并更新数据' : '离线刷新完成：已更新本地缓存数据')
          : '同步失败：${errorMessage ?? '未知错误'}'),
      backgroundColor: success 
          ? (isOnline ? AppTheme.successColor : AppTheme.warningColor)
          : AppTheme.errorColor,
    ));
  }
}
