// ==================== lib/core/services/style_image_service.dart ====================
// 样式图（模板参考图）服务：从后端拉取指定场景的样式图列表

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/config/app_config.dart';
import 'package:foreignscan/models/style_image.dart';

// Provider：样式图服务
final styleImageServiceProvider = Provider<StyleImageService>((ref) {
  return StyleImageService(ref.read(dioProvider));
});

class StyleImageService {
  final Dio _dio;

  StyleImageService(this._dio);

  // 获取指定场景的样式图列表
  Future<List<StyleImage>> getStyleImagesByScene(String sceneId) async {
    try {
      // 说明：Dio 的 baseUrl 已含 /api 前缀，因此这里使用 /style-images/scene/<sceneId>
      final response = await _dio.get('/style-images/scene/$sceneId');
      final data = response.data;

      if (data is Map && data['styleImages'] is List) {
        final List items = data['styleImages'];
        return items.map((e) => StyleImage.fromJson(e as Map<String, dynamic>)).toList();
      }

      return <StyleImage>[];
    } catch (e) {
      // 请求失败返回空列表
      return <StyleImage>[];
    }
  }

  // 根据样式图对象，生成可直接访问的完整URL
  // 注意：静态文件通过后端服务器根路径（非 /api）下的 /uploads 暴露，这里使用 NetworkConfig.apiBaseUrl 去掉 /api
  String buildImageUrl(StyleImage image) {
    // 说明：NetworkConfig.apiBaseUrl 是静态常量，必须通过类名访问
    final apiBase = NetworkConfig.apiBaseUrl;
    final rootBase = apiBase.replaceFirst(RegExp(r'/api/?$'), '');
    return image.toFullUrl(rootBase);
  }
}