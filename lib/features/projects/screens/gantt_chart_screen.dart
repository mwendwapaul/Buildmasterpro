import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    title: 'Project Timeline',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    ),
    home: const GanttChartScreen(tasks: []),
  ));
}

class Task {
  String id;
  String title;
  DateTime startDate;
  DateTime endDate;
  TaskStatus status;
  double progress;
  Color? color;

  Task({
    String? id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.status = TaskStatus.notStarted,
    this.progress = 0,
    this.color,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.index,
      'progress': progress,
      'color': color?.value,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: TaskStatus.values[json['status']],
      progress: json['progress'],
      color: json['color'] != null ? Color(json['color']) : null,
    );
  }
}

enum TaskStatus { notStarted, inProgress, completed }

class GanttChartScreen extends StatefulWidget {
  final List<Task> tasks;
  
  const GanttChartScreen({super.key, required this.tasks});

  @override
  GanttChartScreenState createState() => GanttChartScreenState();
}

class GanttChartScreenState extends State<GanttChartScreen> with TickerProviderStateMixin {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late List<Task> _tasks;
  late DateTime _startDate;
  late DateTime _endDate;
  double _dayWidth = 60.0;
  final String _storageKey = 'gantt_chart_tasks';
  late AnimationController _addTaskController;
  
  @override
  void initState() {
    super.initState();
    _tasks = List.from(widget.tasks);
    _addTaskController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString(_storageKey);
      if (tasksJson != null) {
        final List<dynamic> decodedTasks = jsonDecode(tasksJson);
        setState(() {
          _tasks = decodedTasks.map((task) => Task.fromJson(task)).toList();
          _calculateDateRange();
        });
      } else {
        setState(() {
          _calculateDateRange();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = jsonEncode(_tasks.map((task) => task.toJson()).toList());
      await prefs.setString(_storageKey, tasksJson);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving tasks: $e')),
        );
      }
    }
  }

