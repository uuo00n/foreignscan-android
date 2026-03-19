import 'dart:convert';

class InspectionRecord {
  final String id;
  final String sceneName;
  final String pointId;
  final String roomId;
  final String roomName;
  final String imagePath;
  final DateTime timestamp;
  final String status;

  InspectionRecord({
    required this.id,
    required this.sceneName,
    this.pointId = '',
    this.roomId = '',
    this.roomName = '',
    required this.imagePath,
    required this.timestamp,
    required this.status,
  });

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    return InspectionRecord(
      id: json['id'] ?? '',
      sceneName: json['sceneName'] ?? '',
      pointId: json['pointId'] ?? '',
      roomId: json['roomId'] ?? '',
      roomName: json['roomName'] ?? '',
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
      'pointId': pointId,
      'roomId': roomId,
      'roomName': roomName,
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
    String? pointId,
    String? roomId,
    String? roomName,
    String? imagePath,
    DateTime? timestamp,
    String? status,
  }) {
    return InspectionRecord(
      id: id ?? this.id,
      sceneName: sceneName ?? this.sceneName,
      pointId: pointId ?? this.pointId,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'InspectionRecord(id: $id, sceneName: $sceneName, pointId: $pointId, roomId: $roomId, roomName: $roomName, imagePath: $imagePath, timestamp: $timestamp, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InspectionRecord &&
        other.id == id &&
        other.sceneName == sceneName &&
        other.pointId == pointId &&
        other.roomId == roomId &&
        other.roomName == roomName &&
        other.imagePath == imagePath &&
        other.timestamp == timestamp &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sceneName.hashCode ^
        pointId.hashCode ^
        roomId.hashCode ^
        roomName.hashCode ^
        imagePath.hashCode ^
        timestamp.hashCode ^
        status.hashCode;
  }

  InspectionStatusType get statusType {
    return InspectionStatusTypeParser.fromRaw(status);
  }
}

enum InspectionStatusType {
  uploaded,
  pending,
  qualified,
  abnormal,
  detected,
  verified,
  unknown,
}

class InspectionStatusTypeParser {
  static InspectionStatusType fromRaw(String rawStatus) {
    switch (rawStatus) {
      case '已上传':
        return InspectionStatusType.uploaded;
      case '待检测':
      case '待确认':
      case '未检测':
        return InspectionStatusType.pending;
      case '合格':
        return InspectionStatusType.qualified;
      case '异常':
      case '存在缺陷':
        return InspectionStatusType.abnormal;
      case '已检测':
        return InspectionStatusType.detected;
      case '已确认':
        return InspectionStatusType.verified;
      default:
        return InspectionStatusType.unknown;
    }
  }
}
