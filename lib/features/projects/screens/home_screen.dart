import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image');
    if (imagePath != null && mounted) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: Theme.of(context).appBarTheme.foregroundColor,
                ),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                tooltip: 'Settings',
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'BuildMaster Pro',
                  style: TextStyle(
                    color: Theme.of(context).appBarTheme.foregroundColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Hero(
                      tag: 'profile_image',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Icon(
                                Icons.person,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey,
                                size: 24,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'What would you like to do today?',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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

  Widget _buildSection(BuildContext context, String title, List<_MenuItem> items) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12.0,
          crossAxisSpacing: 12.0,
          childAspectRatio: 0.8,
          children: items.map((item) => _buildHomeButton(context, item)).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHomeButton(BuildContext context, _MenuItem item) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isDarkMode ? 2 : 0, // Slight elevation in dark mode for visibility
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.1),
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
                  color: item.color.withValues(alpha: 0.1),
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
                  color: isDarkMode ? Colors.white : Colors.grey[800],
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