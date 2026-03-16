import 'package:flutter/material.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/widgets/about_app_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            icon: Icons.settings_ethernet,
            title: '连接设置',
            subtitle: '服务器 IP、端口与连接测试可在首页抽屉中配置。',
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            icon: Icons.storage_outlined,
            title: '数据与缓存',
            subtitle: '同步入口位于首页抽屉“同步数据”，本地缓存会在拉取时自动更新。',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
              ),
              title: const Text('关于应用'),
              subtitle: const Text('查看版本信息与应用说明'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const AboutAppDialog(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
