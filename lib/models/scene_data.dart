class SceneData {
  final String id;
  final String name;
  String? capturedImage;

  SceneData({
    required this.id,
    required this.name,
    this.capturedImage,
  });

  // 从JSON创建
  factory SceneData.fromJson(Map<String, dynamic> json) {
    return SceneData(
      id: json['id'],
      name: json['name'],
      capturedImage: json['capturedImage'],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'capturedImage': capturedImage,
    };
  }
}