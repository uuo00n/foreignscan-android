import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_info_providers.dart';
import 'package:foreignscan/widgets/about_app_dialog.dart';
import 'package:foreignscan/core/routes/app_router.dart';
import 'package:foreignscan/theme.dart';
import 'package:foreignscan/screens/home/controllers/drawer_settings_controller.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final Function() onUploadPressed;
  final Function(bool isWiredMode)? onSyncPressed;
  final int statusProbeTick;

  const AppDrawer({
    super.key,
    required this.onUploadPressed,
    this.onSyncPressed,
    this.statusProbeTick = 0,
  });

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _bindKeyController = TextEditingController();
  DrawerServerSettings _serverSettings = const DrawerServerSettings();
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _hasTested = false; // 中文注释：是否已进行过“测试连接”，用于控制右侧状态提示的显示
  String? _testStatusText; // 中文注释：测试连接的提示文案（成功/失败/输入缺失等）
  Map<String, dynamic>? _wifiInfo;
  bool _isWifiLoading = false;
  int _statusVersion =
      0; // 中文注释：状态版本号，每次状态变更递增，确保 AnimatedSwitcher 的子组件 Key 唯一，避免重复 Key
  bool _isAboutDialogShowing = false; // 中文注释：标记“关于”对话框是否正在显示，防止重复点击导致多次弹窗
  bool _isBindKeyVisible = false; // 中文注释：绑定 Key 默认隐藏，可点击眼睛图标临时查看
  bool _isServerStatusChecking = false;
  DrawerServerStatus _serverStatus = const DrawerServerStatus(
    type: DrawerServerStatusType.unconfigured,
    message: '未检测',
  );

  DrawerSettingsController _settingsController(WidgetRef ref) {
    return DrawerSettingsController(ref);
  }

  @override
  void initState() {
    super.initState();
    _initServerSettings();
    _loadWifiInfo();
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statusProbeTick != oldWidget.statusProbeTick) {
      _probeServerStatus();
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _bindKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiInfo() async {
    if (_isWifiLoading) return;
    setState(() {
      _isWifiLoading = true;
    });
    final wifiInfo = await _settingsController(ref).loadWifiInfo();

    if (!mounted) return;
    setState(() {
      _wifiInfo = wifiInfo;
      _isWifiLoading = false;
    });
  }

  Future<void> _testConnection() async {
    // 中文注释：防并发与防抖，若当前已在连接测试中，直接返回，避免多次快速点击导致并发和动画堆叠
    if (_isConnecting) return;
    _dismissInputFocus();

    // 中文注释：立即标记为连接中，阻止再次点击。
    setState(() {
      _isConnecting = true;
      _isServerStatusChecking = true;
      _serverStatus = const DrawerServerStatus(
        type: DrawerServerStatusType.checking,
        message: '检测中...',
      );
    });

    final result = await _settingsController(ref).testConnectionAndPersist(
      ipInput: _ipController.text,
      portInput: _portController.text,
      bindKeyInput: _bindKeyController.text,
      isWiredMode: _serverSettings.isWiredMode,
    );

    // 中文注释：若在等待过程中当前 Drawer 已被关闭或组件已卸载，避免对已卸载组件 setState
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _isConnected = result.isConnected;
      _hasTested = true;
      _testStatusText = result.message;
      _isServerStatusChecking = false;
      _serverStatus = DrawerServerStatus(
        type: result.isConnected
            ? DrawerServerStatusType.online
            : DrawerServerStatusType.offline,
        message: result.message,
      );
      _statusVersion++; // 中文注释：每次结果更新递增版本，避免 AnimatedSwitcher 在快速重复状态下的重复 Key
    });

    // 中文注释：若本次为“重绑成功”，自动触发一次完整同步，确保模板图可离线使用
    if (result.isConnected && result.didBind && widget.onSyncPressed != null) {
      final isWiredMode = _serverSettings.isWiredMode;
      if (mounted) {
        _dismissInputFocus();
        Navigator.pop(context);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSyncPressed?.call(isWiredMode);
      });
    }
  }

  void _resetConnectionStatus() {
    _isConnected = false;
    _hasTested = false;
    _testStatusText = null;
    _serverStatus = const DrawerServerStatus(
      type: DrawerServerStatusType.unconfigured,
      message: '未检测',
    );
  }

  void _dismissInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _probeServerStatus() async {
    if (_isConnecting || _isServerStatusChecking) return;

    setState(() {
      _isServerStatusChecking = true;
      _serverStatus = const DrawerServerStatus(
        type: DrawerServerStatusType.checking,
        message: '检测中...',
      );
    });

    final result = await _settingsController(ref).probeServerStatus(
      ipInput: _ipController.text,
      portInput: _portController.text,
      isWiredMode: _serverSettings.isWiredMode,
    );

    if (!mounted) return;
    setState(() {
      _isServerStatusChecking = false;
      _serverStatus = result;
    });
  }

  Color _serverStatusColor(DrawerServerStatusType type) {
    switch (type) {
      case DrawerServerStatusType.online:
        return AppTheme.successColor;
      case DrawerServerStatusType.offline:
        return AppTheme.errorColor;
      case DrawerServerStatusType.checking:
        return AppTheme.primaryColor;
      case DrawerServerStatusType.unconfigured:
        return AppTheme.warningColor;
    }
  }

  IconData _serverStatusIcon(DrawerServerStatusType type) {
    switch (type) {
      case DrawerServerStatusType.online:
        return Icons.cloud_done;
      case DrawerServerStatusType.offline:
        return Icons.cloud_off;
      case DrawerServerStatusType.checking:
        return Icons.sync;
      case DrawerServerStatusType.unconfigured:
        return Icons.help_outline;
    }
  }

  String _serverStatusLabel(DrawerServerStatusType type) {
    switch (type) {
      case DrawerServerStatusType.unconfigured:
        return '未配置';
      case DrawerServerStatusType.checking:
        return '检测中';
      case DrawerServerStatusType.online:
        return '在线';
      case DrawerServerStatusType.offline:
        return '离线';
    }
  }

  bool get _hasWifiConnection {
    final rawSsid = (_wifiInfo?['ssid'] ?? '').toString().trim();
    if (rawSsid.isEmpty) return false;
    final normalized = rawSsid.toLowerCase();
    return normalized != '<unknown ssid>' && normalized != 'unknown ssid';
  }

  Color get _wifiStatusColor {
    if (_isWifiLoading) return AppTheme.primaryColor;
    return _hasWifiConnection ? AppTheme.successColor : AppTheme.warningColor;
  }

  IconData get _wifiStatusIcon {
    if (_isWifiLoading) return Icons.sync;
    return _hasWifiConnection ? Icons.wifi : Icons.wifi_off;
  }

  String get _wifiStatusLabel {
    if (_isWifiLoading) return '检测中';
    return _hasWifiConnection ? '已连接' : '未连接';
  }

  String get _wifiDetailMessage {
    final ssid = (_wifiInfo?['ssid'] ?? '未连接').toString();
    final ip = (_wifiInfo?['ipAddress'] ?? '未知').toString();
    return 'SSID: $ssid\nIP地址: $ip';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
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
                Builder(
                  builder: (context) {
                    final infoAsync = ref.watch(simpleAppInfoProvider);
                    final versionText = infoAsync.maybeWhen(
                      data: (info) =>
                          '版本: ${info.version} (build ${info.buildNumber})',
                      orElse: () => '版本: 1.0.0',
                    );
                    return Text(
                      versionText,
                      style: TextStyle(
                        color: AppTheme.textInverse.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    );
                  },
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _wifiStatusIcon,
                          color: _wifiStatusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '状态：$_wifiStatusLabel',
                            style: TextStyle(
                              color: _wifiStatusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _wifiDetailMessage,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _isWifiLoading ? null : _loadWifiInfo,
                        child: _isWifiLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('刷新状态'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.cloud, color: AppTheme.primaryColor),
            title: const Text('服务器状态'),
            collapsedIconColor: AppTheme.primaryColor,
            iconColor: AppTheme.primaryColor,
            textColor: AppTheme.primaryColor,
            collapsedTextColor: AppTheme.textPrimary,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _serverStatusIcon(_serverStatus.type),
                          color: _serverStatusColor(_serverStatus.type),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '状态：${_serverStatusLabel(_serverStatus.type)}',
                            style: TextStyle(
                              color: _serverStatusColor(_serverStatus.type),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _serverStatus.message,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _isServerStatusChecking
                            ? null
                            : _probeServerStatus,
                        child: _isServerStatusChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('刷新状态'),
                      ),
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
                    // 中文注释：连接模式选择（无线/有线）
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('无线模式')),
                            selected: !_serverSettings.isWiredMode,
                            onSelected: (selected) {
                              if (!selected || !_serverSettings.isWiredMode) {
                                return;
                              }
                              setState(() {
                                _serverSettings = _settingsController(ref)
                                    .switchToWireless(
                                      current: _serverSettings,
                                      currentIp: _ipController.text,
                                    );
                                _ipController.text = _serverSettings.ip;
                                _resetConnectionStatus();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('有线模式')),
                            selected: _serverSettings.isWiredMode,
                            onSelected: (selected) {
                              if (!selected || _serverSettings.isWiredMode) {
                                return;
                              }
                              setState(() {
                                _serverSettings = _settingsController(ref)
                                    .switchToWired(
                                      current: _serverSettings,
                                      currentIp: _ipController.text,
                                    );
                                _ipController.text = _serverSettings.ip;
                                _resetConnectionStatus();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ipController,
                      // 中文注释：有线模式下不再锁定IP输入，允许用户修改
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bindKeyController,
                      obscureText: !_isBindKeyVisible,
                      decoration: InputDecoration(
                        labelText: '绑定 Key',
                        hintText: '如需重绑请输入新的绑定码',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isBindKeyVisible = !_isBindKeyVisible;
                            });
                          },
                          icon: Icon(
                            _isBindKeyVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip: _isBindKeyVisible ? '隐藏绑定 Key' : '显示绑定 Key',
                        ),
                      ),
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
                                      Icon(
                                        Icons.wifi,
                                        color: AppTheme.primaryColor,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '正在连接...',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                          ),
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
                                          key: ValueKey(
                                            'tested_${_isConnected ? 'success' : 'fail'}_$_statusVersion',
                                          ),
                                          children: [
                                            Icon(
                                              _isConnected
                                                  ? Icons.check_circle
                                                  : Icons.error_outline,
                                              color: _isConnected
                                                  ? AppTheme.successColor
                                                  : AppTheme.errorColor,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _testStatusText ??
                                                    (_isConnected
                                                        ? '连接成功'
                                                        : '连接失败'),
                                                style: TextStyle(
                                                  color: _isConnected
                                                      ? AppTheme.successColor
                                                      : AppTheme.errorColor,
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
              _dismissInputFocus();
              Navigator.pop(context);
              widget.onSyncPressed?.call(_serverSettings.isWiredMode);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: AppTheme.primaryColor),
            title: const Text('关于'),
            onTap: () {
              // 中文注释：防重复点击。如果“关于”对话框正在显示或排队显示，则直接返回。
              if (_isAboutDialogShowing) return;
              _isAboutDialogShowing = true;

              // 中文注释：先关闭抽屉，再使用全局 Navigator 的上下文弹出“关于”对话框，
              // 避免使用已卸载的 Drawer 上下文导致 InheritedWidget（如 ListTileTheme）在卸载时仍有依赖，触发断言错误。
              _dismissInputFocus();
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
    final settings = await _settingsController(ref).loadServerSettings();
    if (!mounted) return;

    setState(() {
      _serverSettings = settings;
      _ipController.text = settings.ip;
      _portController.text = settings.portText;
      _bindKeyController.text = settings.bindKey;
    });

    if (widget.statusProbeTick > 0) {
      await _probeServerStatus();
    }
  }
}
