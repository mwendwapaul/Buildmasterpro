import 'package:cloud_firestore/cloud_firestore.dart';

class PigeonUserDetails {
  final String uid; // Unique identifier for the user
  final String email; // User's email
  final String displayName; // User's display name (optional)
  final String
      profilePictureUrl; // URL for the user's profile picture (optional)
  final DateTime createdAt; // Timestamp of when the user was created

  PigeonUserDetails({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.profilePictureUrl = '',
    required this.createdAt,
  });

  // Factory method to create a PigeonUserDetails instance from a map
  factory PigeonUserDetails.fromMap(Map<String, dynamic> data) {
    return PigeonUserDetails(
      uid: data['uid'],
      email: data['email'],
      displayName: data['displayName'] ?? '',
      profilePictureUrl: data['profilePictureUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Method to convert PigeonUserDetails instance to a map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt,
    };
  }
}
