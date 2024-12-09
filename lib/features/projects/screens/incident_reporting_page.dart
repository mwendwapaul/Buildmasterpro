import 'package:flutter/material.dart';

class IncidentReportingPage extends StatefulWidget {
  const IncidentReportingPage({super.key});

  @override
  IncidentReportingPageState createState() => IncidentReportingPageState();
}

class IncidentReportingPageState extends State<IncidentReportingPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Incident type dropdown
  List<String> incidentTypes = [
    'Safety Hazard',
    'Security Breach',
    'Equipment Failure',
    'Environmental Issue',
    'Other'
  ];
  String? selectedIncidentType;

  // Severity level
  List<String> severityLevels = [
    'Low',
    'Medium',
    'High',
    'Critical'
  ];
  String? selectedSeverityLevel;

  @override
  void dispose() {
    // Clean up controllers
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submitIncident() {
    if (_formKey.currentState!.validate()) {
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident Report Submitted Successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form after submission
      _formKey.currentState!.reset();
      setState(() {
        selectedIncidentType = null;
        selectedSeverityLevel = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incident Reporting'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon and Title
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.report_problem,
                      size: 100,
                      color: Colors.red,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Incident Report Form',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Incident Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Incident Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an incident title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Incident Type Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Incident Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                value: selectedIncidentType,
                items: incidentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedIncidentType = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an incident type';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Severity Level Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Severity Level',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning),
                ),
                value: selectedSeverityLevel,
                items: severityLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSeverityLevel = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a severity level';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Incident Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the incident location';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Incident Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a description of the incident';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _submitIncident,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  textStyle: TextStyle(fontSize: 16),
                ),
                child: Text('Submit Incident Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}