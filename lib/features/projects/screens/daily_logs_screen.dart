import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DailyLogsScreen extends StatefulWidget {
  const DailyLogsScreen({super.key});

  @override
  DailyLogsScreenState createState() => DailyLogsScreenState();
}

class DailyLogsScreenState extends State<DailyLogsScreen> {
  List<Map<String, String>> _logs = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? logsString = prefs.getString('dailyLogs');
      if (logsString != null && mounted) {
        setState(() {
          _logs = List<Map<String, String>>.from(
            (json.decode(logsString) as List)
                .map((item) => Map<String, String>.from(item)),
          );
          _logs.sort((a, b) => DateTime.parse(b['timestamp']!)
              .compareTo(DateTime.parse(a['timestamp']!)));
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error loading logs: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLogs() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dailyLogs', json.encode(_logs));
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error saving logs: $e');
      }
    }
  }

  Future<void> _addLog(String log) async {
    if (!mounted) return;

    setState(() {
      _logs.insert(0, {
        'log': log,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    await _saveLogs();
  }

  Future<void> _editLog(int index, String newLog) async {
    if (!mounted) return;

    setState(() {
      _logs[index] = {
        'log': newLog,
        'timestamp': _logs[index]['timestamp']!,
      };
    });
    await _saveLogs();
  }

  Future<void> _deleteLog(int index) async {
    if (!mounted) return;

    setState(() {
      _logs.removeAt(index);
    });
    await _saveLogs();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogDialog(
    BuildContext dialogContext, {
    required TextEditingController controller,
    required int? editIndex,
    required VoidCallback onCancel,
    required Function() onSave,
  }) {
    return AlertDialog(
      title: Text(editIndex != null ? 'Edit Log' : 'Add Daily Log'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter log here',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onSave,
          child: Text(editIndex != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _showLogDialog({int? editIndex}) async {
    if (!mounted) return;

    final String log = editIndex != null ? _logs[editIndex]['log']! : '';
    final TextEditingController controller = TextEditingController(text: log);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _buildLogDialog(
          dialogContext,
          controller: controller,
          editIndex: editIndex,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSave: () async {
            if (controller.text.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop();
              if (editIndex != null) {
                await _editLog(editIndex, controller.text.trim());
              } else {
                await _addLog(controller.text.trim());
              }
            }
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(int index) {
    if (!mounted) return Future.value(null);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this log?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, String>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs
        .where((log) =>
            log['log']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _LogSearchDelegate(
                  logs: _logs,
                  onSelected: (query) {
                    if (!mounted) return;
                    setState(() => _searchQuery = query);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No logs available.'
                            : 'No matching logs found.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        return Dismissible(
                          key: Key(log['timestamp']!),
                          onDismissed: (_) => _deleteLog(index),
                          confirmDismiss: (_) async {
                            final shouldDelete =
                                await _showDeleteConfirmation(index);
                            return shouldDelete ?? false;
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _showLogDialog(editIndex: index),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log['log']!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      DateTime.parse(log['timestamp']!)
                                          .toLocal()
                                          .toString()
                                          .split('.')[0],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLogDialog(),
        tooltip: 'Add Log',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LogSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, String>> logs;
  final Function(String) onSelected;

  _LogSearchDelegate({required this.logs, required this.onSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSelected(query);
    close(context, query);
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredLogs = logs
        .where((log) => log['log']!.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return ListTile(
          title: Text(log['log']!),
          subtitle: Text(DateTime.parse(log['timestamp']!)
              .toLocal()
              .toString()
              .split('.')[0]),
          onTap: () {
            onSelected(query);
            close(context, query);
          },
        );
      },
    );
  }
}
