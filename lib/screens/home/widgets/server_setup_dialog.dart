import 'package:flutter/material.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

class ServerSetupResult {
  final String ip;
  final int port;
  final bool isWiredMode;

  const ServerSetupResult({
    required this.ip,
    required this.port,
    required this.isWiredMode,
  });
}

Future<ServerSetupResult?> showServerSetupDialog({
  required BuildContext context,
  required String initialIp,
  required int? initialPort,
  required Future<bool> Function(String ip, int port) onTestConnection,
}) async {
  final ipController = TextEditingController(text: initialIp);
  final portController = TextEditingController(
    text: initialPort?.toString() ?? '',
  );

  bool isWiredMode = false;
  String lastWirelessIp = '';
  String lastWiredIp = '';
  bool isTesting = false;
  String? testMessage;

  final result = await showDialog<ServerSetupResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
                const Text(
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
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('无线模式')),
                          selected: !isWiredMode,
                          onSelected: (selected) {
                            if (!selected || !isWiredMode) return;
                            setDialogState(() {
                              lastWiredIp = ipController.text;
                              isWiredMode = false;
                              ipController.text = lastWirelessIp;
                              isTesting = false;
                              testMessage = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('有线模式')),
                          selected: isWiredMode,
                          onSelected: (selected) {
                            if (!selected || isWiredMode) return;
                            setDialogState(() {
                              lastWirelessIp = ipController.text;
                              isWiredMode = true;
                              ipController.text = lastWiredIp;
                              isTesting = false;
                              testMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ipController,
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: portController,
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: testMessage == null
                          ? Colors.transparent
                          : (isTesting
                                ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                : (testMessage == '连接成功'
                                      ? AppTheme.successColor.withValues(
                                          alpha: 0.05,
                                        )
                                      : AppTheme.errorColor.withValues(
                                          alpha: 0.05,
                                        ))),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: testMessage == null
                            ? Colors.transparent
                            : (isTesting
                                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                  : (testMessage == '连接成功'
                                        ? AppTheme.successColor.withValues(
                                            alpha: 0.3,
                                          )
                                        : AppTheme.errorColor.withValues(
                                            alpha: 0.3,
                                          ))),
                      ),
                    ),
                    child: testMessage == null
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: isTesting
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )
                                    : Icon(
                                        testMessage == '连接成功'
                                            ? Icons.check_circle_rounded
                                            : Icons.error_rounded,
                                        size: 20,
                                        color: testMessage == '连接成功'
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isTesting ? '正在测试连接...' : testMessage!,
                                  style: TextStyle(
                                    color: isTesting
                                        ? AppTheme.primaryColor
                                        : (testMessage == '连接成功'
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
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                testMessage = null;
                              });

                              final ip = ipController.text.trim();
                              final port = int.tryParse(
                                portController.text.trim(),
                              );

                              if (ip.isEmpty || port == null || port <= 0) {
                                setDialogState(() {
                                  isTesting = false;
                                  testMessage = '请输入有效的IP和端口';
                                });
                                return;
                              }

                              final ok = await onTestConnection(ip, port);

                              if (!dialogContext.mounted) return;

                              if (ok) {
                                setDialogState(() {
                                  testMessage = '连接成功';
                                  isTesting = false;
                                });
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                if (!dialogContext.mounted) return;
                                Navigator.of(ctx).pop(
                                  ServerSetupResult(
                                    ip: ip,
                                    port: port,
                                    isWiredMode: isWiredMode,
                                  ),
                                );
                              } else {
                                setDialogState(() {
                                  isTesting = false;
                                  testMessage = '连接失败，请检查IP与端口';
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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

  ipController.dispose();
  portController.dispose();
  return result;
}
