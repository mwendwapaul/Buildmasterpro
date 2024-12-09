import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String description;
  final String? fileUrl;
  final String fileName;
  final String userId;
  final DateTime timestamp;

  Report({
    required this.id,
    required this.description,
    this.fileUrl,
    required this.fileName,
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'userId': userId,
      'timestamp': timestamp,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      description: map['description'],
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      userId: map['userId'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}