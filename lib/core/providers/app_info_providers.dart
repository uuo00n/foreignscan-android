// ==================== lib/core/providers/app_info_providers.dart ====================
// 中文说明：
// 1) 提供应用包信息的 Provider，统一从平台获取应用名称、版本号、构建号、包名等；
// 2) 该 Provider 可在“关于”对话框以及任何需要展示 App 信息的地方复用；

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:foreignscan/config/app_config.dart';

/// 获取应用包信息（异步）
/// - 关键点：使用 package_info_plus 的 PackageInfo.fromPlatform() 读取当前安装包信息
/// - 好处：避免硬编码版本号；同时可以拿到构建号与包名
final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  // 中文注释：这里直接从平台读取安装包信息；如遇失败，建议在 UI 层进行兜底展示（例如 AppConfig.appVersion）
  return await PackageInfo.fromPlatform();
});

/// 简化后的 App 信息模型（仅用于“关于”展示）
class SimpleAppInfo {
  final String appName; // 应用名称
  final String version; // 版本号（如：1.0.0）
  final String buildNumber; // 构建号（如：1）
  final String packageName; // 包名（如：com.example.app）
  final String apiBaseUrl; // 后端 API 地址（从 AppConfig 读取）

  const SimpleAppInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.apiBaseUrl,
  });
}

/// 将 PackageInfo 转换为 SimpleAppInfo，便于 UI 展示
final simpleAppInfoProvider = FutureProvider<SimpleAppInfo>((ref) async {
  final pkg = await ref.watch(appPackageInfoProvider.future);
  // 中文注释：API 基础地址来自配置；便于在“关于”中同时展示当前后端目标地址
  const apiBaseUrl = NetworkConfig.apiBaseUrl;
  return SimpleAppInfo(
    appName: pkg.appName.isNotEmpty ? pkg.appName : AppConfig.appName,
    version: pkg.version.isNotEmpty ? pkg.version : AppConfig.appVersion,
    buildNumber: pkg.buildNumber,
    packageName: pkg.packageName,
    apiBaseUrl: apiBaseUrl,
  );
});