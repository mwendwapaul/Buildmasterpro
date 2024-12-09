import 'package:flutter/material.dart';

class AboutMyAppScreen extends StatelessWidget {
  const AboutMyAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About BuildMaster Pro'),
        centerTitle: true,
        backgroundColor: Colors.orange[800],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About BuildMaster Pro',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BuildMaster Pro is an all-in-one construction management application designed to streamline project planning, execution, and monitoring. Whether you are a contractor, project manager, or part of the construction crew, BuildMaster Pro provides the tools you need to manage every aspect of your construction projects efficiently.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Features:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Interactive Gantt charts for project scheduling\n'
                '• Kanban boards for task management\n'
                '• Document management for easy access to plans and permits\n'
                '• Communication tools to keep teams connected\n'
                '• Field reporting for real-time updates and progress tracking\n'
                '• Resource management for effective allocation\n'
                '• Financial management tools for budgeting and expense tracking\n'
                '• Time tracking for accurate billing and payroll\n'
                '• Safety management features to ensure compliance\n'
                '• Comprehensive analytics and reporting for informed decision-making',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Version: 1.0.0',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
