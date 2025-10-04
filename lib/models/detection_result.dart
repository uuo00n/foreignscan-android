class DetectionResult {
  final String id;
  final String sceneName;
  final String imagePath;
  final DateTime timestamp;
  final List<DetectionIssue> issues;
  final String status;

  DetectionResult({
    required this.id,
    required this.sceneName,
    required this.imagePath,
    required this.timestamp,
    required this.issues,
    required this.status,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      id: json['id'],
      sceneName: json['sceneName'],
      imagePath: json['imagePath'],
      timestamp: DateTime.parse(json['timestamp']),
      issues: (json['issues'] as List)
          .map((issue) => DetectionIssue.fromJson(issue))
          .toList(),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneName': sceneName,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'status': status,
    };
  }
}

class DetectionIssue {
  final String id;
  final String type;
  final String description;
  final double x;
  final double y;
  final double width;
  final double height;
  final String severity;

  DetectionIssue({
    required this.id,
    required this.type,
    required this.description,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.severity,
  });

  factory DetectionIssue.fromJson(Map<String, dynamic> json) {
    return DetectionIssue(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
      severity: json['severity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'severity': severity,
    };
  }
}