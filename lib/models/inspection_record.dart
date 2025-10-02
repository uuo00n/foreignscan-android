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
      id: json['id'],
      sceneName: json['sceneName'],
      imagePath: json['imagePath'],
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'],
    );
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
}