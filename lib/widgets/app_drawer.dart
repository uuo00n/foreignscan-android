import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:logger/logger.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final Function() onUploadPressed;
  
  const AppDrawer({
    Key? key,
    required this.onUploadPressed,
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

  @override
  void initState() {
    super.initState();
    _ipController.text = '172.20.10.3'; // 默认IP
    _portController.text = '3000'; // 默认端口（与Go后端一致）
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
    // 中文注释：
    // 当未填写IP或端口时，不再通过首页SnackBar提示，而是在按钮旁边显示文字与图标提示。
    if (_ipController.text.isEmpty || _portController.text.isEmpty) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _hasTested = true;
        _testStatusText = '请输入服务器IP和端口';
      });
      return;
    }

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

    setState(() {
      _isConnecting = false;
      _isConnected = isConnected;
      _hasTested = true;
      // 中文注释：
      // 为避免状态提示文字过长导致溢出，这里使用更短的文案。
      _testStatusText = isConnected
          ? '连接成功'
          : '连接失败，请检查IP与端口';
    });

    if (isConnected) {
      // 成功后，动态更新全局 Dio 的 baseUrl，以便样式图等 REST 接口使用最新地址
      // 例如：http://<ip>:<port>/api
      final dio = ref.read(dioProvider);
      final newApiBaseUrl = 'http://$ip:$port/api';
      dio.options.baseUrl = newApiBaseUrl; // 动态切换到新地址

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
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '智能防异物检测系统',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '版本: 1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading: const Icon(Icons.wifi),
            title: const Text('WiFi状态'),
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
            leading: const Icon(Icons.computer),
            title: const Text('服务器设置'),
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
                                    key: const ValueKey('connecting'),
                                    children: const [
                                      Icon(Icons.wifi, color: Colors.blue, size: 18),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '正在连接...',
                                          style: TextStyle(color: Colors.blue),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  )
                                : (_hasTested
                                    ? Row(
                                        key: const ValueKey('tested'),
                                        children: [
                                          Icon(
                                            _isConnected
                                                ? Icons.check_circle
                                                : Icons.error_outline,
                                            color: _isConnected ? Colors.green : Colors.red,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _testStatusText ?? (_isConnected ? '连接成功' : '连接失败'),
                                              style: TextStyle(
                                                color: _isConnected ? Colors.green : Colors.red,
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
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              // TODO: 导航到设置页面
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            onTap: () {
              // TODO: 显示关于对话框
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}