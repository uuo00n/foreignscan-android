import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
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
    if (_ipController.text.isEmpty || _portController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器IP和端口')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    final wifiService = ref.read(wifiServiceProvider);
    wifiService.setServerAddress(
      _ipController.text,
      int.parse(_portController.text),
    );

    final isConnected = await wifiService.testConnection();

    setState(() {
      _isConnecting = false;
      _isConnected = isConnected;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isConnected ? '连接成功' : '连接失败'),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        ElevatedButton(
                          onPressed: _isConnected ? widget.onUploadPressed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('确认传输'),
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