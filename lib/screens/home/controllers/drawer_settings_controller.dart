import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/providers/home_providers.dart';

class DrawerServerSettings {
  final bool isWiredMode;
  final String ip;
  final String portText;
  final String lastWirelessIp;
  final String lastWiredIp;

  const DrawerServerSettings({
    this.isWiredMode = false,
    this.ip = '',
    this.portText = '',
    this.lastWirelessIp = '',
    this.lastWiredIp = '',
  });

  DrawerServerSettings copyWith({
    bool? isWiredMode,
    String? ip,
    String? portText,
    String? lastWirelessIp,
    String? lastWiredIp,
  }) {
    return DrawerServerSettings(
      isWiredMode: isWiredMode ?? this.isWiredMode,
      ip: ip ?? this.ip,
      portText: portText ?? this.portText,
      lastWirelessIp: lastWirelessIp ?? this.lastWirelessIp,
      lastWiredIp: lastWiredIp ?? this.lastWiredIp,
    );
  }
}

class DrawerConnectionResult {
  final bool isConnected;
  final String message;

  const DrawerConnectionResult({
    required this.isConnected,
    required this.message,
  });
}

class DrawerSettingsController {
  final WidgetRef _ref;

  const DrawerSettingsController(this._ref);

  Future<Map<String, dynamic>?> loadWifiInfo() async {
    final wifiService = _ref.read(wifiServiceProvider);
    return wifiService.getWiFiInfo();
  }

  Future<DrawerServerSettings> loadServerSettings() async {
    try {
      final serverConfigService = _ref.read(serverConfigServiceProvider);
      final config = await serverConfigService.load();

      if (config.isConfigured) {
        await serverConfigService.applyToClients(
          dio: _ref.read(dioProvider),
          wifiService: _ref.read(wifiServiceProvider),
          config: config,
        );
      }

      return DrawerServerSettings(
        isWiredMode: config.isWiredMode,
        ip: config.ip ?? '',
        portText: config.port?.toString() ?? '',
        lastWirelessIp: config.wirelessIp,
        lastWiredIp: config.wiredIp,
      );
    } catch (e) {
      _ref.read(loggerProvider).w('读取服务器设置失败: $e');
      return const DrawerServerSettings();
    }
  }

  DrawerServerSettings switchToWireless({
    required DrawerServerSettings current,
    required String currentIp,
  }) {
    if (!current.isWiredMode) {
      return current;
    }

    return current.copyWith(
      isWiredMode: false,
      lastWiredIp: currentIp,
      ip: current.lastWirelessIp,
    );
  }

  DrawerServerSettings switchToWired({
    required DrawerServerSettings current,
    required String currentIp,
  }) {
    if (current.isWiredMode) {
      return current;
    }

    return current.copyWith(
      isWiredMode: true,
      lastWirelessIp: currentIp,
      ip: current.lastWiredIp,
    );
  }

  Future<DrawerConnectionResult> testConnectionAndPersist({
    required String ipInput,
    required String portInput,
    required bool isWiredMode,
  }) async {
    final ip = ipInput.trim();
    final port = int.tryParse(portInput.trim());

    if (ip.isEmpty || port == null || port <= 0) {
      return const DrawerConnectionResult(
        isConnected: false,
        message: '请输入服务器IP和端口',
      );
    }

    final wifiService = _ref.read(wifiServiceProvider);
    wifiService.setServerAddress(ip, port);

    final isConnected = await wifiService.testConnection();
    if (!isConnected) {
      return const DrawerConnectionResult(
        isConnected: false,
        message: '连接失败，请检查IP与端口',
      );
    }

    try {
      final serverConfigService = _ref.read(serverConfigServiceProvider);
      await serverConfigService.saveCurrent(
        ip: ip,
        port: port,
        isWiredMode: isWiredMode,
      );
      await serverConfigService.applyToClients(
        dio: _ref.read(dioProvider),
        wifiService: wifiService,
      );

      _ref.invalidate(styleImagesForSelectedSceneProvider);
    } catch (e) {
      _ref.read(loggerProvider).w('持久化服务器设置失败: $e');
    }

    return const DrawerConnectionResult(isConnected: true, message: '连接成功');
  }
}
