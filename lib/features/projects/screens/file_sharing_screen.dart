import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

class SharedFile {
  final String id;
  final String name;
  final String url;
  final String uploadedBy;
  final String uploadedByEmail;
  final DateTime uploadedAt;
  final String fileType;
  final List<String> sharedWith;
  final int size;

  SharedFile({
    required this.id,
    required this.name,
    required this.url,
    required this.uploadedBy,
    required this.uploadedByEmail,
    required this.uploadedAt,
    required this.fileType,
    required this.sharedWith,
    required this.size,
  });

  factory SharedFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedFile(
      id: doc.id,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedByEmail: data['uploadedByEmail'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      fileType: data['fileType'] ?? '',
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      size: data['size'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'url': url,
      'uploadedBy': uploadedBy,
      'uploadedByEmail': uploadedByEmail,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'fileType': fileType,
      'sharedWith': sharedWith,
      'size': size,
    };
  }
}

class FileSharingScreen extends StatefulWidget {
  const FileSharingScreen({super.key});

  @override
  State<FileSharingScreen> createState() => _FileSharingScreenState();
}

class _FileSharingScreenState extends State<FileSharingScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login'); // Adjust route name as needed
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_currentUser == null) {
      _showErrorMessage('Please login to upload files');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.first.path!);
      final fileName = path.basename(file.path);
      final fileSize = await file.length();

      if (fileSize > 100 * 1024 * 1024) { // 100MB limit
        _showErrorMessage('File size must be less than 100MB');
        setState(() => _isLoading = false);
        return;
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${_currentUser.uid}_${timestamp}_$fileName';
      
      // Create storage reference
      final storageRef = _storage.ref().child('shared_files/$uniqueFileName');
      
      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(fileName),
        customMetadata: {
          'uploadedBy': _currentUser.displayName ?? 'Unknown',
          'uploadedByEmail': _currentUser.email ?? '',
        },
      );

      // Start upload
      final uploadTask = storageRef.putFile(file, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Upload progress: $progress%');
      }, onError: (e) {
        _showErrorMessage('Upload failed: $e');
        setState(() => _isLoading = false);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      final sharedFile = SharedFile(
        id: '',
        name: fileName,
        url: downloadUrl,
        uploadedBy: _currentUser.displayName ?? 'Unknown',
        uploadedByEmail: _currentUser.email ?? '',
        uploadedAt: DateTime.now(),
        fileType: path.extension(fileName).toLowerCase(),
        sharedWith: [_currentUser.email!],
        size: fileSize,
      );

      final docRef = await _firestore.collection('shared_files').add(sharedFile.toFirestore());
      
      // Update the document with its ID
      await docRef.update({'id': docRef.id});

      _showSuccessMessage('File uploaded successfully');
    } catch (e) {
      _showErrorMessage('Error uploading file: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getContentType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _shareFile(SharedFile file) async {
    if (_currentUser == null) {
      _showErrorMessage('Please login to share files');
      return;
    }

    final email = await _showEmailInputDialog();
    
    if (email == null || email.isEmpty) return;

    if (!_isValidEmail(email)) {
      _showErrorMessage('Please enter a valid email address');
      return;
    }

    if (file.sharedWith.contains(email)) {
      _showErrorMessage('File is already shared with this user');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Update Firestore
      await _firestore.collection('shared_files').doc(file.id).update({
        'sharedWith': FieldValue.arrayUnion([email]),
      });

      // Send email notification (implement your email service here)
      // await _sendShareNotificationEmail(email, file.name, _currentUser!.email!);

      _showSuccessMessage('File shared successfully with $email');
    } catch (e) {
      _showErrorMessage('Error sharing file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(email);
  }

  Future<String?> _showEmailInputDialog() {
    final emailController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Share File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Enter email address',
                hintText: 'user@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(SharedFile file) async {
    if (_currentUser == null) {
      _showErrorMessage('Please login to delete files');
      return;
    }

    if (file.uploadedByEmail != _currentUser.email) {
      _showErrorMessage('You can only delete files you uploaded');
      return;
    }

    final confirmed = await _showDeleteConfirmationDialog(file.name);
    if (!confirmed) return;

    try {
      setState(() => _isLoading = true);

      // Delete from Storage
      final storageRef = FirebaseStorage.instance.refFromURL(file.url);
      await storageRef.delete();

      // Delete from Firestore
      await _firestore.collection('shared_files').doc(file.id).delete();

      _showSuccessMessage('File deleted successfully');
    } catch (e) {
      _showErrorMessage('Error deleting file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String fileName) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$fileName"?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _downloadAndShareFile(SharedFile file) async {
    try {
      setState(() => _isLoading = true);

      // Download file to cache
      final cachedFile = await DefaultCacheManager().getSingleFile(file.url);
      
      if (!mounted) return;

      // Share file
      await Share.shareXFiles(
        [XFile(cachedFile.path)],
        subject: file.name,
        text: 'Shared via File Sharing App',
      );
    } catch (e) {
      _showErrorMessage('Error sharing file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget _buildFileTypeIcon(String fileType) {
    IconData icon;
    Color color;

    switch (fileType.toLowerCase()) {
      case '.pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case '.doc':
      case '.docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        icon = Icons.image;
        color = Colors.green;
        break;
      case '.mp4':
      case '.mov':
      case '.avi':
        icon = Icons.video_file;
        color = Colors.purple;
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
        icon = Icons.audio_file;
        color = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 32);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('File Sharing'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('shared_files')
                .where('sharedWith', arrayContains: _currentUser?.email)
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final files = snapshot.data!.docs
                  .map((doc) => SharedFile.fromFirestore(doc))
                  .where((file) =>
                      file.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      file.uploadedBy
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                  .toList();

              if (files.isEmpty) {
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
                        _searchQuery.isEmpty
                            ? 'No files shared with you yet'
                            : 'No files match your search',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickAndUploadFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload your first file'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: files.length,
                padding: const EdgeInsets.only(bottom: 80),
                itemBuilder: (context, index) {
                  final file = files[index];
                  final isOwner = file.uploadedByEmail == _currentUser?.email;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: _buildFileTypeIcon(file.fileType),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uploaded by ${file.uploadedBy} • ${timeago.format(file.uploadedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Size: ${_formatFileSize(file.size)} • Shared with ${file.sharedWith.length} ${file.sharedWith.length == 1 ? 'person' : 'people'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Download',
                            onPressed: () => _downloadAndShareFile(file),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              switch (value) {
                                case 'share':
                                  await _shareFile(file);
                                  break;
                                case 'delete':
                                  if (isOwner) {
                                    await _deleteFile(file);
                                  } else {
                                    _showErrorMessage(
                                        'You can only delete files you uploaded');
                                  }
                                  break;
                                case 'details':
                                  _showFileDetails(file);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share),
                                    SizedBox(width: 8),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'details',
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline),
                                    SizedBox(width: 8),
                                    Text('Details'),
                                  ],
                                ),
                              ),
                              if (isOwner)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickAndUploadFile,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload File'),
      ),
    );
  }

  void _showFileDetails(SharedFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', file.name),
            _buildDetailRow('Type', file.fileType),
            _buildDetailRow('Size', _formatFileSize(file.size)),
            _buildDetailRow('Uploaded by', file.uploadedBy),
            _buildDetailRow(
                'Upload date',
                DateTime.now().difference(file.uploadedAt).inDays > 1
                    ? file.uploadedAt.toString().split('.')[0]
                    : timeago.format(file.uploadedAt)),
            const Divider(),
            const Text('Shared with:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: file.sharedWith
                      .map((email) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $email'),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
}
