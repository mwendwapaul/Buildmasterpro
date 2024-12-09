import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class CapturePhotosScreen extends StatefulWidget {
  const CapturePhotosScreen({super.key});

  @override
  CapturePhotosScreenState createState() => CapturePhotosScreenState();
}

class PhotoItem {
  String path;
  String title;
  String description;
  DateTime dateAdded;

  PhotoItem({
    required this.path,
    required this.title,
    required this.description,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'title': title,
      'description': description,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      path: json['path'],
      title: json['title'],
      description: json['description'],
      dateAdded: DateTime.parse(json['dateAdded']),
    );
  }
}

class CapturePhotosScreenState extends State<CapturePhotosScreen> {
  final List<PhotoItem> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getStringList('photos') ?? [];
      
      if (!mounted) return;

      setState(() {
        _photos.clear();
        for (var photoJson in photosJson) {
          final photoData = json.decode(photoJson);
          final photo = PhotoItem.fromJson(photoData);
          if (File(photo.path).existsSync()) {
            _photos.add(photo);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Error loading photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = _photos.map((photo) => json.encode(photo.toJson())).toList();
      await prefs.setStringList('photos', photosJson);
    } catch (e) {
      if (!mounted) return;
      _showError('Error saving photos: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (photo != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(photo.path)}';
        final String savedPath = path.join(appDir.path, fileName);
        
        await File(photo.path).copy(savedPath);

        if (!mounted) return;

        final newPhoto = PhotoItem(
          path: savedPath,
          title: 'Photo ${_photos.length + 1}',
          description: '',
          dateAdded: DateTime.now(),
        );

        setState(() {
          _photos.add(newPhoto);
        });
        await _savePhotos();
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error capturing photo: $e');
    }
  }

  Future<void> _editPhoto(int index) async {
    if (!mounted) return;
    
    final photo = _photos[index];
    final titleController = TextEditingController(text: photo.title);
    final descriptionController = TextEditingController(text: photo.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Photo Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        photo.title = titleController.text.trim();
        photo.description = descriptionController.text.trim();
      });
      await _savePhotos();
    }
  }

  Future<void> _deletePhoto(int index) async {
    if (!mounted) return;

    final photo = _photos[index];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        final file = File(photo.path);
        if (await file.exists()) {
          await file.delete();
        }
        
        if (!mounted) return;

        setState(() {
          _photos.removeAt(index);
        });
        await _savePhotos();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        _showError('Error deleting photo: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _viewPhoto(int index) {
    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photo: _photos[index],
          onDelete: () async {
            Navigator.pop(context);
            await _deletePhoto(index);
          },
          onEdit: () async {
            await _editPhoto(index);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _pickImage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No photos yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take a Photo'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: InkWell(
                        onTap: () => _viewPhoto(index),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              child: Image.file(
                                File(photo.path),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    photo.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (photo.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      photo.description,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Added on ${_formatDate(photo.dateAdded)}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OverflowBar(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                  onPressed: () => _editPhoto(index),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete'),
                                  onPressed: () => _deletePhoto(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class PhotoViewScreen extends StatelessWidget {
  final PhotoItem photo;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const PhotoViewScreen({
    super.key,
    required this.photo,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(photo.path),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}