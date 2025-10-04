import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class DetectionResult extends Equatable {
  final String id;
  final String sceneName;
  final String imagePath;
  final DateTime timestamp;
  final List<DetectionIssue> issues;
  final DetectionStatus status;
  final String? detectionType;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const DetectionResult({
    required this.id,
    required this.sceneName,
    required this.imagePath,
    required this.timestamp,
    required this.issues,
    required this.status,
    this.detectionType,
    this.confidence,
    this.metadata,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      id: json['id'] ?? '',
      sceneName: json['sceneName'] ?? '',
      imagePath: json['imagePath'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      issues: (json['issues'] as List<dynamic>?)
              ?.map((issue) => DetectionIssue.fromJson(issue))
              .toList() ?? const [],
      status: DetectionStatus.fromString(json['status'] ?? 'pending'),
      detectionType: json['detectionType'],
      confidence: json['confidence']?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // 从JSON字符串创建
  static List<DetectionResult> fromJsonList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => DetectionResult.fromJson(json)).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneName': sceneName,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'status': status.value,
      'detectionType': detectionType,
      'confidence': confidence,
      'metadata': metadata,
    };
  }

  // 转换为JSON字符串
  static String toJsonList(List<DetectionResult> results) {
    final jsonList = results.map((result) => result.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // 复制对象
  DetectionResult copyWith({
    String? id,
    String? sceneName,
    String? imagePath,
    DateTime? timestamp,
    List<DetectionIssue>? issues,
    DetectionStatus? status,
    String? detectionType,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return DetectionResult(
      id: id ?? this.id,
      sceneName: sceneName ?? this.sceneName,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      issues: issues ?? this.issues,
      status: status ?? this.status,
      detectionType: detectionType ?? this.detectionType,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }

  // 业务逻辑方法
  bool get hasIssues => issues.isNotEmpty;
  
  int get highSeverityIssues => 
      issues.where((issue) => issue.severity == IssueSeverity.high).length;
  
  int get mediumSeverityIssues => 
      issues.where((issue) => issue.severity == IssueSeverity.medium).length;
  
  int get lowSeverityIssues => 
      issues.where((issue) => issue.severity == IssueSeverity.low).length;

  bool get isCompleted => status == DetectionStatus.completed;
  bool get isPending => status == DetectionStatus.pending;
  bool get isFailed => status == DetectionStatus.failed;

  @override
  List<Object?> get props => [
    id,
    sceneName,
    imagePath,
    timestamp,
    issues,
    status,
    detectionType,
    confidence,
    metadata,
  ];

  @override
  bool get stringify => true;
}

class DetectionIssue extends Equatable {
  final String id;
  final IssueType type;
  final String description;
  final double x;
  final double y;
  final double width;
  final double height;
  final IssueSeverity severity;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const DetectionIssue({
    required this.id,
    required this.type,
    required this.description,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.severity,
    this.confidence,
    this.metadata,
  });

  factory DetectionIssue.fromJson(Map<String, dynamic> json) {
    return DetectionIssue(
      id: json['id'] ?? '',
      type: IssueType.fromString(json['type'] ?? 'unknown'),
      description: json['description'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
      severity: IssueSeverity.fromString(json['severity'] ?? 'medium'),
      confidence: json['confidence']?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'description': description,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'severity': severity.value,
      'confidence': confidence,
      'metadata': metadata,
    };
  }

  DetectionIssue copyWith({
    String? id,
    IssueType? type,
    String? description,
    double? x,
    double? y,
    double? width,
    double? height,
    IssueSeverity? severity,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return DetectionIssue(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }

  // 业务逻辑方法
  bool get isHighSeverity => severity == IssueSeverity.high;
  bool get isMediumSeverity => severity == IssueSeverity.medium;
  bool get isLowSeverity => severity == IssueSeverity.low;

  bool get isForeignObject => type == IssueType.foreignObject;
  bool get isDamage => type == IssueType.damage;
  bool get isCorrosion => type == IssueType.corrosion;
  bool get isLeakage => type == IssueType.leakage;

  @override
  List<Object?> get props => [
    id,
    type,
    description,
    x,
    y,
    width,
    height,
    severity,
    confidence,
    metadata,
  ];

  @override
  bool get stringify => true;
}

// 枚举定义
enum DetectionStatus {
  pending('pending', '待检测'),
  processing('processing', '检测中'),
  completed('completed', '检测完成'),
  failed('failed', '检测失败');

  const DetectionStatus(this.value, this.displayName);
  
  final String value;
  final String displayName;

  factory DetectionStatus.fromString(String value) {
    return DetectionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DetectionStatus.pending,
    );
  }
}

enum IssueType {
  foreignObject('foreignObject', '异物'),
  damage('damage', '损坏'),
  corrosion('corrosion', '腐蚀'),
  leakage('leakage', '泄漏'),
  crack('crack', '裂纹'),
  deformation('deformation', '变形'),
  unknown('unknown', '未知');

  const IssueType(this.value, this.displayName);
  
  final String value;
  final String displayName;

  factory IssueType.fromString(String value) {
    return IssueType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => IssueType.unknown,
    );
  }
}

enum IssueSeverity {
  low('low', '低', Colors.blue),
  medium('medium', '中', Colors.orange),
  high('high', '高', Colors.red),
  critical('critical', '严重', Colors.purple);

  const IssueSeverity(this.value, this.displayName, this.color);
  
  final String value;
  final String displayName;
  final Color color;

  factory IssueSeverity.fromString(String value) {
    return IssueSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => IssueSeverity.medium,
    );
  }
}