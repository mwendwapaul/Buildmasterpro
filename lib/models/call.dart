class Contact {
  final String name;
  final String phoneNumber;
  final String? avatarUrl;

  Contact({required this.name, required this.phoneNumber, this.avatarUrl});
}

class CallLog {
  final Contact contact;
  final DateTime timestamp;
  final CallType callType;
  final Duration duration;

  CallLog({
    required this.contact,
    required this.timestamp,
    required this.callType,
    required this.duration,
  });
}

enum CallType { incoming, outgoing, missed }
