import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';

class ServerConfig {
  final String? ip;
  final int? port;
  final bool isWiredMode;
  final String wirelessIp;
  final String wiredIp;

  const ServerConfig({
    required this.ip,
    required this.port,
    required this.isWiredMode,
    required this.wirelessIp,
    required this.wiredIp,
  });

  bool get isConfigured =>
      ip != null && ip!.isNotEmpty && port != null && port! > 0;
}

class ServerConfigService {
  final Future<SharedPreferences> _prefs;

  const ServerConfigService(this._prefs);

  Future<ServerConfig> load() async {
    final prefs = await _prefs;

    final isWiredMode = prefs.getBool('is_wired_mode') ?? false;
    final savedIp = prefs.getString('server_ip');
    final savedPort = prefs.getInt('server_port');

    final savedWirelessIp = prefs.getString('wireless_server_ip') ?? '';
    final savedWiredIp = prefs.getString('wired_server_ip') ?? '';

    final effectiveIp = isWiredMode
        ? (savedWiredIp.isNotEmpty ? savedWiredIp : savedIp)
        : (savedWirelessIp.isNotEmpty ? savedWirelessIp : savedIp);

    return ServerConfig(
      ip: effectiveIp,
      port: savedPort,
      isWiredMode: isWiredMode,
      wirelessIp: savedWirelessIp,
      wiredIp: savedWiredIp,
    );
  }

  Future<void> saveCurrent({
    required String ip,
    required int port,
    required bool isWiredMode,
  }) async {
    final prefs = await _prefs;

    await prefs.setString('server_ip', ip);
    await prefs.setInt('server_port', port);
    await prefs.setBool('is_wired_mode', isWiredMode);

    if (isWiredMode) {
      await prefs.setString('wired_server_ip', ip);
    } else {
      await prefs.setString('wireless_server_ip', ip);
    }
  }

  Future<void> setMode(bool isWiredMode) async {
    final prefs = await _prefs;
    await prefs.setBool('is_wired_mode', isWiredMode);
  }

  Future<void> applyToClients({
    required Dio dio,
    required WiFiCommunicationService wifiService,
    ServerConfig? config,
  }) async {
    final effectiveConfig = config ?? await load();

    if (!effectiveConfig.isConfigured) {
      return;
    }

    final ip = effectiveConfig.ip!;
    final port = effectiveConfig.port!;

    wifiService.setServerAddress(ip, port);
    dio.options.baseUrl = 'http://$ip:$port/api';
  }
}
