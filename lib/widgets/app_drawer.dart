import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/providers/home_providers.dart' hide loggerProvider;
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:logger/logger.dart';
import 'package:foreignscan/core/providers/app_info_providers.dart';
import 'package:foreignscan/widgets/about_app_dialog.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final Function() onUploadPressed;
  final Function()? onSyncPressed;
  
  const AppDrawer({
    Key? key,
    required this.onUploadPressed,
    this.onSyncPressed,
  }) : super(key: key);

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _hasTested = false; // 中文注释：是否已进行过“测试连接”，用于控制右侧状态提示的显示
  String? _testStatusText; // 中文注释：测试连接的提示文案（成功/失败/输入缺失等）
  Map<String, dynamic>? _wifiInfo;
  int _statusVersion = 0; // 中文注释：状态版本号，每次状态变更递增，确保 AnimatedSwitcher 的子组件 Key 唯一，避免重复 Key
  bool _isAboutDialogShowing = false; // 中文注释：标记“关于”对话框是否正在显示，防止重复点击导致多次弹窗

  @override
  void initState() {
    super.initState();
    _initServerSettings();
    _loadWifiInfo();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiInfo() async {
    final wifiService = ref.read(wifiServiceProvider);
    final wifiInfo = await wifiService.getWiFiInfo();
    
    if (mounted) {
      setState(() {
        _wifiInfo = wifiInfo;
      });
    }
  }

  Future<void> _testConnection() async {
    // 中文注释：防并发与防抖，若当前已在连接测试中，直接返回，避免多次快速点击导致并发和动画堆叠
    if (_isConnecting) return;

    // 中文注释：
    // 当未填写IP或端口时，不再通过首页SnackBar提示，而是在按钮旁边显示文字与图标提示。
    if (_ipController.text.isEmpty || _portController.text.isEmpty) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _hasTested = true;
        _testStatusText = '请输入服务器IP和端口';
        _statusVersion++; // 中文注释：递增版本，确保相同提示的连续出现也有不同的 Key
      });
      return;
    }

    // 中文注释：立即标记为连接中，阻止再次点击。
    setState(() {
      _isConnecting = true;
    });

    // 读取输入并进行基本校验
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 3000;

    // 更新 WiFi 服务的目标地址（用于非 REST 上传与测试）
    final wifiService = ref.read(wifiServiceProvider);
    wifiService.setServerAddress(ip, port);

    final isConnected = await wifiService.testConnection();
    // 中文注释：若在等待过程中当前 Drawer 已被关闭或组件已卸载，避免对已卸载组件 setState
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _isConnected = isConnected;
      _hasTested = true;
      // 中文注释：
      // 为避免状态提示文字过长导致溢出，这里使用更短的文案。
      _testStatusText = isConnected
          ? '连接成功'
          : '连接失败，请检查IP与端口';
      _statusVersion++; // 中文注释：每次结果更新递增版本，避免 AnimatedSwitcher 在快速重复状态下的重复 Key
    });

    if (isConnected) {
      // 成功后，动态更新全局 Dio 的 baseUrl，以便样式图等 REST 接口使用最新地址
      // 例如：http://<ip>:<port>/api
      final dio = ref.read(dioProvider);
      final newApiBaseUrl = 'http://$ip:$port/api';
      dio.options.baseUrl = newApiBaseUrl; // 动态切换到新地址

      // 中文注释：持久化服务器设置，确保重启后仍使用最新地址
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setString('server_ip', ip);
        await prefs.setInt('server_port', port);
      } catch (_) {}

      // 使样式图 Provider 失效并重新拉取，立刻刷新参考图
      ref.invalidate(styleImagesForSelectedSceneProvider);
      // 中文注释：不再使用SnackBar提示，将状态反馈改为按钮旁的文字+图标提示（见UI部分）
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '智能防异物检测系统',
                  style: TextStyle(
                    color: AppTheme.textInverse,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 中文注释：版本号动态展示（优先使用 PackageInfo；加载中或错误时使用兜底值）
                Builder(builder: (context) {
                  final infoAsync = ref.watch(simpleAppInfoProvider);
                  final versionText = infoAsync.maybeWhen(
                    data: (info) => '版本: ${info.version} (build ${info.buildNumber})',
                    orElse: () => '版本: 1.0.0',
                  );
                  return Text(
                    versionText,
                    style: TextStyle(
                      color: AppTheme.textInverse.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  );
                }),
              ],
            ),
          ),
          ExpansionTile(
            leading: const Icon(Icons.wifi, color: AppTheme.primaryColor),
            title: const Text('WiFi状态'),
            collapsedIconColor: AppTheme.primaryColor,
            iconColor: AppTheme.primaryColor,
            textColor: AppTheme.primaryColor,
            collapsedTextColor: AppTheme.textPrimary,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _wifiInfo == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SSID: ${_wifiInfo!['ssid'] ?? '未连接'}'),
                          const SizedBox(height: 4),
                          Text('IP地址: ${_wifiInfo!['ipAddress'] ?? '未知'}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadWifiInfo,
                            child: const Text('刷新WiFi信息'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.computer, color: AppTheme.primaryColor),
            title: const Text('服务器设置'),
            collapsedIconColor: AppTheme.primaryColor,
            iconColor: AppTheme.primaryColor,
            textColor: AppTheme.primaryColor,
            collapsedTextColor: AppTheme.textPrimary,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: '服务器IP',
                        hintText: '例如: 192.168.1.100',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        hintText: '例如: 8080',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // 中文注释：测试连接按钮（点击后在右侧显示状态文字与图标）
                        ElevatedButton(
                          onPressed: _isConnecting ? null : _testConnection,
                          child: _isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('测试连接'),
                        ),
                        const SizedBox(width: 12),
                        // 中文注释：按钮右侧的状态提示区域使用 Expanded 包裹，
                        // 以避免长文案在窄屏或窄容器下溢出。
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isConnecting
                                ? Row(
                                    // 中文注释：连接中状态使用常量 Key 即可，因已通过 _isConnecting 防并发
                                    key: const ValueKey('connecting'),
                                    children: const [
                                      Icon(Icons.wifi, color: AppTheme.primaryColor, size: 18),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '正在连接...',
                                          style: TextStyle(color: AppTheme.primaryColor),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  )
                                : (_hasTested
                                    ? Row(
                                        // 中文注释：使用状态+版本组合生成唯一 Key，
                                        // 即使连续出现相同状态（例如连续成功），也不会产生重复 Key。
                                        key: ValueKey('tested_${_isConnected ? 'success' : 'fail'}_$_statusVersion'),
                                        children: [
                                          Icon(
                                            _isConnected
                                                ? Icons.check_circle
                                                : Icons.error_outline,
                                            color: _isConnected ? AppTheme.successColor : AppTheme.errorColor,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _testStatusText ?? (_isConnected ? '连接成功' : '连接失败'),
                                              style: TextStyle(
                                                color: _isConnected ? AppTheme.successColor : AppTheme.errorColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          // 中文注释：新增“与服务器同步数据”按钮，提供手动同步入口
          ListTile(
            leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
            title: const Text('同步数据'),
            onTap: () {
              // 关闭抽屉并触发同步回调
              Navigator.pop(context);
              widget.onSyncPressed?.call();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: AppTheme.primaryColor),
            title: const Text('设置'),
            onTap: () {
              // TODO: 导航到设置页面
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: AppTheme.primaryColor),
            title: const Text('关于'),
            onTap: () {
              // 中文注释：防重复点击。如果“关于”对话框正在显示或排队显示，则直接返回。
              if (_isAboutDialogShowing) return;
              _isAboutDialogShowing = true;

              // 中文注释：先关闭抽屉，再使用全局 Navigator 的上下文弹出“关于”对话框，
              // 避免使用已卸载的 Drawer 上下文导致 InheritedWidget（如 ListTileTheme）在卸载时仍有依赖，触发断言错误。
              Navigator.pop(context);
              // 中文注释：使用下一帧回调确保 Drawer 完成关闭与元素卸载，
              // 再安全地弹出对话框，避免 InheritedWidget 在卸载过程中仍被依赖。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final safeContext = AppRouter.navigatorKey.currentContext;
                if (safeContext != null) {
                  showDialog(
                    context: safeContext,
                    builder: (_) => const AboutAppDialog(),
                  ).whenComplete(() {
                    // 中文注释：对话框关闭后，恢复可点击状态
                    _isAboutDialogShowing = false;
                  });
                } else {
                  // 中文注释：如果全局上下文不可用，恢复标志，避免卡住
                  _isAboutDialogShowing = false;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _initServerSettings() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final savedIp = prefs.getString('server_ip');
      final savedPort = prefs.getInt('server_port');
      if (savedIp != null && savedIp.isNotEmpty && savedPort != null) {
        _ipController.text = savedIp;
        _portController.text = savedPort.toString();

        // 中文注释：仅当存在已保存的服务器配置时，初始化 WiFi 服务与 Dio 地址
        final ip = _ipController.text.trim();
        final port = int.tryParse(_portController.text.trim()) ?? 3000;
        final wifiService = ref.read(wifiServiceProvider);
        wifiService.setServerAddress(ip, port);
        final dio = ref.read(dioProvider);
        dio.options.baseUrl = 'http://$ip:$port/api';
      } else {
        // 中文注释：无已保存配置时，不使用默认地址，留空等待用户手动配置
        _ipController.text = '';
        _portController.text = '';
      }
    } catch (_) {
      // 中文注释：读取失败时同样不填充默认地址，避免误用
      _ipController.text = '';
      _portController.text = '';
    }
  }
}
