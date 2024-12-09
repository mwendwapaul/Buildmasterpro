import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TrainingProgram {
  String name;
  String description;
  String category;
  List<String> prerequisites;
  String duration;

  TrainingProgram({
    required this.name,
    required this.description,
    required this.category,
    this.prerequisites = const [],
    this.duration = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category,
        'prerequisites': prerequisites,
        'duration': duration,
      };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) => TrainingProgram(
        name: json['name'],
        description: json['description'],
        category: json['category'],
        prerequisites: List<String>.from(json['prerequisites'] ?? []),
        duration: json['duration'] ?? '',
      );
}

class TrainingProgramsPage extends StatefulWidget {
  const TrainingProgramsPage({super.key});

  @override
  TrainingProgramsPageState createState() => TrainingProgramsPageState();
}

class TrainingProgramsPageState extends State<TrainingProgramsPage> {
  List<TrainingProgram> _trainingPrograms = [];
  final List<String> _categories = [
    'Safety Training',
    'Technical Skills',
    'Management',
    'Equipment Operation',
    'Compliance'
  ];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  String _selectedCategory = 'Safety Training';
  final List<String> _prerequisites = [];
  final _prerequisiteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTrainingPrograms();
  }

  Future<void> _loadTrainingPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final programsJson = prefs.getStringList('training_programs') ?? [];
    setState(() {
      _trainingPrograms = programsJson
          .map((programJson) =>
              TrainingProgram.fromJson(json.decode(programJson)))
          .toList();
    });
  }

  Future<void> _saveTrainingPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final programsJson = _trainingPrograms
        .map((program) => json.encode(program.toJson()))
        .toList();
    await prefs.setStringList('training_programs', programsJson);
  }

  void _addTrainingProgram() {
    if (_nameController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty) {
      final newProgram = TrainingProgram(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        prerequisites: _prerequisites,
        duration: _durationController.text,
      );

      setState(() {
        _trainingPrograms.add(newProgram);
        _saveTrainingPrograms();
      });

      _nameController.clear();
      _descriptionController.clear();
      _durationController.clear();
      _prerequisites.clear();
      Navigator.of(context).pop();
    }
  }

  void _deleteTrainingProgram(int index) {
    setState(() {
      _trainingPrograms.removeAt(index);
      _saveTrainingPrograms();
    });
  }

  void _addPrerequisite() {
    if (_prerequisiteController.text.isNotEmpty) {
      setState(() {
        _prerequisites.add(_prerequisiteController.text);
        _prerequisiteController.clear();
      });
    }
  }

  void _showAddProgramDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Training Program'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Program Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prerequisiteController,
                            decoration: const InputDecoration(
                              labelText: 'Prerequisites',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addPrerequisite,
                        ),
                      ],
                    ),
                    if (_prerequisites.isNotEmpty)
                      Column(
                        children: _prerequisites.map((prereq) {
                          return Chip(
                            label: Text(prereq),
                            onDeleted: () {
                              setState(() {
                                _prerequisites.remove(prereq);
                              });
                            },
                          );
                        }).toList(),
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
                  onPressed: _addTrainingProgram,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Programs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddProgramDialog,
          ),
        ],
      ),
      body: _trainingPrograms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.school,
                    size: 100,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Training Programs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Click + to add a new training program',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _trainingPrograms.length,
              itemBuilder: (context, index) {
                final program = _trainingPrograms[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(
                      program.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${program.category}'),
                        Text('Duration: ${program.duration}'),
                        if (program.prerequisites.isNotEmpty)
                          Text(
                            'Prerequisites: ${program.prerequisites.join(", ")}',
                          ),
                        const SizedBox(height: 5),
                        Text(
                          program.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteTrainingProgram(index),
                    ),
                    onTap: () {
                      // Optional: Add detail view or edit functionality
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(program.name),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Description: ${program.description}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                Text('Category: ${program.category}'),
                                Text('Duration: ${program.duration}'),
                                if (program.prerequisites.isNotEmpty)
                                  Text(
                                    'Prerequisites: ${program.prerequisites.join(", ")}',
                                  ),
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
                    },
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _prerequisiteController.dispose();
    super.dispose();
  }
}