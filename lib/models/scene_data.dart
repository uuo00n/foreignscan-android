import 'dart:convert';

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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      capturedImage: json['capturedImage'],
    );
  }

  // 从JSON字符串创建
  static List<SceneData> fromJsonList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => SceneData.fromJson(json)).toList();
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'capturedImage': capturedImage,
    };
  }

  // 转换为JSON字符串
  static String toJsonList(List<SceneData> scenes) {
    final jsonList = scenes.map((scene) => scene.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // 复制对象
  SceneData copyWith({
    String? id,
    String? name,
    String? capturedImage,
  }) {
    return SceneData(
      id: id ?? this.id,
      name: name ?? this.name,
      capturedImage: capturedImage ?? this.capturedImage,
    );
  }

  @override
  String toString() {
    return 'SceneData(id: $id, name: $name, capturedImage: $capturedImage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneData &&
        other.id == id &&
        other.name == name &&
        other.capturedImage == capturedImage;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ capturedImage.hashCode;
  }
}