import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Validate User ID
  Future<bool> validateUserId(String uid) async {
    try {
      // Check if UID is not empty and meets basic format requirements
      if (uid.isEmpty || uid.length < 20) {
        _logger.w('Invalid user ID format: $uid');
        return false;
      }

      // Check if user document exists
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _logger.w('No user found with ID: $uid');
        return false;
      }

      // Additional checks can be added here
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        _logger.w('User document is empty for ID: $uid');
        return false;
      }

      // Check if user is active (optional, depending on your requirements)
      if (userData['isActive'] == false) {
        _logger.w('User account is not active for ID: $uid');
        return false;
      }

      return true;
    } catch (e) {
      _logger.e('Error validating user ID: $e');
      return false;
    }
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }

      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return result.docs.isNotEmpty;
    } catch (e) {
      // Log the error
      _logger.e('Error checking if email exists: $e');
      return false; // Return false on error
    }
  }

  // Create user document
  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    try {
      // Validate user data
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }
      if (name.isEmpty) {
        throw Exception('Name cannot be empty');
      }

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true, // Add an active flag
      });
    } catch (e) {
      // Log the error
      _logger.e('Error creating user document: $e');
      rethrow; // Rethrow to allow caller to handle the error
    }
  }

  // Update last login
  Future<void> updateLastLogin(String uid) async {
    try {
      // Validate user ID first
      final bool isValidUser = await validateUserId(uid);
      if (!isValidUser) {
        throw Exception('Invalid user ID');
      }

      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log the error
      _logger.e('Error updating last login: $e');
      rethrow; // Rethrow to allow caller to handle the error
    }
  }

  // Retrieve user document by UID
  Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      // Validate user ID first
      final bool isValidUser = await validateUserId(uid);
      if (!isValidUser) {
        _logger.w('Cannot retrieve user document - Invalid user ID');
        return null;
      }

      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      // Log the error
      _logger.e('Error retrieving user document: $e');
      return null;
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    // More comprehensive email regex
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
      multiLine: false,
    );
    return emailRegex.hasMatch(email);
  }
}