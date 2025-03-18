import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class IncidentReportingPage extends StatefulWidget {
  const IncidentReportingPage({super.key});

  @override
  IncidentReportingPageState createState() => IncidentReportingPageState();
}

class IncidentReportingPageState extends State<IncidentReportingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<String> incidentTypes = [
    'Safety Hazard',
    'Security Breach',
    'Equipment Failure',
    'Environmental Issue',
    'Other'
  ];
  String? selectedIncidentType;

  List<String> severityLevels = ['Low', 'Medium', 'High', 'Critical'];
  String? selectedSeverityLevel;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitIncident() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.email == null) {
          throw Exception('User not authenticated or email not available.');
        }

        bool hasInternet = await _checkInternetConnection();
        if (!hasInternet) {
          throw Exception('No internet connection. Please check your network.');
        }

        final incidentData = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'location': _locationController.text,
          'incidentType': selectedIncidentType,
          'severityLevel': selectedSeverityLevel,
          'email': user.email,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'createdBy': user.uid,
          'createdByEmail': user.email,
        };

        await FirebaseFirestore.instance
            .collection('incidents')
            .add(incidentData);

        try {
          final String? apiKey = dotenv.env['SENDGRID_API_KEY'];
          final String? verifiedSenderEmail = dotenv.env['VERIFIED_SENDER_EMAIL'];

          if (apiKey == null || verifiedSenderEmail == null) {
            throw Exception('SendGrid API key or verified sender email not configured.');
          }

          final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');

          final body = jsonEncode({
            'personalizations': [
              {
                'to': [
                  {'email': user.email}
                ]
              }
            ],
            'from': {'email': verifiedSenderEmail},
            'subject': 'New Incident Report: ${_titleController.text}',
            'content': [
              {
                'type': 'text/plain',
                'value': '''
Incident Report:
Title: ${_titleController.text}
Type: $selectedIncidentType
Severity: $selectedSeverityLevel
Location: ${_locationController.text}
Description: ${_descriptionController.text}
                '''
              }
            ]
          });

          final response = await http.post(
            url,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          );

          if (response.statusCode == 202) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incident Report Submitted and Email Sent Successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Failed to send email: ${response.statusCode} - ${response.body}');
          }
        } catch (emailError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Incident submitted, but email failed: $emailError'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        if (mounted) {
          _formKey.currentState!.reset();
          setState(() {
            selectedIncidentType = null;
            selectedSeverityLevel = null;
            _isSubmitting = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Reporting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings navigation here
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? Center(
                child: Card(
                  color: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Please sign in to submit an incident report.',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : Card(
                color: Colors.grey[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.report_problem,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Incident Report Form',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Incident Title',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[700],
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an incident title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Incident Type',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[700],
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Severity Level',
                          prefixIcon: const Icon(Icons.warning),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[700],
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Incident Location',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[700],
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the incident location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Email: ${user.email ?? 'Not available'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Incident Description',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[700],
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please provide a description of the incident';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitIncident,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit Incident Report', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}