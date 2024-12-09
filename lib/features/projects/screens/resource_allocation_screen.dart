import 'package:build_masterpro/models/task.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResourceAllocationScreen extends StatefulWidget {
  const ResourceAllocationScreen({super.key});

  @override
  ResourceAllocationScreenState createState() =>
      ResourceAllocationScreenState();
}

class ResourceAllocationScreenState extends State<ResourceAllocationScreen> {
  final Map<String, List<Task>> _resourceAllocations = {};

  @override
  void initState() {
    super.initState();
    _loadResourceAllocations();
  }

  // Load resource allocations from SharedPreferences
  Future<void> _loadResourceAllocations() async {
    final prefs = await SharedPreferences.getInstance();
    final resourceData = prefs.getString('resourceAllocations');
    if (resourceData != null) {
      final decodedData = resourceData.split('||');
      for (var data in decodedData) {
        final parts = data.split('|');
        if (parts.length == 5) {
          final resourceName = parts[0];
          final task = Task(
            id: parts[1],
            title: parts[2],
            description: parts[3],
            startDate: DateTime.parse(parts[4]),
            endDate: DateTime.parse(parts[5]),
          );
          setState(() {
            _resourceAllocations.putIfAbsent(resourceName, () => []).add(task);
          });
        }
      }
    }
  }

  // Save the resource allocations to SharedPreferences
  Future<void> _saveResourceAllocations() async {
    final prefs = await SharedPreferences.getInstance();
    final resourceData = _resourceAllocations.entries
        .map((entry) {
          return entry.value
              .map((task) {
                return '${entry.key}|${task.id}|${task.title}|${task.description}|${task.startDate.toIso8601String()}|${task.endDate.toIso8601String()}';
              })
              .join('||');
        })
        .join('||');
    await prefs.setString('resourceAllocations', resourceData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Allocation'),
        backgroundColor: Colors.red,
      ),
      body: _resourceAllocations.isEmpty
          ? Center(
              child: Text(
                'No resources allocated. Click + to add a new allocation.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _resourceAllocations.length,
              itemBuilder: (context, index) {
                final resource = _resourceAllocations.keys.elementAt(index);
                final tasks = _resourceAllocations[resource]!;
                return ExpansionTile(
                  title: Text(resource),
                  children: tasks.map((task) {
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.startDate.toLocal().toString().split(' ')[0]} - '
                        '${task.endDate.toLocal().toString().split(' ')[0]}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _removeTaskFromResource(resource, task),
                      ),
                      onTap: () => _editTaskDetails(resource, task),
                    );
                  }).toList(),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addResourceAllocation,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addResourceAllocation() {
    String selectedResource = '';
    final TextEditingController taskTitleController = TextEditingController();
    final TextEditingController taskDescriptionController =
        TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Resource Allocation'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Resource Name'),
                  onChanged: (value) {
                    selectedResource = value;
                  },
                ),
                TextField(
                  controller: taskTitleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                TextField(
                  controller: taskDescriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Task Description'),
                ),
                ListTile(
                  title: const Text('Start Date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      startDate = await _selectDate(context, startDate);
                      setState(() {});
                    },
                  ),
                  subtitle: startDate != null
                      ? Text('${startDate!.toLocal()}'.split(' ')[0])
                      : const Text('No date selected'),
                ),
                ListTile(
                  title: const Text('End Date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      endDate = await _selectDate(context, endDate);
                      setState(() {});
                    },
                  ),
                  subtitle: endDate != null
                      ? Text('${endDate!.toLocal()}'.split(' ')[0])
                      : const Text('No date selected'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (selectedResource.isNotEmpty &&
                    taskTitleController.text.isNotEmpty &&
                    startDate != null &&
                    endDate != null) {
                  setState(() {
                    _resourceAllocations.putIfAbsent(
                        selectedResource, () => []);
                    _resourceAllocations[selectedResource]!.add(Task(
                      id: DateTime.now().toString(),
                      title: taskTitleController.text,
                      description: taskDescriptionController.text,
                      startDate: startDate!,
                      endDate: endDate!,
                    ));
                  });
                  _saveResourceAllocations();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editTaskDetails(String resource, Task task) {
    final TextEditingController taskTitleController =
        TextEditingController(text: task.title);
    final TextEditingController taskDescriptionController =
        TextEditingController(text: task.description);
    DateTime? startDate = task.startDate;
    DateTime? endDate = task.endDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task Details'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: taskTitleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                TextField(
                  controller: taskDescriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Task Description'),
                ),
                ListTile(
                  title: const Text('Start Date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      startDate = await _selectDate(context, startDate);
                      setState(() {});
                    },
                  ),
                  subtitle: startDate != null
                      ? Text('${startDate!.toLocal()}'.split(' ')[0])
                      : const Text('No date selected'),
                ),
                ListTile(
                  title: const Text('End Date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      endDate = await _selectDate(context, endDate);
                      setState(() {});
                    },
                  ),
                  subtitle: endDate != null
                      ? Text('${endDate!.toLocal()}'.split(' ')[0])
                      : const Text('No date selected'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (taskTitleController.text.isNotEmpty &&
                    startDate != null &&
                    endDate != null) {
                  setState(() {
                    task.title = taskTitleController.text;
                    task.description = taskDescriptionController.text;
                    task.startDate = startDate!;
                    task.endDate = endDate!;
                  });
                  _saveResourceAllocations();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _removeTaskFromResource(String resource, Task task) {
    setState(() {
      _resourceAllocations[resource]?.remove(task);
      if (_resourceAllocations[resource]?.isEmpty ?? false) {
        _resourceAllocations.remove(resource);
      }
      _saveResourceAllocations();
    });
  }

  Future<DateTime?> _selectDate(
      BuildContext context, DateTime? initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    return picked;
  }
}
