import 'package:flutter/material.dart';

class ComplianceTrackingPage extends StatefulWidget {
  const ComplianceTrackingPage({super.key});

  @override
  ComplianceTrackingPageState createState() => ComplianceTrackingPageState();
}

class ComplianceTrackingPageState extends State<ComplianceTrackingPage> {
  // List of compliance categories
  final List<ComplianceCategory> _complianceCategories = [
    ComplianceCategory(
      name: 'Safety Regulations',
      requiredDocuments: [
        'Personal Protective Equipment (PPE) Checklist',
        'Safety Training Certificates',
        'Site Safety Plan',
      ],
    ),
    ComplianceCategory(
      name: 'Environmental Compliance',
      requiredDocuments: [
        'Environmental Impact Assessment',
        'Waste Management Plan',
        'Emissions Control Documentation',
      ],
    ),
    ComplianceCategory(
      name: 'Building Codes',
      requiredDocuments: [
        'Architectural Drawings',
        'Structural Engineering Reports',
        'Permit Approvals',
      ],
    ),
    ComplianceCategory(
      name: 'Labor Regulations',
      requiredDocuments: [
        'Worker Contracts',
        'Wage Compliance Reports',
        'Work Hour Logs',
      ],
    ),
  ];

  // Track compliance status for each category
  Map<String, bool> complianceStatus = {};

  @override
  void initState() {
    super.initState();
    // Initialize compliance status
    for (var category in _complianceCategories) {
      complianceStatus[category.name] = false;
    }
  }

  void _showComplianceDetails(ComplianceCategory category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(category.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Required Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...category.requiredDocuments.map((doc) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text(doc)),
                    ],
                  ),
                )
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateComplianceStatus(String category, bool? value) {
    setState(() {
      complianceStatus[category] = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Tracking'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Track and manage compliance across different categories.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon and Title
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in,
                    size: 100,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Compliance Management',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Compliance Categories List
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compliance Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 10),
                    ..._complianceCategories.map((category) => 
                      CheckboxListTile(
                        title: Text(category.name),
                        subtitle: Text('Tap for details'),
                        value: complianceStatus[category.name],
                        onChanged: (value) => _updateComplianceStatus(category.name, value),
                        secondary: IconButton(
                          icon: Icon(Icons.info_outline),
                          onPressed: () => _showComplianceDetails(category),
                        ),
                      )
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Compliance Summary
            Card(
              color: _calculateOverallComplianceColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Overall Compliance Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '${_calculateCompliancePercentage()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calculate overall compliance percentage
  double _calculateCompliancePercentage() {
    final totalCategories = complianceStatus.length;
    final compliantCategories = complianceStatus.values.where((status) => status).length;
    return (compliantCategories / totalCategories * 100).roundToDouble();
  }

  // Determine color based on compliance percentage
  Color _calculateOverallComplianceColor() {
    final percentage = _calculateCompliancePercentage();
    if (percentage < 50) return Colors.red;
    if (percentage < 75) return Colors.orange;
    return Colors.green;
  }
}

// Compliance Category Model
class ComplianceCategory {
  final String name;
  final List<String> requiredDocuments;

  ComplianceCategory({
    required this.name,
    required this.requiredDocuments,
  });
}