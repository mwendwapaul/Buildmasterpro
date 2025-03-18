import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../models/task.dart';

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  KanbanBoardScreenState createState() => KanbanBoardScreenState();
}

class KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final List<String> _columns = ['Todo', 'In Progress', 'Done'];
  late Map<String, List<Task>> _tasks;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDueDate;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tasks = {
      'Todo': [],
      'In Progress': [],
      'Done': [],
    };
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var column in _columns) {
        final String? tasksJson = prefs.getString(column);
        if (tasksJson != null) {
          final List<dynamic> decodedTasks = jsonDecode(tasksJson);
          _tasks[column] = decodedTasks
              .map((taskJson) => Task.fromJson(taskJson))
              .toList();
        }
      }
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    for (var column in _columns) {
      final String tasksJson = jsonEncode(
        _tasks[column]!.map((task) => task.toJson()).toList(),
      );
      prefs.setString(column, tasksJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Kanban Board'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showProjectMetrics,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // Mobile layout
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: SizedBox(
                  width: constraints.maxWidth > 400 
                      ? constraints.maxWidth 
                      : _columns.length * 300.0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _columns
                        .map((column) => _buildColumn(column, constraints))
                        .toList(),
                  ),
                ),
              );
            } else {
              // Desktop layout
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _columns
                    .map((column) => _buildColumn(column, constraints))
                    .toList(),
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  Widget _buildColumn(String column, BoxConstraints constraints) {
    final double columnWidth = constraints.maxWidth < 600
        ? 300.0
        : (constraints.maxWidth / _columns.length) - 16;

    return SizedBox(
      width: columnWidth,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildColumnHeader(column),
            Expanded(
              child: DragTarget<Task>(
                onWillAcceptWithDetails: (details) {
                  final task = details.data;
                  return !_tasks[column]!.contains(task);
                },
                onAcceptWithDetails: (details) {
                  final task = details.data;
                  setState(() {
                    _tasks.forEach((key, list) => list.remove(task));
                    _tasks[column]!.add(task);
                    if (column == 'Done') {
                      task.isCompleted = true;
                    }
                    _saveTasks();
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return ListView(
                    padding: const EdgeInsets.all(8),
                    children: _tasks[column]!.map((task) {
                      return Draggable<Task>(
                        data: task,
                        feedback: SizedBox(
                          width: columnWidth - 16,
                          child: _buildTaskCard(task, isDragging: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: _buildTaskCard(task),
                        ),
                        child: _buildTaskCard(task),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(String column) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getColumnHeaderColor(column),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              column,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_tasks[column]!.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColumnHeaderColor(String column) {
    switch (column) {
      case 'Todo':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTaskCard(Task task, {bool isDragging = false}) {
    final bool isOverdue = task.endDate.isBefore(DateTime.now()) && !task.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isDragging ? 8 : 2,
      color: isDragging ? Colors.blue.shade50 : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOverdue ? Colors.red.shade200 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: isOverdue ? Colors.red : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy').format(task.endDate),
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditTaskDialog(task),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteTask(task),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    _selectedDueDate = null;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedDueDate == null
                    ? 'Select Due Date'
                    : DateFormat('MMM dd, yyyy').format(_selectedDueDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDueDate = picked);
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
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty && _selectedDueDate != null) {
                setState(() {
                  _tasks['Todo']!.add(
                    Task(
                      id: DateTime.now().toString(),
                      title: _titleController.text,
                      description: _descriptionController.text,
                      startDate: DateTime.now(),
                      endDate: _selectedDueDate!,
                    ),
                  );
                  _saveTasks();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTaskDialog(Task task) async {
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _selectedDueDate = task.endDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(DateFormat('MMM dd, yyyy').format(_selectedDueDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDueDate!,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDueDate = picked);
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
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                setState(() {
                  final newTask = Task(
                    id: task.id,
                    title: _titleController.text,
                    description: _descriptionController.text,
                    startDate: task.startDate,
                    endDate: _selectedDueDate!,
                    isCompleted: task.isCompleted,
                  );
                  
                  _tasks.forEach((column, tasks) {
                    final index = tasks.indexWhere((t) => t.id == task.id);
                    if (index != -1) {
                      tasks[index] = newTask;
                    }
                  });
                  _saveTasks();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _tasks.forEach((column, tasks) => tasks.remove(task));
                _saveTasks();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showProjectMetrics() {
    final int totalTasks = _tasks.values.fold(0, (sum, tasks) => sum + tasks.length);
    final int completedTasks = _tasks['Done']!.length;
    final int overdueTasks = _tasks.values
        .expand((tasks) => tasks)
        .where((task) => task.endDate.isBefore(DateTime.now()) && !task.isCompleted)
        .length;

    final double completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Project Metrics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Total Tasks',
                    totalTasks.toString(),
                    Icons.task,
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricCard(
                    'Completed Tasks',
                    '$completedTasks (${completionRate.toStringAsFixed(1)}%)',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricCard(
                    'In Progress',
                    _tasks['In Progress']!.length.toString(),
                    Icons.trending_up,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricCard(
                    'Overdue Tasks',
                    overdueTasks.toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exportProjectReport();
                        },
                        child: const Text('Export Report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportProjectReport() async {
    final StringBuffer report = StringBuffer();
    report.writeln('Project Status Report');
    report.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    report.writeln('\n---\n');

    for (final column in _columns) {
      report.writeln('\n$column (${_tasks[column]!.length} tasks)');
      report.writeln('---');
      
      for (final task in _tasks[column]!) {
        report.writeln('\n📌 ${task.title}');
        report.writeln('Description: ${task.description}');
        report.writeln('Due: ${DateFormat('yyyy-MM-dd').format(task.endDate)}');
        report.writeln('Status: ${task.isCompleted ? "✅ Completed" : "⏳ Pending"}');
        
        if (!task.isCompleted && task.endDate.isBefore(DateTime.now())) {
          report.writeln('⚠️ OVERDUE');
        }
        report.writeln('---');
      }
    }

    // In a real app, you would implement file saving functionality here
    // For now, we'll just show the report in a dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Report',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(report.toString()),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }
}