import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/services/usb_transfer_service.dart';

/// USB传输服务Provider
final usbTransferServiceProvider = Provider<USBTransferService>((ref) {
  return USBTransferService();
});

/// USB传输状态Provider
final usbTransferStatusProvider = StateProvider<bool>((ref) {
  return false; // 初始状态为未运行
});

/// USB传输统计Provider
final usbTransferStatsProvider = StateProvider<Map<String, dynamic>>((ref) {
  return {
    'serverAddress': null,
    'filesTransferred': 0,
    'lastTransfer': null,
  };
});