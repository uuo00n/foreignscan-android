import 'dart:convert';

class SceneData {
  final String id;
  final String name;
  String? capturedImage;
  DateTime? captureTime;
  DateTime? transferTime;
  bool isTransferred;

  SceneData({
    required this.id,
    required this.name,
    this.capturedImage,
    this.captureTime,
    this.transferTime,
    this.isTransferred = false,
  });

  // 从JSON创建
  factory SceneData.fromJson(Map<String, dynamic> json) {
    return SceneData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      capturedImage: json['capturedImage'],
      captureTime: json['captureTime'] != null ? DateTime.parse(json['captureTime']) : null,
      transferTime: json['transferTime'] != null ? DateTime.parse(json['transferTime']) : null,
      isTransferred: json['isTransferred'] ?? false,
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
      'captureTime': captureTime?.toIso8601String(),
      'transferTime': transferTime?.toIso8601String(),
      'isTransferred': isTransferred,
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
    DateTime? captureTime,
    DateTime? transferTime,
    bool? isTransferred,
  }) {
    return SceneData(
      id: id ?? this.id,
      name: name ?? this.name,
      capturedImage: capturedImage ?? this.capturedImage,
      captureTime: captureTime ?? this.captureTime,
      transferTime: transferTime ?? this.transferTime,
      isTransferred: isTransferred ?? this.isTransferred,
    );
  }

  @override
  String toString() {
    return 'SceneData(id: $id, name: $name, capturedImage: $capturedImage, captureTime: $captureTime, transferTime: $transferTime, isTransferred: $isTransferred)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneData &&
        other.id == id &&
        other.name == name &&
        other.capturedImage == capturedImage &&
        other.captureTime == captureTime &&
        other.transferTime == transferTime &&
        other.isTransferred == isTransferred;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ capturedImage.hashCode ^ captureTime.hashCode ^ transferTime.hashCode ^ isTransferred.hashCode;
  }
}