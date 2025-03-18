import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class BiometricClockInOutScreen extends StatefulWidget {
  const BiometricClockInOutScreen({super.key});

  @override
  BiometricClockInOutScreenState createState() => BiometricClockInOutScreenState();
}

class BiometricClockInOutScreenState extends State<BiometricClockInOutScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  bool _isClockedIn = false;
  String? _lastClockInTime;
  String? _lastClockOutTime;
  bool _isAuthenticating = false;
  bool _canUseBiometrics = false;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _biometricEnrollmentInProgress = false;
  String _biometricStatus = 'Not checked';
  List<BiometricType> _availableBiometrics = [];
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await _requestLocationPermissions();
      await _checkBiometricSupport();
      await _getCurrentLocation();
      if (_firebaseAuth.currentUser != null) {
        await _checkClockInStatus();
        _setupRealtimeUpdates();
      }
    } catch (e) {
      _handleError('Initialization error', e);
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
      ].request();

      if (!statuses[Permission.location]!.isGranted) {
        throw Exception('Location permission denied');
      }
    } catch (e) {
      _handleError('Location permission error', e);
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      
      setState(() {
        _canUseBiometrics = canCheckBiometrics && isDeviceSupported;
        _biometricStatus = _canUseBiometrics ? 'Supported' : 'Not supported';
      });
      
      if (_canUseBiometrics) {
        _availableBiometrics = await _auth.getAvailableBiometrics();
        
        if (_availableBiometrics.isEmpty) {
          setState(() {
            _biometricStatus = 'No biometrics enrolled';
          });
        } else {
          setState(() {
            _biometricStatus = 'Available biometrics: ${_availableBiometrics.join(", ")}';
            _canUseBiometrics = _availableBiometrics.contains(BiometricType.fingerprint) || 
                               _availableBiometrics.contains(BiometricType.strong) ||
                               _availableBiometrics.contains(BiometricType.face);
          });
        }
      }
    } catch (e) {
      _handleError('Biometric support check failed', e);
      setState(() {
        _canUseBiometrics = false;
        _biometricStatus = 'Error checking biometrics: ${e.toString()}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services disabled';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permission denied';
      }
      if (permission == LocationPermission.deniedForever) throw 'Location permission permanently denied';

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _handleError('Location error', e);
    }
  }

  void _setupRealtimeUpdates() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    _statusSubscription?.cancel();
    _statusSubscription = _usersCollection.doc(user.uid).snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final clockInStatus = data['clock_in_status'] as Map<String, dynamic>?;
          if (clockInStatus != null) {
            setState(() {
              _isClockedIn = clockInStatus['is_clocked_in'] ?? false;
              _lastClockInTime = clockInStatus['last_clock_in_time'];
              _lastClockOutTime = clockInStatus['last_clock_out_time'];
            });
          }
        }
      },
      onError: (error) => _handleError('Realtime update error', error),
    );
  }

  Future<void> _checkClockInStatus() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final clockInStatus = data['clock_in_status'] as Map<String, dynamic>?;
        if (clockInStatus != null && mounted) {
          setState(() {
            _isClockedIn = clockInStatus['is_clocked_in'] ?? false;
            _lastClockInTime = clockInStatus['last_clock_in_time'];
            _lastClockOutTime = clockInStatus['last_clock_out_time'];
          });
        }
      } else {
        await _usersCollection.doc(user.uid).set({
          'clock_in_status': {
            'is_clocked_in': false,
            'updated_at': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _handleError('Clock-in status check failed', e);
    }
  }

  Future<void> _enrollBiometrics() async {
    setState(() => _biometricEnrollmentInProgress = true);
    
    try {
      // First, check if the device supports biometrics
      bool isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported) {
        _showMessage('Your device does not support biometric authentication');
        return;
      }
      
      // Try to authenticate to prompt system enrollment
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Enroll your fingerprint for clock in/out',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      
      if (authenticated) {
        _showMessage('Biometric enrollment successful!');
        await _checkBiometricSupport(); // Refresh biometric status
      } else {
        _showMessage('Biometric enrollment canceled or failed');
      }
    } catch (e) {
      if (e.toString().contains('NotEnrolled')) {
        _showGuideToEnroll();
      } else {
        _handleError('Biometric enrollment error', e);
      }
    } finally {
      if (mounted) setState(() => _biometricEnrollmentInProgress = false);
    }
  }

  void _showGuideToEnroll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fingerprint Enrollment Guide'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'You need to enroll a fingerprint in your device settings. Follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...[
                'Open your device Settings',
                'Select Security or Biometrics and Security',
                'Tap on Fingerprint or Biometrics',
                'Follow the on-screen instructions to add your fingerprint',
                'Return to this app after enrollment',
              ].map((step) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(step)),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Text(
                'After enrollment, tap the "Check Again" button to verify your fingerprint is ready.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticateAndClockInOut() async {
    if (!_canUseBiometrics) {
      _showMessage('Fingerprint authentication is not available. Please enroll a fingerprint first.');
      return;
    }

    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        _showMessage('Please sign in first');
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Use your fingerprint to ${_isClockedIn ? 'clock out' : 'clock in'}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (authenticated && mounted) {
        await _toggleClockInOut();
      } else if (mounted) {
        _showMessage('Fingerprint authentication failed');
      }
    } catch (e) {
      _handleError('Authentication error', e);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _toggleClockInOut() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        _showMessage('Unable to get location. Please try again.');
        return;
      }

      final now = DateTime.now();
      final currentTime = now.toIso8601String();

      if (_lastClockInTime != null && _isClockedIn) {
        final lastClockIn = DateTime.parse(_lastClockInTime!);
        if (now.difference(lastClockIn).inSeconds < 30) {
          _showMessage('Please wait 30 seconds before clocking out');
          return;
        }
      }

      await _usersCollection.doc(user.uid).set({
        'clock_in_status': {
          'is_clocked_in': !_isClockedIn,
          'last_clock_in_time': !_isClockedIn ? currentTime : _lastClockInTime,
          'last_clock_out_time': _isClockedIn ? currentTime : _lastClockOutTime,
          'updated_at': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      await _usersCollection.doc(user.uid).collection('attendance_log').doc(now.millisecondsSinceEpoch.toString()).set({
        'action': _isClockedIn ? 'clock_out' : 'clock_in',
        'timestamp': currentTime,
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        },
        'user_id': user.uid,
      });

      if (mounted) {
        setState(() {
          _isClockedIn = !_isClockedIn;
          if (_isClockedIn) {
            _lastClockInTime = currentTime;
          } else {
            _lastClockOutTime = currentTime;
          }
        });
        _showMessage(_isClockedIn ? 'Successfully clocked in' : 'Successfully clocked out');
      }
    } catch (e) {
      _handleError('Clock in/out failed', e);
    }
  }

  void _handleError(String prefix, dynamic error) {
    if (mounted) {
      _showMessage('$prefix: ${error.toString()}');
      debugPrint('$prefix: $error');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: message.contains('failed') || message.contains('error') 
              ? Colors.red 
              : Colors.green,
        ),
      );
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Never';
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
        title: const Text('Fingerprint Clock-In/Out'),
        centerTitle: true,
        elevation: 2,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Refresh biometric status',
          ),
        ],
      ),
      body: SafeArea(
        child: !_isInitialized || _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_firebaseAuth.currentUser == null)
                        Card(
                          elevation: 3,
                          color: Colors.red.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Please sign in to use this feature',
                                  style: TextStyle(color: Colors.red, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_canUseBiometrics && _firebaseAuth.currentUser != null)
                        Card(
                          elevation: 3,
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Icon(Icons.fingerprint, color: Colors.orange, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Fingerprint authentication is required',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: $_biometricStatus',
                                  style: const TextStyle(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                _biometricEnrollmentInProgress
                                    ? const CircularProgressIndicator(color: Colors.orange)
                                    : ElevatedButton.icon(
                                        onPressed: _enrollBiometrics,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Enroll Fingerprint'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _checkBiometricSupport,
                                  child: const Text('Check Again'),
                                )
                              ],
                            ),
                          ),
                        ),
                      if (_firebaseAuth.currentUser != null && _canUseBiometrics) ...[
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Icon(
                                  _isClockedIn ? Icons.check_circle : Icons.timer_off,
                                  size: 48,
                                  color: _isClockedIn ? Colors.green : Colors.grey,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Activity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.login, size: 20, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Last Clock-In: ${_formatDateTime(_lastClockInTime)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.logout, size: 20, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Last Clock-Out: ${_formatDateTime(_lastClockOutTime)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isAuthenticating ? null : _authenticateAndClockInOut,
                          icon: _isAuthenticating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(_isClockedIn ? Icons.logout : Icons.login),
                          label: Text(_isClockedIn ? 'Clock Out' : 'Clock In'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            backgroundColor: _isClockedIn ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Using Fingerprint authentication',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}