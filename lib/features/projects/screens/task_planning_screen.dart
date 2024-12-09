import 'package:build_masterpro/models/task.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TaskPlanningScreen extends StatefulWidget {
  const TaskPlanningScreen({super.key});

  @override
  TaskPlanningScreenState createState() => TaskPlanningScreenState();
}

class TaskPlanningScreenState extends State<TaskPlanningScreen> {
  final List<Task> _tasks = [];
  final String _storageKey = 'tasks';
  
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from storage
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList(_storageKey);
    
    if (tasksJson != null) {
      setState(() {
        _tasks.clear();
        for (var taskStr in tasksJson) {
          final taskMap = json.decode(taskStr);
          _tasks.add(Task(
            id: taskMap['id'],
            title: taskMap['title'],
            description: taskMap['description'],
            startDate: DateTime.parse(taskMap['startDate']),
            endDate: DateTime.parse(taskMap['endDate']),
          ));
        }
      });
    }
  }

  // Save tasks to storage
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks.map((task) => json.encode({
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'startDate': task.startDate.toIso8601String(),
      'endDate': task.endDate.toIso8601String(),
    })).toList();
    
    await prefs.setStringList(_storageKey, tasksJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Planning'),
        backgroundColor: Colors.orange,
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Text(
                'No tasks available. Click + to add a new task.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Dismissible(
                  key: Key(task.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => _deleteTask(task),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.description),
                          const SizedBox(height: 4),
                          Text(
                            'Due: ${_formatDate(task.endDate)}',
                            style: TextStyle(
                              color: task.endDate.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTask(task),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _addTask() async {
    await _showTaskDialog();
  }

  void _editTask(Task task) async {
    await _showTaskDialog(task: task);
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.remove(task);
    });
    _saveTasks();
  }

  Future<void> _showTaskDialog({Task? task}) async {
    final TextEditingController titleController =
        TextEditingController(text: task?.title ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: task?.description ?? '');
    DateTime selectedStartDate = task?.startDate ?? DateTime.now();
    DateTime selectedEndDate = task?.endDate ?? DateTime.now().add(const Duration(days: 1));

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task == null ? 'Add New Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(_formatDate(selectedStartDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedStartDate = picked;
                        if (selectedEndDate.isBefore(selectedStartDate)) {
                          selectedEndDate = selectedStartDate.add(const Duration(days: 1));
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(_formatDate(selectedEndDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedEndDate,
                      firstDate: selectedStartDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedEndDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a title'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  if (task == null) {
                    // Add new task
                    _tasks.add(Task(
                      id: DateTime.now().toString(),
                      title: titleController.text,
                      description: descriptionController.text,
                      startDate: selectedStartDate,
                      endDate: selectedEndDate,
                    ));
                  } else {
                    // Edit existing task
                    task.title = titleController.text;
                    task.description = descriptionController.text;
                    task.startDate = selectedStartDate;
                    task.endDate = selectedEndDate;
                  }
                });
                _saveTasks();
                Navigator.pop(context);
              },
              child: Text(task == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }
}