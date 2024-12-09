import 'package:build_masterpro/models/app_user.dart';
import 'package:build_masterpro/models/user_role.dart';
import 'package:build_masterpro/services/activity_log_service.dart';
import 'package:build_masterpro/services/user_service.dart';
import 'package:flutter/material.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final UserService _userService = UserService();
  final ActivityLogService _logService = ActivityLogService();
  List<AppUser> _users = [];
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error loading users: $e');
    }
  }

  Future<void> _updateUserRole(AppUser user, UserRole newRole) async {
    setState(() {
      user.role = newRole;
    });

    try {
      await _userService.saveUsers(_users);
      await _logService.logActivity(
        userId: _currentUser?.id ?? 'system',
        userName: _currentUser?.name ?? 'System',
        action: 'ROLE_CHANGE',
        description: 'Changed ${user.name}\'s role to ${newRole.displayName}',
        targetId: user.id,
        targetType: 'USER',
      );
    } catch (e) {
      _showErrorDialog('Failed to update user role: $e');
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Remove user from the list
        _users.removeWhere((u) => u.id == user.id);

        // Save updated users list
        await _userService.saveUsers(_users);

        // Log the deletion
        await _logService.logActivity(
          userId: _currentUser?.id ?? 'system',
          userName: _currentUser?.name ?? 'System',
          action: 'USER_DELETE',
          description: 'Deleted user ${user.name}',
          targetId: user.id,
          targetType: 'USER',
        );

        setState(() {
          _isLoading = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${user.name} has been deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Failed to delete user: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found.'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<UserRole>(
                              value: user.role,
                              onChanged: (UserRole? newRole) {
                                if (newRole != null) {
                                  _updateUserRole(user, newRole);
                                }
                              },
                              items: UserRole.values
                                  .map((role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role.displayName),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(user),
                              tooltip: 'Delete User',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
