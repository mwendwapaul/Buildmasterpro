import 'package:build_masterpro/features/projects/screens/activity_logs_screen.dart';
import 'package:build_masterpro/features/projects/screens/role_management_screen.dart';
import 'package:build_masterpro/features/projects/screens/user_onboarding_screen.dart';
import 'package:build_masterpro/features/projects/screens/user_permissions_screen.dart';
import 'package:build_masterpro/models/app_user.dart';
import 'package:build_masterpro/models/user_role.dart';
import 'package:flutter/material.dart';

import 'asset_tracking_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // Simulating loading a user with admin role or all permissions
    final user = AppUser(
      id: '1',
      name: 'Admin User',
      email: 'admin@example.com',
      role: UserRole.admin,
      permissions: [
        'manage_users',
        'manage_assets',
        'manage_roles',
      ],
      createdAt: DateTime.now(), // Added the required createdAt parameter
    );

    setState(() {
      _currentUser = user;
    });
  }

  List<Map<String, dynamic>> _getAvailableCards() {
    return [
      if (_hasPermission('manage_users'))
        {
          'title': 'Onboarding',
          'icon': Icons.person_add,
          'color': Colors.green,
          'screen': const UserOnboardingScreen(),
        },
        if (_hasPermission('manage_roles'))
        {
          'title': 'Role Management',
          'icon': Icons.group,
          'color': Colors.red,
          'screen': const RoleManagementScreen(),
        },
        if (_hasPermission('manage_users'))
        {
          'title': 'User Permissions',
          'icon': Icons.security,
          'color': Colors.blue,
          'screen': const UserPermissionsScreen(),
        },
      if (_hasPermission('manage_assets'))
        {
          'title': 'Assets Tracking',
          'icon': Icons.inventory,
          'color': Colors.purple,
          'screen': const AssetTrackingScreen(),
        },
      {
        'title': 'Activity Logs',
        'icon': Icons.history,
        'color': Colors.orange,
        'screen': const ActivityLogsScreen(),
      },
    ];
  }

  bool _hasPermission(String permissionId) {
    if (_currentUser?.role == UserRole.admin) return true;
    return _currentUser?.permissions.contains(permissionId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Your Users Effectively',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final crossAxisCount = width < 600
                        ? 2
                        : width < 1200
                            ? 3
                            : 4;
                    final aspectRatio = width < 600 ? 1.0 : 1.2;

                    final cards = _getAvailableCards();

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return _buildUserManagementCard(
                          context,
                          card['title'] as String,
                          card['icon'] as IconData,
                          card['color'] as Color,
                          () => _navigateToScreen(
                            context,
                            card['screen'] as Widget,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
