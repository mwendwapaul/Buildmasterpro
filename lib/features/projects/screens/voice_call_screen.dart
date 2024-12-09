
import 'dart:async';

import 'package:build_masterpro/models/call.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CallLogsTab(),
    const ContactsTab(),
    const DialPadTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Dial'),
        ],
      ),
    );
  }
}

// Call Logs Tab
class CallLogsTab extends StatefulWidget {
  const CallLogsTab({super.key});

  @override
  State<CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends State<CallLogsTab> {
  final List<CallLog> _callLogs = [
    CallLog(
      contact: Contact(name: 'John Doe', phoneNumber: '+1234567890'),
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      callType: CallType.incoming,
      duration: const Duration(minutes: 5),
    ),
    // Add more sample call logs as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _callLogs.length,
        itemBuilder: (context, index) {
          final log = _callLogs[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(log.contact.name[0]),
            ),
            title: Text(log.contact.name),
            subtitle: Row(
              children: [
                Icon(
                  _getCallTypeIcon(log.callType),
                  size: 16,
                  color: _getCallTypeColor(log.callType),
                ),
                const SizedBox(width: 4),
                Text(DateFormat('MMM d, h:mm a').format(log.timestamp)),
              ],
            ),
            trailing: Text('${log.duration.inMinutes}m'),
            onTap: () => _startCall(context, log.contact),
          );
        },
      ),
    );
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
    }
  }
}

// Contacts Tab
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final List<Contact> _contacts = [
    Contact(name: 'John Doe', phoneNumber: '+1234567890'),
    Contact(name: 'Jane Smith', phoneNumber: '+0987654321'),
    // Add more sample contacts
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(contact.name[0]),
            ),
            title: Text(contact.name),
            subtitle: Text(contact.phoneNumber),
            trailing: IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _startCall(context, contact),
            ),
          );
        },
      ),
    );
  }
}

// Dial Pad Tab
class DialPadTab extends StatefulWidget {
  const DialPadTab({super.key});

  @override
  State<DialPadTab> createState() => _DialPadTabState();
}

class _DialPadTabState extends State<DialPadTab> {
  final TextEditingController _numberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dial Pad')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _numberController,
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
              ),
              keyboardType: TextInputType.none,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              children: [
                for (var i = 1; i <= 9; i++) _buildDialButton(i.toString()),
                _buildDialButton('*'),
                _buildDialButton('0'),
                _buildDialButton('#'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: () {
                if (_numberController.text.isNotEmpty) {
                  _startCall(
                    context,
                    Contact(
                      name: 'Unknown',
                      phoneNumber: _numberController.text,
                    ),
                  );
                }
              },
              child: const Icon(Icons.call),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialButton(String number) {
    return InkWell(
      onTap: () {
        setState(() {
          _numberController.text += number;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

// Active Call Screen
class ActiveCallScreen extends StatefulWidget {
  final Contact contact;

  const ActiveCallScreen({super.key, required this.contact});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Duration _callDuration = Duration.zero;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    child: Text(
                      widget.contact.name[0],
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.contact.name,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.contact.phoneNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallButton(
                    icon: Icons.mic_off,
                    isActive: _isMuted,
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: () => Navigator.pop(context),
                  ),
                  _buildCallButton(
                    icon: Icons.volume_up,
                    isActive: _isSpeakerOn,
                    onPressed: () =>
                        setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    Color color = Colors.white,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return FloatingActionButton(
      backgroundColor: isActive ? Colors.blue : color,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${hours == '00' ? '' : '$hours:'}$minutes:$seconds";
  }
}

// Helper function to start a call
void _startCall(BuildContext context, Contact contact) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ActiveCallScreen(contact: contact),
    ),
  );
}
