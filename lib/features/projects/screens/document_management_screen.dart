import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() => _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends State<DocumentManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUploading = false;
  String? _selectedCategory;
  String? _selectedFilterCategory;
  double _uploadProgress = 0.0;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Images', 'icon': Icons.image, 'extensions': ['.jpg', '.jpeg', '.png', '.gif']},
    {'name': 'Documents', 'icon': Icons.description, 'extensions': ['.doc', '.docx', '.txt']},
    {'name': 'PDFs', 'icon': Icons.picture_as_pdf, 'extensions': ['.pdf']},
    {'name': 'Other', 'icon': Icons.attachment, 'extensions': []}
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _resetUploadState() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedCategory = null;
    _uploadProgress = 0.0;
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
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
        onFileLoading: (FilePickerStatus status) => debugPrint(status.toString()),
      );

      if (result == null || result.files.isEmpty) {
        _showMessage('No files selected');
        return;
      }

      for (final file in result.files) {
        if (file.bytes == null) {
          _showMessage('Error: Unable to read ${file.name}', isError: true);
          continue;
        }

        _resetUploadState();
        _nameController.text = file.name;
        _selectedCategory = _getFileType(file.name);

        final shouldUpload = await _showFileDetailsDialog();
        if (!shouldUpload) continue;

        final fileName = _nameController.text.trim();
        if (fileName.isEmpty) {
          _showMessage('File name cannot be empty', isError: true);
          continue;
        }

        final description = _descriptionController.text.trim();
        final category = _selectedCategory ?? _getFileType(file.name);
        final fileBytes = file.bytes!;
        final fileExtension = path.extension(fileName).toLowerCase();
        
        // Ensure the current user is authenticated
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _showMessage('User not authenticated', isError: true);
          continue;
        }

        // Create a unique filename to prevent overwrites
        final uniqueFileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('documents/$uniqueFileName');

        // Set proper content type based on file extension
        final contentType = _getContentType(fileExtension);
        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'originalName': fileName,
            'category': category,
            'description': description,
            'uploadedBy': user.uid,
          },
        );

        try {
          // Upload file to Firebase Storage
          final uploadTask = storageRef.putData(fileBytes, metadata);

          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              setState(() {
                _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
              });
            },
            onError: (error) {
              _showMessage('Storage upload error: $error', isError: true);
              debugPrint('Storage upload error: $error');
            },
          );

          // Wait for upload to complete
          final snapshot = await uploadTask;
          
          // Get download URL
          final downloadUrl = await snapshot.ref.getDownloadURL();

          // Add document metadata to Firestore
          await FirebaseFirestore.instance.collection('documents').add({
            'name': fileName,
            'description': description,
            'category': category,
            'url': downloadUrl,
            'uploadedBy': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'fileType': fileExtension,
            'size': fileBytes.length,
            'storagePath': storageRef.fullPath,
          });

          _showMessage('${file.name} uploaded successfully');
        } catch (e) {
          _showMessage('Upload process error: $e', isError: true);
          debugPrint('Upload process error: $e');
          
          // Attempt to delete the storage reference if something went wrong
          try {
            await storageRef.delete();
          } catch (deleteError) {
            debugPrint('Error cleaning up storage file: $deleteError');
          }
        }
      }
    } catch (e) {
      _showMessage('Unexpected error during upload: $e', isError: true);
      debugPrint('Unexpected error: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<bool> _showFileDetailsDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('File Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'File Name',
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
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category['name'] as String,
                        child: Row(
                          children: [
                            Icon(category['icon'] as IconData),
                            const SizedBox(width: 8),
                            Text(category['name'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) {
                    _showMessage('Please enter a file name', isError: true);
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Upload'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteDocument(String docId, String url, String storagePath) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this file?'),
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
        ) ??
        false;

    if (!confirmed) return;

    try {
      // First try to delete from Storage
      try {
        final storageRef = FirebaseStorage.instance.ref().child(storagePath);
        await storageRef.delete();
      } catch (e) {
        debugPrint('Error deleting from storage: $e');
        // Continue with Firestore deletion even if Storage deletion fails
      }

      // Then delete from Firestore
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .delete();
      
      _showMessage('File deleted successfully');
    } catch (e) {
      _showMessage('Error deleting file: $e', isError: true);
    }
  }

  Future<void> _viewDocument(DocumentSnapshot doc) async {
    final url = doc['url'] as String;
    final fileType = doc['fileType'] as String?;
    final name = doc['name'] as String;

    try {
      if (fileType != null &&
          ['.jpg', '.jpeg', '.png', '.gif'].contains(fileType.toLowerCase())) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(name),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text('Error loading image'),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final file = await DefaultCacheManager().getSingleFile(url);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      }
    } catch (e) {
      _showMessage('Error opening file: $e', isError: true);
    }
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${suffixes[i]}';
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by category',
            itemBuilder: (context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('All'),
              ),
              ..._categories.map((category) {
                return PopupMenuItem<String?>(
                  value: category['name'] as String,
                  child: Row(
                    children: [
                      Icon(category['icon'] as IconData),
                      const SizedBox(width: 8),
                      Text(category['name'] as String),
                    ],
                  ),
                );
              }),
            ],
            onSelected: (value) => setState(() => _selectedFilterCategory = value),
          ),
        ],
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildDocumentsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading documents: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilterCategory != null
                        ? 'No files in $_selectedFilterCategory category'
                        : 'No files uploaded yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _uploadFile,
                    icon: const Icon(Icons.add),
                    label: const Text('Upload File'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final category = _categories.firstWhere(
                (cat) => cat['name'] == data['category'],
                orElse: () => _categories.last,
              );

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: ExpansionTile(
                  leading: Icon(
                    category['icon'] as IconData,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(
                    data['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Size: ${_formatFileSize(data['size'] as int)}\n'
                    'Uploaded: ${DateFormat.yMMMd().add_jm().format((data['timestamp'] as Timestamp).toDate())}',
                  ),
                  children: [
                    if (data['description']?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Description:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              data['description'] as String,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          tooltip: 'View',
                          onPressed: () => _viewDocument(doc),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Download',
                          onPressed: () async {
                            try {
                              final url = data['url'] as String;
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                throw 'Could not launch $url';
                              }
                            } catch (e) {
                              _showMessage(
                                'Error downloading file: $e',
                                isError: true,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete',
                          color: Colors.red,
                          onPressed: () => _deleteDocument(
                            doc.id,
                            data['url'] as String,
                            data['storagePath'] as String,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // New method to build the Firestore query stream
  Stream<QuerySnapshot> _buildDocumentsStream() {
    Query query = FirebaseFirestore.instance.collection('documents');

    // Apply category filter if a category is selected
    if (_selectedFilterCategory != null) {
      query = query.where('category', isEqualTo: _selectedFilterCategory);
    }

    // Order by timestamp in descending order
    return query.orderBy('timestamp', descending: true).snapshots();
  }
}