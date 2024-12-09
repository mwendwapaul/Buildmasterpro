import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SafetyAudit {
  String siteName;
  String date;
  String auditor;
  List<SafetyCheckItem> checkList;
  String overallRisk;

  SafetyAudit({
    required this.siteName,
    required this.date,
    required this.auditor,
    this.checkList = const [],
    this.overallRisk = 'Low',
  });

  Map<String, dynamic> toJson() => {
        'siteName': siteName,
        'date': date,
        'auditor': auditor,
        'checkList': checkList.map((item) => item.toJson()).toList(),
        'overallRisk': overallRisk,
      };

  factory SafetyAudit.fromJson(Map<String, dynamic> json) => SafetyAudit(
        siteName: json['siteName'],
        date: json['date'],
        auditor: json['auditor'],
        checkList: (json['checkList'] as List)
            .map((item) => SafetyCheckItem.fromJson(item))
            .toList(),
        overallRisk: json['overallRisk'] ?? 'Low',
      );
}

class SafetyCheckItem {
  String description;
  bool isPassed;
  String? notes;

  SafetyCheckItem({
    required this.description,
    this.isPassed = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'isPassed': isPassed,
        'notes': notes,
      };

  factory SafetyCheckItem.fromJson(Map<String, dynamic> json) => SafetyCheckItem(
        description: json['description'],
        isPassed: json['isPassed'] ?? false,
        notes: json['notes'],
      );
}

class SafetyAuditsPage extends StatefulWidget {
  const SafetyAuditsPage({super.key});

  @override
  SafetyAuditsPageState createState() => SafetyAuditsPageState();
}

class SafetyAuditsPageState extends State<SafetyAuditsPage> {
  List<SafetyAudit> _safetyAudits = [];
  final List<String> _predefinedCheckItems = [
    'Personal Protective Equipment (PPE)',
    'Fall Protection',
    'Electrical Safety',
    'Scaffolding Integrity',
    'Equipment Maintenance',
    'Emergency Exits',
    'Hazardous Materials Handling',
    'Fire Extinguisher Accessibility',
  ];

  final _siteNameController = TextEditingController();
  final _auditorController = TextEditingController();
  final _dateController = TextEditingController();
  String _selectedRisk = 'Low';
  List<SafetyCheckItem> _currentCheckList = [];

  @override
  void initState() {
    super.initState();
    _loadSafetyAudits();
    _dateController.text = _formatCurrentDate();
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSafetyAudits() async {
    final prefs = await SharedPreferences.getInstance();
    final auditsJson = prefs.getStringList('safety_audits') ?? [];
    setState(() {
      _safetyAudits = auditsJson
          .map((auditJson) => SafetyAudit.fromJson(json.decode(auditJson)))
          .toList();
    });
  }

  Future<void> _saveSafetyAudits() async {
    final prefs = await SharedPreferences.getInstance();
    final auditsJson = _safetyAudits
        .map((audit) => json.encode(audit.toJson()))
        .toList();
    await prefs.setStringList('safety_audits', auditsJson);
  }

  void _addSafetyAudit() {
    if (_siteNameController.text.isNotEmpty &&
        _auditorController.text.isNotEmpty &&
        _currentCheckList.isNotEmpty) {
      final newAudit = SafetyAudit(
        siteName: _siteNameController.text,
        date: _dateController.text,
        auditor: _auditorController.text,
        checkList: _currentCheckList,
        overallRisk: _selectedRisk,
      );

      setState(() {
        _safetyAudits.add(newAudit);
        _saveSafetyAudits();
      });

      _resetForm();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
    }
  }

  void _resetForm() {
    _siteNameController.clear();
    _auditorController.clear();
    _dateController.text = _formatCurrentDate();
    _currentCheckList.clear();
    _selectedRisk = 'Low';
  }

  void _deleteSafetyAudit(int index) {
    setState(() {
      _safetyAudits.removeAt(index);
      _saveSafetyAudits();
    });
  }

  void _showAddAuditDialog() {
    _currentCheckList = _predefinedCheckItems
        .map((item) => SafetyCheckItem(description: item))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Safety Audit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _siteNameController,
                      decoration: const InputDecoration(
                        labelText: 'Site Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _auditorController,
                      decoration: const InputDecoration(
                        labelText: 'Auditor Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Audit Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        setState(() {
                          _dateController.text =
                              '${pickedDate?.year ?? ''}-${pickedDate?.month.toString().padLeft(2, '0') ?? ''}-${pickedDate?.day.toString().padLeft(2, '0') ?? ''}';
                        });
                                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedRisk,
                      decoration: const InputDecoration(
                        labelText: 'Overall Risk',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Low', 'Medium', 'High']
                          .map((risk) => DropdownMenuItem(
                                value: risk,
                                child: Text(risk),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRisk = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Safety Checklist',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ...List.generate(
                      _currentCheckList.length,
                      (index) => CheckboxListTile(
                        title: Text(_currentCheckList[index].description),
                        value: _currentCheckList[index].isPassed,
                        onChanged: (bool? value) {
                          setState(() {
                            _currentCheckList[index].isPassed = value ?? false;
                          });
                        },
                        secondary: IconButton(
                          icon: const Icon(Icons.notes),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                    _currentCheckList[index].description),
                                content: TextField(
  decoration: const InputDecoration(
    labelText: 'Additional Notes',
    border: OutlineInputBorder(),
  ),
  controller: TextEditingController(text: _currentCheckList[index].notes ?? ''),
  onChanged: (value) {
    _currentCheckList[index].notes = value;
  },
  maxLines: 3,
),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _addSafetyAudit,
                  child: const Text('Add Audit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _viewAuditDetails(SafetyAudit audit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Safety Audit: ${audit.siteName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${audit.date}'),
              Text('Auditor: ${audit.auditor}'),
              Text('Overall Risk: ${audit.overallRisk}'),
              const SizedBox(height: 10),
              const Text(
                'Checklist:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...audit.checkList.map((item) => ListTile(
                    title: Text(item.description),
                    trailing: Icon(
                      item.isPassed ? Icons.check_circle : Icons.cancel,
                      color: item.isPassed ? Colors.green : Colors.red,
                    ),
                    subtitle: item.notes != null && item.notes!.isNotEmpty
                        ? Text('Notes: ${item.notes}')
                        : null,
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Audits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAuditDialog,
          ),
        ],
      ),
      body: _safetyAudits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.checklist,
                    size: 100,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Safety Audits',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Click + to add a new safety audit',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _safetyAudits.length,
              itemBuilder: (context, index) {
                final audit = _safetyAudits[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(
                      audit.siteName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${audit.date}'),
                        Text('Auditor: ${audit.auditor}'),
                        Text('Risk Level: ${audit.overallRisk}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_red_eye,
                            color: Colors.blue,
                          ),
                          onPressed: () => _viewAuditDetails(audit),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteSafetyAudit(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _auditorController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}