  void _calculateDateRange() {
    if (_tasks.isEmpty) {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
      return;
    }

    _startDate = _tasks.fold(
      DateTime.now(),
      (min, task) => task.startDate.isBefore(min) ? task.startDate : min,
    );
    _endDate = _tasks.fold(
      DateTime.now(),
      (max, task) => task.endDate.isAfter(max) ? task.endDate : max,
    );

    // Add padding days
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day - 7);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day + 7);
  }

  Color _getStatusColor(TaskStatus status, Task task) {
    if (task.color != null) return task.color!;
    
    switch (status) {
      case TaskStatus.completed:
        return Colors.green.shade400;
      case TaskStatus.inProgress:
        return Colors.blue.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _tasks.remove(task);
        _calculateDateRange();
      });
      await _saveTasks();
    }
  }

  void _showTaskDialog({Task? task}) {
    final isNew = task == null;
    final titleController = TextEditingController(text: task?.title);
    DateTime startDate = task?.startDate ?? DateTime.now();
    DateTime endDate = task?.endDate ?? DateTime.now().add(const Duration(days: 1));
    TaskStatus status = task?.status ?? TaskStatus.notStarted;
    double progress = task?.progress ?? 0;
    Color selectedColor = task?.color ?? _getStatusColor(status, task ?? Task(
      title: '',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    ));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isNew ? 'Add Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(
                      'Start Date: ${DateFormat('MMM d, yyyy').format(startDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setDialogState(() => startDate = date);
                      }
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    title: Text(
                      'End Date: ${DateFormat('MMM d, yyyy').format(endDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setDialogState(() => endDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskStatus>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => status = value);
                    }
                  },
                  items: TaskStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.toString().split('.').last),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Progress: ${progress.round()}%'),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: selectedColor,
                    thumbColor: selectedColor,
                    overlayColor: selectedColor.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (value) {
                      setDialogState(() => progress = value);
                    },
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${progress.round()}%',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ...Colors.primaries.map((color) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                          boxShadow: selectedColor == color
                            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)]
                            : null,
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteTask(task);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final taskTitle = titleController.text.trim();
                if (taskTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a task title')),
                  );
                  return;
                }

                final newTask = Task(
                  id: task?.id,
                  title: taskTitle,
                  startDate: startDate,
                  endDate: endDate,
                  status: status,
                  progress: progress,
                  color: selectedColor,
                );

                setState(() {
                  if (isNew) {
                    _tasks.add(newTask);
                  } else {
                    final index = _tasks.indexWhere((t) => t.id == task.id);
                    _tasks[index] = newTask;
                  }
                  _calculateDateRange();
                });

                await _saveTasks();

                // Properly guard BuildContext usage
                if (mounted && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isNew ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => setState(() => _dayWidth *= 1.2),
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => setState(() => _dayWidth /= 1.2),
            tooltip: 'Zoom Out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _addTaskController.forward(from: 0);
          _showTaskDialog();
        },
        label: const Text('Add Task'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildTimelineHeader(),
          Expanded(
            child: Row(
              children: [
                _buildTaskList(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: _buildGanttChart(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListView.builder(
        controller: _verticalController,
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                   '${DateFormat('MMM d').format(task.startDate)} - ${DateFormat('MMM d').format(task.endDate)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.color ?? _getStatusColor(task.status, task),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              onTap: () => _showTaskDialog(task: task),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineHeader() {
    final days = _endDate.difference(_startDate).inDays + 1;
    return Container(
      height: 60,
      margin: const EdgeInsets.only(left: 200),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListView.builder(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        itemCount: days,
        itemBuilder: (context, index) {
          final date = _startDate.add(Duration(days: index));
          final isWeekend = date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday;
          return Container(
            width: _dayWidth,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey[300]!),
              ),
              color: isWeekend ? Colors.grey[100] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM d').format(date),
                  style: TextStyle(
                    color: isWeekend ? Colors.grey[600] : Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('E').format(date),
                  style: TextStyle(
                    color: isWeekend ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGanttChart() {
    final days = _endDate.difference(_startDate).inDays + 1;
    final height = _tasks.length * 60.0;
    final width = days * _dayWidth;

    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        // Draw vertical grid lines and weekend highlights
        for (var i = 0; i < days; i++) ...[
          Positioned(
            left: i * _dayWidth,
            top: 0,
            child: Container(
              width: _dayWidth,
              height: height,
              color:
                  _startDate.add(Duration(days: i)).weekday >= DateTime.saturday
                      ? Colors.grey[50]
                      : Colors.transparent,
            ),
          ),
          Positioned(
            left: i * _dayWidth,
            top: 0,
            child: Container(
              width: 1,
              height: height,
              color: Colors.grey[300],
            ),
          ),
        ],
        // Draw horizontal grid lines
        for (var i = 0; i < _tasks.length; i++)
          Positioned(
            top: i * 60.0,
            left: 0,
            child: Container(
              width: width,
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        // Draw task bars
        for (var i = 0; i < _tasks.length; i++) _buildGanttChartTask(i),
      ],
    );
  }

  Widget _buildGanttChartTask(int index) {
    final task = _tasks[index];
    final left = task.startDate.difference(_startDate).inDays * _dayWidth;
    final width =
        task.endDate.difference(task.startDate).inDays * _dayWidth + _dayWidth;

    return Positioned(
      top: index * 60.0 + 10,
      left: left,
      child: GestureDetector(
        onTap: () => _showTaskDialog(task: task),
        child: Container(
          height: 40,
          width: width,
          decoration: BoxDecoration(
            color: (task.color ?? _getStatusColor(task.status, task))
                .withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Container(
                width: width * (task.progress / 100),
                decoration: BoxDecoration(
                  color: task.color ?? _getStatusColor(task.status, task),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${task.progress.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _addTaskController.dispose();
    super.dispose();
  }
}
