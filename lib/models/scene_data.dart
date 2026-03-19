import 'dart:convert';

class SceneData {
  final String id;
  final String name;
  final String roomId;
  final String roomName;
  final String pointCode;
  final String location;
  String? capturedImage;
  DateTime? captureTime;
  DateTime? transferTime;
  bool isTransferred;
  // 新增字段：用于支持最新的检测状态展示（检测闭环）
  String? latestStatus; // "未检测" / "已检测"
  bool? hasIssue; // true: 异常 / false: 合格

  SceneData({
    required this.id,
    required this.name,
    this.roomId = '',
    this.roomName = '',
    this.pointCode = '',
    this.location = '',
    this.capturedImage,
    this.captureTime,
    this.transferTime,
    this.isTransferred = false,
    this.latestStatus,
    this.hasIssue,
  });

  // 从JSON创建
  factory SceneData.fromJson(Map<String, dynamic> json) {
    return SceneData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      roomId: json['roomId'] ?? '',
      roomName: json['roomName'] ?? '',
      pointCode: json['pointCode'] ?? '',
      location: json['location'] ?? '',
      capturedImage: json['capturedImage'],
      captureTime: json['captureTime'] != null
          ? DateTime.parse(json['captureTime'])
          : null,
      transferTime: json['transferTime'] != null
          ? DateTime.parse(json['transferTime'])
          : null,
      isTransferred: json['isTransferred'] ?? false,
      latestStatus: json['latestStatus'],
      hasIssue: json['hasIssue'],
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
      'roomId': roomId,
      'roomName': roomName,
      'pointCode': pointCode,
      'location': location,
      'capturedImage': capturedImage,
      'captureTime': captureTime?.toIso8601String(),
      'transferTime': transferTime?.toIso8601String(),
      'isTransferred': isTransferred,
      'latestStatus': latestStatus,
      'hasIssue': hasIssue,
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
    String? roomId,
    String? roomName,
    String? pointCode,
    String? location,
    String? capturedImage,
    DateTime? captureTime,
    DateTime? transferTime,
    bool? isTransferred,
    String? latestStatus,
    bool? hasIssue,
  }) {
    return SceneData(
      id: id ?? this.id,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      pointCode: pointCode ?? this.pointCode,
      location: location ?? this.location,
      capturedImage: capturedImage ?? this.capturedImage,
      captureTime: captureTime ?? this.captureTime,
      transferTime: transferTime ?? this.transferTime,
      isTransferred: isTransferred ?? this.isTransferred,
      latestStatus: latestStatus ?? this.latestStatus,
      hasIssue: hasIssue ?? this.hasIssue,
    );
  }

  @override
  String toString() {
    return 'SceneData(id: $id, name: $name, roomId: $roomId, roomName: $roomName, pointCode: $pointCode, location: $location, capturedImage: $capturedImage, captureTime: $captureTime, transferTime: $transferTime, isTransferred: $isTransferred, latestStatus: $latestStatus, hasIssue: $hasIssue)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneData &&
        other.id == id &&
        other.name == name &&
        other.roomId == roomId &&
        other.roomName == roomName &&
        other.pointCode == pointCode &&
        other.location == location &&
        other.capturedImage == capturedImage &&
        other.captureTime == captureTime &&
        other.transferTime == transferTime &&
        other.isTransferred == isTransferred &&
        other.latestStatus == latestStatus &&
        other.hasIssue == hasIssue;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        roomId.hashCode ^
        roomName.hashCode ^
        pointCode.hashCode ^
        location.hashCode ^
        capturedImage.hashCode ^
        captureTime.hashCode ^
        transferTime.hashCode ^
        isTransferred.hashCode ^
        latestStatus.hashCode ^
        hasIssue.hashCode;
  }
}
