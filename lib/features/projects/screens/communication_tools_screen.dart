import 'package:build_masterpro/features/projects/screens/voice_call_screen.dart';
import 'package:flutter/material.dart';
import 'messaging_screen.dart';
import 'video_call_screen.dart';
import 'file_sharing_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class CommunicationToolsScreen extends StatelessWidget {
  const CommunicationToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user's ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication Tools'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Choose a Communication Method'),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCommunicationCard(
                    context, 
                    'Messaging', 
                    Icons.message,
                    Colors.blue, 
                    // Prompt user to select a recipient before navigating
                    MessagingSetupScreen(currentUserId: currentUserId)
                  ),
                  _buildCommunicationCard(
                    context,
                    'Voice Calls',
                    Icons.call,
                    Colors.green,
                    const VoiceCallScreen()
                  ),
                  _buildCommunicationCard(
                    context, 
                    'Video Calls',
                    Icons.videocam, 
                    Colors.orange, 
                    VideoCallScreen(
                      accountId: currentUserId, 
                      deviceId: '', // You might want to implement device ID generation
                    )
                  ),
                  _buildCommunicationCard(
                    context, 
                    'File Sharing', 
                    Icons.share,
                    Colors.red, 
                    const FileSharingScreen()
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _buildCommunicationCard(BuildContext context, String title,
      IconData icon, Color color, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New screen to handle recipient selection
class MessagingSetupScreen extends StatefulWidget {
  final String currentUserId;

  const MessagingSetupScreen({super.key, required this.currentUserId});

  @override
  MessagingSetupScreenState createState() => MessagingSetupScreenState();
}

class MessagingSetupScreenState extends State<MessagingSetupScreen> {
  List<Map<String, String>> _availableUsers = []; // Populate this with actual users

  @override
  void initState() {
    super.initState();
    _fetchAvailableUsers();
  }

  Future<void> _fetchAvailableUsers() async {
    // Implement user fetching logic here
    // This is a placeholder - replace with actual Firebase/database logic
    setState(() {
      _availableUsers = [
        {'id': 'user1', 'name': 'John Doe'},
        {'id': 'user2', 'name': 'Jane Smith'},
        // Add more users dynamically
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Recipient'),
      ),
      body: ListView.builder(
        itemCount: _availableUsers.length,
        itemBuilder: (context, index) {
          final user = _availableUsers[index];
          return ListTile(
            title: Text(user['name'] ?? ''),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagingScreen(
                    currentUserId: widget.currentUserId, 
                    recipientId: user['id'] ?? '',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}