class ActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String description;
  final DateTime timestamp;
  final String? targetId;
  final String? targetType;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.description,
    required this.timestamp,
    this.targetId,
    this.targetType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'action': action,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'targetId': targetId,
        'targetType': targetType,
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'],
        userId: json['userId'],
        userName: json['userName'],
        action: json['action'],
        description: json['description'],
        timestamp: DateTime.parse(json['timestamp']),
        targetId: json['targetId'],
        targetType: json['targetType'],
      );
}
