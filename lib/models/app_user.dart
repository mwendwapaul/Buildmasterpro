import 'package:build_masterpro/models/user_role.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  UserRole role;
  final List<String> permissions;
  final DateTime createdAt;
  bool isActive;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'permissions': permissions,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        email: json['email'],
        name: json['name'],
        role: UserRole.values.firstWhere(
          (role) => role.name == json['role'],
          orElse: () => UserRole.viewer,
        ),
        permissions: List<String>.from(json['permissions']),
        createdAt: DateTime.parse(json['createdAt']),
        isActive: json['isActive'],
      );
}
