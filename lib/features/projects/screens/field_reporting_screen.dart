import 'package:flutter/material.dart';

class FieldReportingScreen extends StatelessWidget {
  const FieldReportingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Reporting'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field Reporting Options',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _reportingOptions.length,
                itemBuilder: (context, index) {
                  final option = _reportingOptions[index];
                  return _buildReportingCard(
                    context,
                    option['title'] as String,
                    option['icon'] as IconData,
                    option['color'] as Color,
                    option['route'] as String, // Pass the route
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportingCard(BuildContext context, String title, IconData icon,
      Color color, String route) {
    return GestureDetector(
      onTap: () {
        // Navigate to the corresponding screen based on the option selected
        Navigator.pushNamed(context, route);
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
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
}

// Updated reporting options with routes
final List<Map<String, dynamic>> _reportingOptions = [
  {
    'title': 'Daily Logs',
    'icon': Icons.article,
    'color': Colors.blue,
    'route': '/dailyLogs', // Add route for Daily Logs
  },
  {
    'title': 'Capture Photos',
    'icon': Icons.camera_alt,
    'color': Colors.green,
    'route': '/capturePhotos',
  },
  {
    'title': 'Checklists',
    'icon': Icons.check_circle,
    'color': Colors.orange,
    'route': '/checklists', 
  },
  {
    'title': 'Submit Reports',
    'icon': Icons.send,
    'color': Colors.red,
    'route': '/submitReports', 
  },
];
