import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OvertimeTrackingScreen extends StatefulWidget {
  const OvertimeTrackingScreen({super.key});

  @override
  OvertimeTrackingScreenState createState() => OvertimeTrackingScreenState();
}

class OvertimeTrackingScreenState extends State<OvertimeTrackingScreen> {
  final TextEditingController _hoursController = TextEditingController();
  final List<Map<String, dynamic>> _overtimeRecords = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOvertimeRecords();
  }

  Future<void> _loadOvertimeRecords() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('Authentication Error', 'Please sign in to view overtime records.');
      return;
    }

    try {
      final snapshot = await _usersCollection
          .doc(user.uid)
          .collection('overtime_records')
          .orderBy('timestamp', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _overtimeRecords.clear();
        _overtimeRecords.addAll(snapshot.docs.map((doc) => {
              'id': doc.id,
              'hours': doc['hours'] as double,
              'timestamp': (doc['timestamp'] as Timestamp).toDate(),
            }));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error', 'Failed to load overtime records: $e');
    }
  }

  Future<void> _saveOvertimeRecord(double hours) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final record = {
        'hours': hours,
        'timestamp': Timestamp.fromDate(now),
        'userId': user.uid,
      };

      await _usersCollection
          .doc(user.uid)
          .collection('overtime_records')
          .doc(now.millisecondsSinceEpoch.toString())
          .set(record);

      _hoursController.clear();
      await _loadOvertimeRecords();
    } catch (e) {
      _showErrorDialog('Error', 'Failed to save overtime record: $e');
    }
  }

  void _addOvertimeRecord() {
    final hoursText = _hoursController.text;
    final hours = double.tryParse(hoursText);
    if (hours != null && hours > 0) {
      _saveOvertimeRecord(hours);
    } else {
      _showErrorDialog('Invalid Entry', 'Please enter a valid positive number of hours.');
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecord(String recordId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Store the Navigator instance before async operations
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('Delete Record'),
          content: const Text('Are you sure you want to delete this record?'),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    await _usersCollection
                        .doc(user.uid)
                        .collection('overtime_records')
                        .doc(recordId)
                        .delete();
                    await _loadOvertimeRecords();
                    navigator.pop(); // Use stored navigator instance
                  } catch (e) {
                    if (mounted) {
                      _showErrorDialog('Error', 'Failed to delete record: $e');
                    }
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                              final record = _overtimeRecords[index];
                              final formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(record['timestamp']);
                              return Dismissible(
                                key: Key(record['id']),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) {
                                  _confirmDeleteRecord(record['id']);
                                },
                                child: ListTile(
                                  title: Text('Overtime: ${record['hours']} hours'),
                                  subtitle: Text('Added: $formattedDate'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDeleteRecord(record['id']),
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