import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:intl/intl.dart';

enum MessageStatus { sent, delivered, read }

enum MessageType { text, image, file }

class Message {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final MessageStatus status;
  final MessageType type;
  final bool isEdited;
  String? fileUrl;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.status,
    required this.type,
    this.isEdited = false,
    this.fileUrl,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      content: data['content'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MessageStatus.values[data['status'] ?? 0],
      type: MessageType.values[data['type'] ?? 0],
      isEdited: data['isEdited'] ?? false,
      fileUrl: data['fileUrl'],
    );
  }
}

class MessagingScreen extends StatefulWidget {
  final String currentUserId;
  final String recipientId;

  const MessagingScreen({
    super.key,
    required this.currentUserId,
    required this.recipientId,
  });

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Message? _editingMessage;
  Timer? _userActivityTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    if (!mounted) return;

    if (!_validateUserIds()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInvalidUserIdError();
      });
      return;
    }

    try {
      // Verify users exist in Firestore
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      
      final recipientUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.recipientId)
          .get();

      if (!currentUserDoc.exists || !recipientUserDoc.exists) {
        if (mounted) {
          _showInvalidUserIdError();
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _setupUserActivityListener();
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing messaging: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  bool _validateUserIds() {
    // Add additional validation as needed
    return widget.currentUserId.isNotEmpty && 
           widget.recipientId.isNotEmpty && 
           widget.currentUserId != widget.recipientId &&
           widget.currentUserId.length >= 20 && // Typical Firebase ID length
           widget.recipientId.length >= 20;
  }

  void _showInvalidUserIdError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error: Invalid user ID. Please ensure both users exist and IDs are valid.'),
        duration: Duration(seconds: 5),
      ),
    );
    Navigator.of(context).pop();
  }

  void _setupUserActivityListener() {
    if (!_validateUserIds()) return;

    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .update({
            'lastActive': FieldValue.serverTimestamp(),
            'isOnline': true
          });

      _userActivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (_validateUserIds() && mounted) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.currentUserId)
              .update({'lastActive': FieldValue.serverTimestamp()});
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  void _markMessagesAsRead() {
    if (!_validateUserIds()) return;

    try {
      FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: widget.currentUserId)
          .where('senderId', isEqualTo: widget.recipientId)
          .where('status', isLessThan: MessageStatus.read.index)
          .get()
          .then((messages) {
        for (var message in messages.docs) {
          message.reference.update({'status': MessageStatus.read.index});
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking messages as read: $e')),
      );
    }
  }

  Future<void> _sendMessage({String? imageUrl, String? fileUrl}) async {
    if (!mounted || !_validateUserIds()) return;

    String content = _messageController.text.trim();
    if (content.isEmpty && imageUrl == null && fileUrl == null) return;

    try {
      final messageData = {
        'senderId': widget.currentUserId,
        'receiverId': widget.recipientId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'status': MessageStatus.sent.index,
        'type': MessageType.text.index,
        'isEdited': false,
      };

      if (imageUrl != null) {
        messageData['type'] = MessageType.image.index;
        messageData['fileUrl'] = imageUrl;
      } else if (fileUrl != null) {
        messageData['type'] = MessageType.file.index;
        messageData['fileUrl'] = fileUrl;
      }

      await FirebaseFirestore.instance.collection('messages').add(messageData);

      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    if (!_validateUserIds()) return;
    
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('message_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(image.path));
        final imageUrl = await ref.getDownloadURL();

        if (!mounted) return;
        await _sendMessage(imageUrl: imageUrl);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    if (!_validateUserIds()) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File picking not yet implemented')),
    );
  }

  Future<void> _editMessage(Message message) async {
    if (!_validateUserIds() || message.senderId != widget.currentUserId || !mounted) return;

    setState(() {
      _editingMessage = message;
      _messageController.text = message.content;
    });
  }

  Future<void> _updateMessage() async {
    if (_editingMessage == null || !mounted || !_validateUserIds()) return;

    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(_editingMessage!.id)
          .update({
        'content': _messageController.text.trim(),
        'isEdited': true,
      });

      if (!mounted) return;
      setState(() {
        _editingMessage = null;
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating message: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    if (!mounted || !_validateUserIds()) return;

    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageStatus(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == widget.currentUserId;
    final bubbleColor = isMe ? Colors.blue : Colors.grey[300];
    final textColor = isMe ? Colors.white : Colors.black;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.image)
              Image.network(
                message.fileUrl!,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator();
                },
              ),
            if (message.type == MessageType.file)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file),
                  Text('File Attachment', style: TextStyle(color: textColor)),
                ],
              ),
            Text(
              message.content,
              style: TextStyle(color: textColor),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                if (message.isEdited)
                  Text(
                    ' (edited)',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                if (isMe) _buildMessageStatus(message.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Messages'),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.recipientId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final isOnline = userData?['isOnline'] ?? false;
                final lastActive = userData?['lastActive'] as Timestamp?;

                return Text(
                  isOnline
                      ? 'Online'
                      : lastActive != null
                          ? 'Last seen ${DateFormat.yMd().add_jm().format(lastActive.toDate())}'
                          : 'Offline',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('senderId',
                      whereIn: [widget.currentUserId, widget.recipientId])
                  .where('receiverId',
                      whereIn: [widget.currentUserId, widget.recipientId])
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs
                    .map((doc) => Message.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return GestureDetector(
                      onLongPress: () {
                        if (message.senderId == widget.currentUserId) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Message Options'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Edit'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _editMessage(message);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete),
                                    title: const Text('Delete'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _deleteMessage(message.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                      child: _buildMessageBubble(message),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickFile,
                ),
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _editingMessage != null
                          ? 'Edit message...'
                          : 'Type a message...',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: Icon(_editingMessage != null ? Icons.check : Icons.send),
                  onPressed: _editingMessage != null
                      ? _updateMessage
                      : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _userActivityTimer?.cancel();
    if (_validateUserIds()) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .update({
        'isOnline': false,
        'lastActive': FieldValue.serverTimestamp()
      }).catchError((error) {
        // Handle any errors silently in dispose
        debugPrint('Error updating user status on dispose: $error');
      });
    }
    super.dispose();
  }
}