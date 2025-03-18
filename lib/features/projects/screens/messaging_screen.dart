import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  MessagingScreenState createState() => MessagingScreenState();
}

class MessagingScreenState extends State<MessagingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send a message')),
        );
      }
      return;
    }

    try {
      await _firestore.collection('messages').add({
        'text': _messageController.text.trim(),
        'userId': user.uid,
        'email': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Add user profile or settings navigation here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }

                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index].data() as Map<String, dynamic>;
                      final isCurrentUser = data['userId'] == user?.uid;
                      return Card(
                        color: isCurrentUser ? Colors.blue[700] : Colors.grey[700],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          title: Align(
                            alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Text(
                              data['text'],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          subtitle: Text(
                            data['email'] ?? 'Unknown',
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: isCurrentUser
                              ? const Icon(Icons.done_all, color: Colors.white70, size: 16)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}