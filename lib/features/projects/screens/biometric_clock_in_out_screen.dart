import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class BiometricClockInOutScreen extends StatefulWidget {
  const BiometricClockInOutScreen({super.key});

  @override
  BiometricClockInOutScreenState createState() => BiometricClockInOutScreenState();
}

class BiometricClockInOutScreenState extends State<BiometricClockInOutScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isClockedIn = false;
  String? _lastClockInTime;
  String? _lastClockOutTime;
  bool _isAuthenticating = false;
  bool _canUseBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _checkClockInStatus();
    _setupRealtimeUpdates();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      _canUseBiometrics = await auth.canCheckBiometrics;
      if (_canUseBiometrics) {
        _availableBiometrics = await auth.getAvailableBiometrics();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _handleError('Error checking biometric support', e);
    }
  }

  void _setupRealtimeUpdates() {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      _database.child('users/${user.uid}/clock_in_status').onValue.listen(
        (event) {
          if (event.snapshot.value != null && mounted) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            setState(() {
              _isClockedIn = data['is_clocked_in'] ?? false;
              _lastClockInTime = data['last_clock_in_time'];
              _lastClockOutTime = data['last_clock_out_time'];
            });
          }
        },
        onError: (error) => _handleError('Realtime update error', error),
      );
    }
  }

  Future<void> _checkClockInStatus() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final snapshot = await _database.child('users/${user.uid}/clock_in_status').get();
        if (mounted && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _isClockedIn = data['is_clocked_in'] ?? false;
            _lastClockInTime = data['last_clock_in_time'];
            _lastClockOutTime = data['last_clock_out_time'];
          });
        }
      }
    } catch (e) {
      _handleError('Error checking clock-in status', e);
    }
  }

  Future<void> _authenticateAndClockInOut() async {
    if (!_canUseBiometrics || _availableBiometrics.isEmpty) {
      _showMessage('Biometric authentication is not available on this device');
      return;
    }

    try {
      setState(() => _isAuthenticating = true);

      bool authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to ${_isClockedIn ? 'clock out' : 'clock in'}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated && mounted) {
        await _toggleClockInOut();
      }
    } catch (e) {
      _handleError('Authentication error', e);
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _toggleClockInOut() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      _showMessage('Please sign in to use this feature');
      return;
    }

    try {
      final now = DateTime.now();
      final currentTime = now.toIso8601String();
      
      // Check if user has already clocked in/out in the last minute
      if (_lastClockInTime != null) {
        final lastAction = DateTime.parse(_isClockedIn ? _lastClockInTime! : _lastClockOutTime ?? _lastClockInTime!);
        if (now.difference(lastAction).inMinutes < 1) {
          _showMessage('Please wait a minute before your next clock-in/out');
          return;
        }
      }

      await _database.child('users/${user.uid}/clock_in_status').set({
        'is_clocked_in': !_isClockedIn,
        'last_clock_in_time': !_isClockedIn ? currentTime : _lastClockInTime,
        'last_clock_out_time': _isClockedIn ? currentTime : _lastClockOutTime,
        'updated_at': currentTime,
      });

      // Log the attendance record
      await _database.child('users/${user.uid}/attendance_log').push().set({
        'action': _isClockedIn ? 'clock_out' : 'clock_in',
        'timestamp': currentTime,
        'location': 'Office', // You can add actual location tracking here
      });

      _showMessage(_isClockedIn ? 'Successfully clocked out' : 'Successfully clocked in');
    } catch (e) {
      _handleError('Error updating clock-in status', e);
    }
  }

  void _handleError(String prefix, dynamic error) {
    if (mounted) {
      _showMessage('$prefix: ${error.toString()}');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Not available';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Clock-In/Out'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        _isClockedIn ? Icons.check_circle : Icons.access_time,
                        size: 48,
                        color: _isClockedIn ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isClockedIn ? 'Currently Clocked In' : 'Currently Clocked Out',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isClockedIn ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Activity:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Clock-In: ${_formatDateTime(_lastClockInTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_lastClockOutTime != null)
                        Text(
                          'Last Clock-Out: ${_formatDateTime(_lastClockOutTime)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_canUseBiometrics)
                const Text(
                  'Biometric authentication is not available on this device',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ElevatedButton.icon(
                onPressed: _isAuthenticating || !_canUseBiometrics
                    ? null
                    : _authenticateAndClockInOut,
                icon: Icon(_isClockedIn ? Icons.logout : Icons.login),
                label: Text(_isClockedIn ? 'Clock Out' : 'Clock In'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  backgroundColor: _isClockedIn ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_isAuthenticating)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up any subscriptions or controllers here
    super.dispose();
  }
}