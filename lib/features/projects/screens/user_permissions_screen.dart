import 'package:build_masterpro/models/app_user.dart';
import 'package:build_masterpro/models/permission.dart';
import 'package:build_masterpro/services/user_service.dart';
import 'package:flutter/material.dart';

class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  final UserService _userService = UserService();
  List<AppUser> _users = [];
  List<Permission> _permissions = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final users = await _userService.getUsers();
      final permissions = await _userService.getPermissions();
      setState(() {
        _users = users;
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load data: $error');
    }
  }

  Future<void> _saveUserPermissions() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _userService.saveUsers(_users);
      setState(() {
        _isSaving = false;
      });
      _showSuccessDialog('Permissions saved successfully.');
    } catch (error) {
      setState(() {
        _isSaving = false;
      });
      _showErrorDialog('Failed to save permissions: $error');
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
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
        title: const Text('User Permissions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ExpansionTile(
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Role: ${user.role.displayName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Permissions:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ..._permissions.map((permission) {
                              final isRolePermission =
                                  user.role.permissions.contains(permission.id);
                              final isChecked = user.permissions.contains(permission.id);
                              return CheckboxListTile(
                                title: Text(permission.name),
                                subtitle: Text(permission.description),
                                value: isChecked,
                                onChanged: isRolePermission
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          if (value ?? false) {
                                            user.permissions.add(permission.id);
                                          } else {
                                            user.permissions.remove(permission.id);
                                          }
                                        });
                                      },
                              );
                            }),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveUserPermissions,
                              child: const Text('Save Changes'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
