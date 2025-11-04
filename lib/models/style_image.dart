// ==================== lib/models/style_image.dart ====================
// 样式图（模板参考图）模型定义
// 说明：用于承接后端 /api/style-images 与 /api/style-images/scene/:sceneId 的响应数据

class StyleImage {
  final String id; // 样式图ID（ObjectID的Hex字符串）
  final String sceneId; // 场景ID
  final String? name; // 样式图名称
  final String? description; // 样式图描述
  final String? filename; // 文件名
  final String? path; // 存储路径（可能是服务器本地路径）
  final String? accessPath; // 可直接访问的URL路径（例如 /uploads/styles/<scene>/<file>）

  StyleImage({
    required this.id,
    required this.sceneId,
    this.name,
    this.description,
    this.filename,
    this.path,
    this.accessPath,
  });

  // 从后端JSON创建对象
  // 注意：后端可能返回 path 为服务器本地路径（如 ./uploads/styles/...），也可能返回 accessPath。我们尽量兼容。
  factory StyleImage.fromJson(Map<String, dynamic> json) {
    return StyleImage(
      id: json['id']?.toString() ?? '',
      sceneId: (json['sceneId'] is Map && json['sceneId']['Hex'] != null)
          ? json['sceneId']['Hex'].toString() // 兼容极少数序列化形式
          : (json['sceneId']?.toString() ?? ''),
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      filename: json['filename']?.toString(),
      path: json['path']?.toString(),
      accessPath: json['accessPath']?.toString(),
    );
  }

  // 拼接完整的图片URL
  // 参数 baseUrl 形如 http://<host>:<port>（不要带 /api），因为静态文件通常由服务器根路径下的 /uploads 提供
  // 如果后端返回 accessPath，则优先使用；否则尝试用 path 去掉前缀 '.'
  String toFullUrl(String baseUrl) {
    // 1) 优先使用后端返回的 accessPath（一般形如 /uploads/styles/<scene>/<file>）
    // 2) 若仅返回 path（如 ./uploads/styles/...），则去掉前缀 '.'
    // 3) 兜底：确保相对路径以 '/' 开头，避免拼接成 http://host:portuploads/... 的错误形式
    String? relative = accessPath ?? (path != null ? path!.replaceFirst(RegExp(r'^\.'), '') : null);
    if (relative == null || relative.isEmpty) return '';
    if (!relative.startsWith('/')) {
      relative = '/$relative';
    }
    // 确保 baseUrl 不以斜杠结尾
    final String normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$normalizedBase$relative';
  }
}