import 'package:build_masterpro/models/app_user.dart';
import 'package:build_masterpro/models/permission.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserService {
  static const String _usersKey = 'app_users';
  static const String _permissionsKey = 'app_permissions';

  Future<void> saveUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = users.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList(_usersKey, usersJson);
  }

  Future<List<AppUser>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey);
    if (usersJson == null) return [];

    return usersJson
        .map((userStr) => AppUser.fromJson(jsonDecode(userStr)))
        .toList();
  }

  Future<void> savePermissions(List<Permission> permissions) async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsJson = permissions
        .map((permission) => jsonEncode(permission.toJson()))
        .toList();
    await prefs.setStringList(_permissionsKey, permissionsJson);
  }

  Future<List<Permission>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsJson = prefs.getStringList(_permissionsKey);
    if (permissionsJson == null) return _getDefaultPermissions();

    return permissionsJson
        .map((permissionStr) => Permission.fromJson(jsonDecode(permissionStr)))
        .toList();
  }

  List<Permission> _getDefaultPermissions() {
    return [
      Permission(
        id: 'view_dashboard',
        name: 'View Dashboard',
        description: 'Access to view the main dashboard',
        module: 'Dashboard',
      ),
      Permission(
        id: 'manage_users',
        name: 'Manage Users',
        description: 'Create, edit, and delete users',
        module: 'User Management',
      ),
      Permission(
        id: 'manage_roles',
        name: 'Manage Roles',
        description: 'Modify user roles and permissions',
        module: 'User Management',
      ),
      // Add more default permissions as needed
    ];
  }
}
