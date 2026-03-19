import 'dart:math';

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

class BindPadResult {
  final bool success;
  final String message;

  const BindPadResult({required this.success, required this.message});
}

class ServerConfigService {
  final Future<SharedPreferences> _prefs;

  const ServerConfigService(this._prefs);

  String _generateDevicePadId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final suffix = List.generate(
      12,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    return 'pad-$suffix';
  }

  Future<ServerConfig> load() async {
    final prefs = await _prefs;

    final isWiredMode = prefs.getBool('is_wired_mode') ?? false;
    final savedIp = prefs.getString('server_ip');
    final savedPort = prefs.getInt('server_port');

    final savedWirelessIp = prefs.getString('wireless_server_ip') ?? '';
    final savedWiredIp = prefs.getString('wired_server_ip') ?? '';
    var savedPadId = prefs.getString('pad_id');
    final savedPadKey = prefs.getString('pad_key');
    if ((savedPadId ?? '').trim().isEmpty) {
      savedPadId = _generateDevicePadId();
      await prefs.setString('pad_id', savedPadId);
    }

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

    var normalizedPadId = (padId ?? '').trim();
    if (normalizedPadId.isEmpty) {
      normalizedPadId = (prefs.getString('pad_id') ?? '').trim();
    }
    if (normalizedPadId.isEmpty) {
      normalizedPadId = _generateDevicePadId();
    }
    final normalizedPadKey = (padKey ?? '').trim();
    await prefs.setString('pad_id', normalizedPadId);
    if (normalizedPadKey.isNotEmpty) {
      await prefs.setString('pad_key', normalizedPadKey);
    } else {
      await prefs.remove('pad_key');
    }
  }

  Future<BindPadResult> bindPadWithKey({
    required String ip,
    required int port,
    required bool isWiredMode,
    required String bindKey,
  }) async {
    final normalizedBindKey = bindKey.trim();
    if (normalizedBindKey.isEmpty) {
      return const BindPadResult(success: false, message: '绑定码不能为空');
    }

    final prefs = await _prefs;
    var padId = (prefs.getString('pad_id') ?? '').trim();
    if (padId.isEmpty) {
      padId = _generateDevicePadId();
      await prefs.setString('pad_id', padId);
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final response = await dio.post(
        'http://$ip:$port/api/pad/bind',
        data: {'bindKey': normalizedBindKey, 'padId': padId},
      );
      final data = response.data;
      final ok = (data is Map && data['success'] == true);
      if (!ok) {
        final message = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Pad 绑定失败';
        return BindPadResult(success: false, message: message);
      }

      await saveCurrent(
        ip: ip,
        port: port,
        isWiredMode: isWiredMode,
        padId: padId,
        padKey: normalizedBindKey,
      );
      return const BindPadResult(success: true, message: '绑定成功');
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : (e.message ?? 'Pad 绑定失败');
      return BindPadResult(success: false, message: message);
    } catch (_) {
      return const BindPadResult(success: false, message: 'Pad 绑定失败');
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
