// lib/config/constants.dart
class AppConstants {
  // App Information
  static const String appTitle = "BuildMaster Pro";
  
  // Firebase Collections
  static const String usersCollection = "users";
  static const String projectsCollection = "projects";
  static const String tasksCollection = "tasks";
  
  // Storage Keys
  static const String authTokenKey = "auth_token";
  static const String userIdKey = "user_id";
  
  // API Configuration
  static const int apiTimeoutSeconds = 30;
  
  // Default Values
  static const int defaultPageSize = 20;
  static const String defaultAvatarUrl = "assets/images/default_avatar.png";
}