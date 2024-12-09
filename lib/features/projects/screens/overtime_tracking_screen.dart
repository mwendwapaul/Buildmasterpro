import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeTrackingScreen extends StatefulWidget {
  const OvertimeTrackingScreen({super.key});

  @override
  OvertimeTrackingScreenState createState() => OvertimeTrackingScreenState();
}

class OvertimeTrackingScreenState extends State<OvertimeTrackingScreen> {
  final TextEditingController _hoursController = TextEditingController();
  final List<String> _overtimeRecords = [];

  @override
  void initState() {
    super.initState();
    _loadOvertimeRecords();
  }

  Future<void> _loadOvertimeRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _overtimeRecords.addAll(prefs.getStringList('overtimeRecords') ?? []);
    });
  }

  Future<void> _saveOvertimeRecord(String record) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _overtimeRecords.add(record);
    await prefs.setStringList('overtimeRecords', _overtimeRecords);
    _hoursController.clear();
    setState(() {});
  }

  void _addOvertimeRecord() {
    final hours = _hoursController.text;
    if (hours.isNotEmpty && double.tryParse(hours) != null) {
      final record = 'Overtime: $hours hours';
      _saveOvertimeRecord(record);
    } else {
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Entry'),
        content: const Text('Please enter a valid number of hours.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecord(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _overtimeRecords.removeAt(index);
                _saveRecordsToPrefs();
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecordsToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('overtimeRecords', _overtimeRecords);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Tracking'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter Overtime Hours',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addOvertimeRecord,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _overtimeRecords.isNotEmpty
                  ? ListView.builder(
                      itemCount: _overtimeRecords.length,
                      itemBuilder: (context, index) {
                        return Dismissible(
                          key: Key(_overtimeRecords[index]),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            _confirmDeleteRecord(index);
                          },
                          child: ListTile(
                            title: Text(_overtimeRecords[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteRecord(index),
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'No overtime records yet.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
