import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:build_masterpro/models/activity_log.dart';
import 'package:build_masterpro/services/activity_log_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final ActivityLogService _logService = ActivityLogService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _actionController = TextEditingController();
  
  List<ActivityLog> _allLogs = [];
  List<ActivityLog> _filteredLogs = [];
  bool _isLoading = false;
  String _filterAction = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await _logService.getLogs();
      setState(() {
        _allLogs = logs;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load logs: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        if (_filterAction.isNotEmpty &&
            !log.action.toLowerCase().contains(_filterAction.toLowerCase())) {
          return false;
        }
        
        if (_filterStartDate != null) {
          final startOfDay = DateTime(_filterStartDate!.year, 
                                   _filterStartDate!.month, 
                                   _filterStartDate!.day);
          if (log.timestamp.isBefore(startOfDay)) {
            return false;
          }
        }
        
        if (_filterEndDate != null) {
          final endOfDay = DateTime(_filterEndDate!.year, 
                                  _filterEndDate!.month, 
                                  _filterEndDate!.day, 23, 59, 59);
          if (log.timestamp.isAfter(endOfDay)) {
            return false;
          }
        }
        
        return true;
      }).toList();

      // Sort by timestamp descending
      _filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Implement pagination here if needed
      // _loadMoreLogs();
    }
  }

  Future<void> _showFilterDialog() async {
    final tempStartDate = _filterStartDate;
    final tempEndDate = _filterEndDate;
    final tempAction = _filterAction;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Logs'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _actionController..text = _filterAction,
                decoration: const InputDecoration(
                  labelText: 'Action',
                  hintText: 'Filter by action type',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _filterAction = value,
              ),
              const SizedBox(height: 16),
              Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerButton(
                      label: 'Start Date',
                      selectedDate: _filterStartDate,
                      onDateSelected: (date) => setState(() => _filterStartDate = date),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DatePickerButton(
                      label: 'End Date',
                      selectedDate: _filterEndDate,
                      onDateSelected: (date) => setState(() => _filterEndDate = date),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterAction = '';
                _filterStartDate = null;
                _filterEndDate = null;
                _actionController.clear();
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _filterAction = tempAction;
                _filterStartDate = tempStartDate;
                _filterEndDate = tempEndDate;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterAction.isNotEmpty || _filterStartDate != null || _filterEndDate != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_filterAction.isNotEmpty)
                          _FilterChip(
                            label: 'Action: $_filterAction',
                            onRemove: () => setState(() {
                              _filterAction = '';
                              _actionController.clear();
                              _applyFilters();
                            }),
                          ),
                        if (_filterStartDate != null)
                          _FilterChip(
                            label: 'From: ${DateFormat('MMM dd, yyyy').format(_filterStartDate!)}',
                            onRemove: () => setState(() {
                              _filterStartDate = null;
                              _applyFilters();
                            }),
                          ),
                        if (_filterEndDate != null)
                          _FilterChip(
                            label: 'To: ${DateFormat('MMM dd, yyyy').format(_filterEndDate!)}',
                            onRemove: () => setState(() {
                              _filterEndDate = null;
                              _applyFilters();
                            }),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _filterAction = '';
                      _filterStartDate = null;
                      _filterEndDate = null;
                      _actionController.clear();
                      _applyFilters();
                    }),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildLogsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_isLoading && _filteredLogs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadLogs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No activity logs found'),
            if (_filterAction.isNotEmpty || _filterStartDate != null || _filterEndDate != null)
              const Text('Try adjusting your filters'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadLogs,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _filteredLogs.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredLogs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final log = _filteredLogs[index];
          return _LogCard(log: log);
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final ActivityLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          log.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, 
                     size: 16, 
                     color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(log.userName),
              ],
            ),
            Row(
              children: [
                Icon(Icons.label_outline, 
                     size: 16, 
                     color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(log.action),
              ],
            ),
            Row(
              children: [
                Icon(Icons.access_time, 
                     size: 16, 
                     color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp)),
              ],
            ),
            if (log.targetType != null)
              Row(
                children: [
                  Icon(Icons.category_outlined, 
                       size: 16, 
                       color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(log.targetType!),
                ],
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;

  const _DatePickerButton({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        onDateSelected(date);
      },
      child: Text(
        selectedDate != null
            ? DateFormat('MMM dd, yyyy').format(selectedDate!)
            : label,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onRemove,
    );
  }
}