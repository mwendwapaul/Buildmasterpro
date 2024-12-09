import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChecklistItem {
  String text;
  bool isCompleted;

  ChecklistItem({
    required this.text,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isCompleted': isCompleted,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    text: json['text'],
    isCompleted: json['isCompleted'],
  );
}

class ChecklistsScreen extends StatefulWidget {
  const ChecklistsScreen({super.key});

  @override
  ChecklistsScreenState createState() => ChecklistsScreenState();
}

class ChecklistsScreenState extends State<ChecklistsScreen> {
  final List<ChecklistItem> _checklistItems = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  // Load checklist items from SharedPreferences
  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('checklist_items');
    
    if (itemsJson != null) {
      final List<dynamic> decodedItems = jsonDecode(itemsJson);
      if (mounted) {  // Add mounted check before setState
        setState(() {
          _checklistItems.clear();
          _checklistItems.addAll(
            decodedItems.map((item) => ChecklistItem.fromJson(item)).toList(),
          );
        });
      }
    }
  }

  // Save checklist items to SharedPreferences
  Future<void> _saveChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedItems = jsonEncode(
      _checklistItems.map((item) => item.toJson()).toList(),
    );
    await prefs.setString('checklist_items', encodedItems);
    
    // Add mounted check before using BuildContext
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist saved successfully!')),
      );
    }
  }

  // Add a new item to the checklist
  void _addChecklistItem() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _checklistItems.add(ChecklistItem(text: _controller.text));
        _controller.clear();
      });
      _saveChecklist();
    }
  }

  // Remove an item from the checklist
  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
    });
    _saveChecklist();
  }

  // Toggle completion status of an item
  void _toggleItemCompletion(int index) {
    setState(() {
      _checklistItems[index].isCompleted = !_checklistItems[index].isCompleted;
    });
    _saveChecklist();
  }

  // Clear all completed items
  void _clearCompletedItems() {
    setState(() {
      _checklistItems.removeWhere((item) => item.isCompleted);
    });
    _saveChecklist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklists'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_completed') {
                _clearCompletedItems();
              } else if (value == 'save') {
                _saveChecklist();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Text('Clear Completed'),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Text('Save'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Add Checklist Item',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addChecklistItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addChecklistItem,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _checklistItems.length,
                itemBuilder: (context, index) {
                  final item = _checklistItems[index];
                  return Dismissible(
                    key: Key(item.text + index.toString()),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _removeChecklistItem(index),
                    child: ListTile(
                      leading: Checkbox(
                        value: item.isCompleted,
                        onChanged: (_) => _toggleItemCompletion(index),
                      ),
                      title: Text(
                        item.text,
                        style: TextStyle(
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeChecklistItem(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}