import 'package:flutter/material.dart';
import 'dart:io';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'BuildMaster Pro',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[200]!, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'profile-photo',
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[100],
                          child: ClipOval(
                            child: Image.file(
                              File('path_to_saved_photo.jpg'),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person,
                                    color: Colors.grey);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'What would you like to do today?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSection(
                      context,
                      'Project Essentials',
                      [
                        _MenuItem(
                          'Project\nManagement',
                          '/project_management',
                          Icons.business_center_rounded,
                          const Color(0xFF2196F3),
                        ),
                        _MenuItem(
                          'Document\nManagement',
                          '/document_management',
                          Icons.description_rounded,
                          const Color(0xFF673AB7),
                        ),
                        _MenuItem(
                          'Communication\nTools',
                          '/communication_tools',
                          Icons.chat_bubble_rounded,
                          const Color(0xFF009688),
                        ),
                      ],
                    ),
                    _buildSection(
                      context,
                      'Field Operations',
                      [
                        _MenuItem(
                          'Field\nReporting',
                          '/field_reporting',
                          Icons.assignment_rounded,
                          const Color(0xFFFF9800),
                        ),
                        _MenuItem(
                          'Resource\nManagement',
                          '/resource_management',
                          Icons.groups_rounded,
                          const Color(0xFF4CAF50),
                        ),
                        _MenuItem(
                          'Safety\nManagement',
                          '/safety_management',
                          Icons.health_and_safety_rounded,
                          const Color(0xFFF44336),
                        ),
                      ],
                    ),
                    _buildSection(
                      context,
                      'Management Tools',
                      [
                        _MenuItem(
                          'Financial\nManagement',
                          '/financial_management',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFFE91E63),
                        ),
                        _MenuItem(
                          'Time\nTracking',
                          '/time_tracking',
                          Icons.schedule_rounded,
                          const Color(0xFFFFB300),
                        ),
                        _MenuItem(
                          'Analytics &\nReporting',
                          '/analytics_reporting',
                          Icons.insights_rounded,
                          const Color(0xFF00BCD4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Adjusted the childAspectRatio to provide more height
            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.0,
              crossAxisSpacing: 12.0,
              childAspectRatio: (constraints.maxWidth / 3 - 8) /
                  120, // Increased from 110 to 120
              children:
                  items.map((item) => _buildHomeButton(context, item)).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHomeButton(BuildContext context, _MenuItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: item.color.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  size: 24,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String route;
  final IconData icon;
  final Color color;

  _MenuItem(this.title, this.route, this.icon, this.color);
}
