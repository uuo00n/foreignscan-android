// ==================== lib/widgets/about_app_dialog.dart ====================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_info_providers.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

/// “关于应用”对话框
/// - 展示应用名称、版本+构建号、包名、后端 API 地址
/// - 提供一键复制信息的操作，便于问题反馈与排查
class AboutAppDialog extends ConsumerWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(simpleAppInfoProvider);

    // 中文注释：使用 AlertDialog 承载信息，保证在安卓与 iOS 上都有一致体验
    return AlertDialog(
      title: const Text('关于'),
      content: infoAsync.when(
        data: (info) {
          // 关键点：将关键信息组织为 ListTile，便于阅读与复制
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoTile(label: '应用名称', value: info.appName),
              _InfoTile(label: '版本', value: '${info.version} (build ${info.buildNumber})'),
              _InfoTile(label: '包名', value: info.packageName),
              _InfoTile(label: '后端 API', value: info.apiBaseUrl),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final all = '应用名称: ${info.appName}\n版本: ${info.version} (build ${info.buildNumber})\n包名: ${info.packageName}\n后端 API: ${info.apiBaseUrl}';
                      Clipboard.setData(ClipboardData(text: all));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制应用信息')),
                      );
                    },
                    child: const Text('复制信息'),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) {
          // 中文注释：当获取 PackageInfo 失败时进行兜底提示，同时给出关闭按钮
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('获取应用信息失败，请稍后重试'),
              const SizedBox(height: 12),
              Text(
                '$e',
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 信息条目组件（标签 + 值）
class _InfoTile extends StatelessWidget {
  final String label; // 中文注释：显示字段名，如“版本”
  final String value; // 中文注释：对应的具体值，如“1.0.0+1”
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}