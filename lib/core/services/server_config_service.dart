import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';

class ServerConfig {
  final String? ip;
  final int? port;
  final bool isWiredMode;
  final String wirelessIp;
  final String wiredIp;
  final String? padId;
  final String? padKey;

  const ServerConfig({
    required this.ip,
    required this.port,
    required this.isWiredMode,
    required this.wirelessIp,
    required this.wiredIp,
    required this.padId,
    required this.padKey,
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
    final savedPadId = prefs.getString('pad_id');
    final savedPadKey = prefs.getString('pad_key');

    final effectiveIp = isWiredMode
        ? (savedWiredIp.isNotEmpty ? savedWiredIp : savedIp)
        : (savedWirelessIp.isNotEmpty ? savedWirelessIp : savedIp);

    return ServerConfig(
      ip: effectiveIp,
      port: savedPort,
      isWiredMode: isWiredMode,
      wirelessIp: savedWirelessIp,
      wiredIp: savedWiredIp,
      padId: savedPadId,
      padKey: savedPadKey,
    );
  }

  Future<void> saveCurrent({
    required String ip,
    required int port,
    required bool isWiredMode,
    String? padId,
    String? padKey,
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

    final normalizedPadId = (padId ?? '').trim();
    final normalizedPadKey = (padKey ?? '').trim();
    if (normalizedPadId.isNotEmpty) {
      await prefs.setString('pad_id', normalizedPadId);
    } else {
      await prefs.remove('pad_id');
    }
    if (normalizedPadKey.isNotEmpty) {
      await prefs.setString('pad_key', normalizedPadKey);
    } else {
      await prefs.remove('pad_key');
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
    wifiService.setPadCredentials(
      effectiveConfig.padId,
      effectiveConfig.padKey,
    );
    dio.options.baseUrl = 'http://$ip:$port/api';
    if ((effectiveConfig.padId ?? '').isNotEmpty &&
        (effectiveConfig.padKey ?? '').isNotEmpty) {
      dio.options.headers['X-Pad-Id'] = effectiveConfig.padId!;
      dio.options.headers['X-Pad-Key'] = effectiveConfig.padKey!;
    } else {
      dio.options.headers.remove('X-Pad-Id');
      dio.options.headers.remove('X-Pad-Key');
    }
  }
}
