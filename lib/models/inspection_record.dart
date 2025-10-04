import 'dart:convert';

class InspectionRecord {
  final String id;
  final String sceneName;
  final String imagePath;
  final DateTime timestamp;
  final String status;

  InspectionRecord({
    required this.id,
    required this.sceneName,
    required this.imagePath,
    required this.timestamp,
    required this.status,
  });

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    return InspectionRecord(
      id: json['id'] ?? '',
      sceneName: json['sceneName'] ?? '',
      imagePath: json['imagePath'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      status: json['status'] ?? '待确认',
    );
  }

  // 从JSON字符串创建
  static List<InspectionRecord> fromJsonList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => InspectionRecord.fromJson(json)).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneName': sceneName,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  // 转换为JSON字符串
  static String toJsonList(List<InspectionRecord> records) {
    final jsonList = records.map((record) => record.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // 复制对象
  InspectionRecord copyWith({
    String? id,
    String? sceneName,
    String? imagePath,
    DateTime? timestamp,
    String? status,
  }) {
    return InspectionRecord(
      id: id ?? this.id,
      sceneName: sceneName ?? this.sceneName,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'InspectionRecord(id: $id, sceneName: $sceneName, imagePath: $imagePath, timestamp: $timestamp, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InspectionRecord &&
        other.id == id &&
        other.sceneName == sceneName &&
        other.imagePath == imagePath &&
        other.timestamp == timestamp &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sceneName.hashCode ^
        imagePath.hashCode ^
        timestamp.hashCode ^
        status.hashCode;
  }
}