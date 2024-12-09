import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TimeEntry {
  final DateTime date;
  final String projectName;
  final String taskDescription;
  final double hours;
  final String status;

  TimeEntry({
    required this.date,
    required this.projectName,
    required this.taskDescription,
    required this.hours,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'projectName': projectName,
        'taskDescription': taskDescription,
        'hours': hours,
        'status': status,
      };

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
        date: DateTime.parse(json['date']),
        projectName: json['projectName'],
        taskDescription: json['taskDescription'],
        hours: json['hours'].toDouble(),
        status: json['status'],
      );
}

class DetailedTimesheetsScreen extends StatefulWidget {
  const DetailedTimesheetsScreen({super.key});

  @override
  State<DetailedTimesheetsScreen> createState() =>
      _DetailedTimesheetsScreenState();
}

class _DetailedTimesheetsScreenState extends State<DetailedTimesheetsScreen> {
  List<TimeEntry> _timeEntries = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedProject = 'All Projects';
  final List<String> _projects = [
    'All Projects',
    'City Plaza Project',
    'Residential Complex'
  ];
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadTimeEntries();
  }

  Future<void> _loadTimeEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString('timeEntries');
    
    if (entriesJson != null) {
      final List<dynamic> decodedEntries = jsonDecode(entriesJson);
      if (mounted) {
        setState(() {
          _timeEntries = decodedEntries
              .map((entry) => TimeEntry.fromJson(entry))
              .toList();
        });
      }
    }
  }

  Future<void> _saveTimeEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = jsonEncode(
        _timeEntries.map((entry) => entry.toJson()).toList());
    await prefs.setString('timeEntries', entriesJson);
  }

  void _showAddEntryDialog() {
    final formKey = GlobalKey<FormState>();
    String projectName = '';
    String taskDescription = '';
    String hours = '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Time Entry'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Project'),
                items: _projects
                    .where((project) => project != 'All Projects')
                    .map((project) => DropdownMenuItem(
                          value: project,
                          child: Text(project),
                        ))
                    .toList(),
                onChanged: (value) => projectName = value ?? '',
                validator: (value) =>
                    value == null ? 'Please select a project' : null,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Task Description'),
                onChanged: (value) => taskDescription = value,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a description' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Hours'),
                keyboardType: TextInputType.number,
                onChanged: (value) => hours = value,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter hours';
                  }
                  if (double.tryParse(value!) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                // First close the dialog
                Navigator.of(dialogContext).pop();
                
                // Then perform the async operations
                if (mounted) {
                  setState(() {
                    _timeEntries.add(
                      TimeEntry(
                        date: _selectedDate,
                        projectName: projectName,
                        taskDescription: taskDescription,
                        hours: double.parse(hours),
                        status: 'Pending',
                      ),
                    );
                  });
                  await _saveTimeEntries();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteTimeEntry(TimeEntry entry) async {
    setState(() {
      _timeEntries.removeWhere((e) =>
          e.date == entry.date &&
          e.projectName == entry.projectName &&
          e.taskDescription == entry.taskDescription);
    });
    await _saveTimeEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Timesheets'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildFilterSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildDateSelector(),
          _buildProjectFilter(),
          Expanded(
            child: _buildTimeEntriesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard() {
    double totalHours = _timeEntries
        .where((entry) =>
            entry.date.year == _selectedDate.year &&
            entry.date.month == _selectedDate.month &&
            (_selectedProject == 'All Projects' ||
                entry.projectName == _selectedProject) &&
            (_statusFilter == 'All' || entry.status == _statusFilter))
        .fold(0.0, (sum, entry) => sum + entry.hours);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${totalHours.toStringAsFixed(1)} Hours',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Total Hours This Month',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2025),
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedProject,
        decoration: const InputDecoration(
          labelText: 'Filter by Project',
          border: OutlineInputBorder(),
        ),
        items: _projects.map((String project) {
          return DropdownMenuItem<String>(
            value: project,
            child: Text(project),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null && mounted) {
            setState(() {
              _selectedProject = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildTimeEntriesList() {
    final filteredEntries = _timeEntries.where((entry) =>
        entry.date.year == _selectedDate.year &&
        entry.date.month == _selectedDate.month &&
        (_selectedProject == 'All Projects' ||
            entry.projectName == _selectedProject) &&
        (_statusFilter == 'All' || entry.status == _statusFilter));

    return ListView.builder(
      itemCount: filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = filteredEntries.elementAt(index);
        return Dismissible(
          key: Key(entry.toString()),
          onDismissed: (direction) {
            _deleteTimeEntry(entry);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entry deleted')),
            );
          },
          background: Container(color: Colors.red),
          child: ListTile(
            title: Text(entry.projectName),
            subtitle: Text(
              '${DateFormat.yMMMd().format(entry.date)} - ${entry.hours} hrs',
            ),
            trailing: Text(entry.status),
          ),
        );
      },
    );
  }

  Widget _buildFilterSheet() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter by Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text('All'),
            leading: Radio<String>(
              value: 'All',
              groupValue: _statusFilter,
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    _statusFilter = value;
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Pending'),
            leading: Radio<String>(
              value: 'Pending',
              groupValue: _statusFilter,
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    _statusFilter = value;
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Approved'),
            leading: Radio<String>(
              value: 'Approved',
              groupValue: _statusFilter,
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    _statusFilter = value;
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}