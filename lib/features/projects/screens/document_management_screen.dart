import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() => _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends State<DocumentManagementScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _searchQuery = '';
  final Map<String, List<File>> _documents = {
    'Images': [],
    'Documents': [],
    'PDFs': [],
    'Other': [],
  };

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Images',
      'icon': Icons.image,
      'color': Colors.blue,
      'extensions': ['.jpg', '.jpeg', '.png', '.gif']
    },
    {
      'name': 'Documents',
      'icon': Icons.description,
      'color': Colors.green,
      'extensions': ['.doc', '.docx', '.txt']
    },
    {
      'name': 'PDFs',
      'icon': Icons.picture_as_pdf,
      'color': Colors.red,
      'extensions': ['.pdf']
    },
    {
      'name': 'Other',
      'icon': Icons.attachment,
      'color': Colors.grey,
      'extensions': []
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalFiles();
  }

  String _getFileType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    for (final category in _categories) {
      if ((category['extensions'] as List).contains(ext)) {
        return category['name'] as String;
      }
    }
    return 'Other';
  }

  Future<void> _loadLocalFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = Directory(appDir.path).listSync();

      setState(() {
        for (final category in _documents.keys) {
          _documents[category] = [];
        }

        for (final file in files) {
          if (file is File) {
            final category = _getFileType(file.path);
            _documents[category]?.add(file);
          }
        }
      });
    } catch (e) {
      _showMessage('Error loading files: $e', isError: true);
    }
  }

  Future<void> _uploadFile() async {
    if (_isUploading) {
      _showMessage('Upload in progress, please wait', isError: true);
      return;
    }

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _showMessage('No files selected');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final totalFiles = result.files.length;
      int processedFiles = 0;

      for (final file in result.files) {
        if (file.bytes == null) {
          _showMessage('Error: Unable to read ${file.name}', isError: true);
          continue;
        }

        final fileName = file.name;
        final localPath = path.join(appDir.path, fileName);

        final localFile = File(localPath);
        await localFile.writeAsBytes(file.bytes!);

        final category = _getFileType(fileName);
        setState(() {
          _documents[category]?.add(localFile);
          processedFiles++;
          _uploadProgress = processedFiles / totalFiles;
        });

        _showMessage('${file.name} uploaded successfully');
      }
    } catch (e) {
      _showMessage('Unexpected error during upload: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      await _loadLocalFiles();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        _showMessage('File not found: ${path.basename(filePath)}', isError: true);
        return;
      }

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showMessage('Could not open ${path.basename(filePath)}: ${result.message}', isError: true);
      }
    } catch (e) {
      _showMessage('Error opening file: $e', isError: true);
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      if (!await file.exists()) {
        _showMessage('File not found: ${path.basename(file.path)}', isError: true);
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sharing ${path.basename(file.path)}',
      );
    } catch (e) {
      _showMessage('Error sharing file: $e', isError: true);
    }
  }

  Future<bool> showDeleteConfirmation(BuildContext context, String fileName) async {
    if (!context.mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete $fileName?'),
        content: const Text('This action cannot be undone.'),
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
    ) ?? false;
  }

  Future<void> _deleteFile(File file, String category) async {
    try {
      if (!await file.exists()) {
        _showMessage('File already deleted: ${path.basename(file.path)}', isError: true);
        setState(() {
          _documents[category]?.remove(file);
        });
        return;
      }

      if (!mounted) return;  // Check before any async operation

      final String fileName = path.basename(file.path);
      final bool confirmDelete = await showDeleteConfirmation(context, fileName);

      if (!confirmDelete) return;
      
      if (!mounted) return;

      await file.delete();
      setState(() {
        _documents[category]?.remove(file);
      });
      
      if (mounted) {
        _showMessage('$fileName deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting file: $e', isError: true);
      }
    }
  }

  String _getFileInfo(File file) {
    final fileSize = _formatFileSize(file.lengthSync());
    final lastModified = _formatDate(file.lastModifiedSync());
    return 'Size: $fileSize\nModified: $lastModified';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFileItem(File file, String category) {
    final fileName = path.basename(file.path);
    final fileInfo = _getFileInfo(file);

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _shareFile(file),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.share,
            label: 'Share',
          ),
          SlidableAction(
            onPressed: (_) => _deleteFile(file, category),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Icon(
            _categories.firstWhere((cat) => cat['name'] == category)['icon'] as IconData,
            color: _categories.firstWhere((cat) => cat['name'] == category)['color'] as Color,
            size: 32,
          ),
          title: Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(fileInfo),
          onTap: () => _openFile(file.path),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: const Text('Open'),
                      onTap: () {
                        Navigator.pop(context);
                        _openFile(file.path);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share),
                      title: const Text('Share'),
                      onTap: () {
                        Navigator.pop(context);
                        _shareFile(file);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete'),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteFile(file, category);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Properties'),
                      onTap: () {
                        Navigator.pop(context);
                        _showFileProperties(file);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFileProperties(File file) {
    final fileName = path.basename(file.path);
    final fileExt = path.extension(file.path).toLowerCase();
    final fileSize = _formatFileSize(file.lengthSync());
    final dateCreated = _formatDate(file.statSync().changed);
    final dateModified = _formatDate(file.lastModifiedSync());
    final filePath = file.path;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Properties: $fileName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPropertyRow('Type', fileExt.isEmpty ? 'Unknown' : fileExt.substring(1).toUpperCase()),
              _buildPropertyRow('Size', fileSize),
              _buildPropertyRow('Created', dateCreated),
              _buildPropertyRow('Modified', dateModified),
              _buildPropertyRow('Location', filePath),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String categoryName, List<File> files) {
    final filteredFiles = files
        .where((file) => path.basename(file.path).toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    filteredFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return ExpansionTile(
      initiallyExpanded: categoryName == 'Documents' || categoryName == 'PDFs',
      leading: Icon(
        _categories.firstWhere((cat) => cat['name'] == categoryName)['icon'] as IconData,
        color: _categories.firstWhere((cat) => cat['name'] == categoryName)['color'] as Color,
      ),
      title: Text(
        '$categoryName (${filteredFiles.length})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: filteredFiles.map((file) => _buildFileItem(file, categoryName)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocalFiles,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadFile,
        icon: _isUploading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_isUploading ? 'Uploading...' : 'Upload File'),
      ),
      body: _documents.values.every((files) => files.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No files found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap the upload button to add files'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _uploadFile,
                    icon: const Icon(Icons.add),
                    label: const Text('Upload Files'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLocalFiles,
              child: ListView(
                children: _documents.entries
                    .map((entry) => _buildCategoryList(entry.key, entry.value))
                    .toList(),
              ),
            ),
    );
  }
}