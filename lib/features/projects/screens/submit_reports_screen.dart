import 'package:build_masterpro/models/report.dart';
import 'package:build_masterpro/services/report_service.dart';
import 'package:build_masterpro/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class SubmitReportScreen extends StatefulWidget {
  final String userId;

  const SubmitReportScreen({super.key, required this.userId});

  @override
  SubmitReportScreenState createState() => SubmitReportScreenState();
}

class SubmitReportScreenState extends State<SubmitReportScreen> {
  final TextEditingController _reportController = TextEditingController();
  final StorageService _storageService = StorageService();
  final ReportService _reportService = ReportService();

  String? _fileName;
  File? _file;
  bool _isSubmitting = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_reportController.text.isEmpty) {
      _showMessage('Please enter a report description.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? fileUrl;
      if (_file != null) {
        fileUrl = await _storageService.uploadFile(_file!, widget.userId);
      }

      final report = Report(
        id: const Uuid().v4(),
        description: _reportController.text,
        fileUrl: fileUrl,
        fileName: _fileName ?? '',
        userId: widget.userId,
        timestamp: DateTime.now(),
      );

      await _reportService.submitReport(report);

      if (!mounted) return;

      _reportController.clear();
      setState(() {
        _fileName = null;
        _file = null;
        _isSubmitting = false;
      });

      _showMessage('Report submitted successfully!');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showMessage('Error submitting report: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter report details here...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Attach File'),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Attached File: $_fileName',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
