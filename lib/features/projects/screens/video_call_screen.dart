import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class VideoCallScreen extends StatefulWidget {
  final String accountId;
  final String deviceId;

  const VideoCallScreen({
    super.key,
    required this.accountId,
    required this.deviceId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _database = FirebaseDatabase.instance.ref();
  final _uuid = const Uuid();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  String? _currentCallId;
  Timer? _callTimer;
  int _callDuration = 0;
  DateTime? _callStartTime;
  
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _isInCall = false;
  bool _isFrontCamera = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCalls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
      default:
        break;
    }
  }

  void _handleAppBackground() {
    if (_isInCall) {
      _toggleCamera();  // Turn off camera to save battery
    }
  }

  void _handleAppForeground() {
    if (_isInCall && !_isCameraOn) {
      _toggleCamera();  // Resume camera if we were in a call
    }
  }

  Future<void> _initializeCalls() async {
    setState(() => _isInitializing = true);
    try {
      await _initRenderers();
      _listenForIncomingCalls();
    } catch (e) {
      _showError("Initialization failed: $e");
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    } catch (e) {
      _showError("Failed to initialize renderers: $e");
    }
  }

  Future<void> _setupLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        }
      });
      
      setState(() {
        _localRenderer.srcObject = _localStream;
      });
    } catch (e) {
      _showError("Cannot access camera/microphone: $e");
      rethrow;
    }
  }

  Future<void> _initializePeerConnection({bool isInitiator = true}) async {
    try {
      if (_localStream == null) {
        await _setupLocalStream();
      }

      final configuration = {
        "iceServers": [
          {"urls": "stun:stun.l.google.com:19302"},
          {
            "urls": "turn:your-turn-server.com:3478",  // Add your TURN server
            "username": "username",
            "credential": "password"
          }
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      _peerConnection?.onIceCandidate = (candidate) {
        _sendIceCandidate(candidate);
      };

      _peerConnection?.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      };

      _peerConnection?.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _showError("Connection failed. Attempting to reconnect...");
          _retryConnection();
        }
      };

      if (isInitiator) {
        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true
        });
        await _peerConnection!.setLocalDescription(offer);
        _sendOffer(offer);
      }

      setState(() {
        _isInCall = true;
        _callStartTime = DateTime.now();
      });

      _startCallTimer();
    } catch (e) {
      _showError("Connection failed: $e");
      rethrow;
    }
  }

  Future<void> _retryConnection() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
    await _initializePeerConnection();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
        });
      }
    });
  }

  Future<void> _makeCall(String targetDeviceId) async {
    setState(() => _isInitializing = true);
    try {
      _currentCallId = _uuid.v4();
      await _initializePeerConnection();

      await _database
          .child("accounts/${widget.accountId}/devices/$targetDeviceId/calls")
          .child(_currentCallId!)
          .set({
        'callId': _currentCallId,
        'initiatorDeviceId': widget.deviceId,
        'timestamp': ServerValue.timestamp,
      });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendOffer(RTCSessionDescription offer) async {
    try {
      await _database
          .child("accounts/${widget.accountId}/calls/$_currentCallId/offer")
          .set({
        "sdp": offer.sdp,
        "type": offer.type,
      });
    } catch (e) {
      _showError("Failed to send offer: $e");
      rethrow;
    }
  }

  Future<void> _sendAnswer(RTCSessionDescription answer) async {
    try {
      await _database
          .child("accounts/${widget.accountId}/calls/$_currentCallId/answer")
          .set({
        "sdp": answer.sdp,
        "type": answer.type,
      });
    } catch (e) {
      _showError("Failed to send answer: $e");
      rethrow;
    }
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _database
          .child("accounts/${widget.accountId}/calls/$_currentCallId/candidates")
          .push()
          .set({
        "candidate": candidate.candidate,
        "sdpMid": candidate.sdpMid,
        "sdpMlineIndex": candidate.sdpMLineIndex,
      });
    } catch (e) {
      _showError("Failed to send ICE candidate: $e");
    }
  }

  void _listenForIncomingCalls() {
    _database
        .child("accounts/${widget.accountId}/devices/${widget.deviceId}/calls")
        .onChildAdded
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && !_isInCall) {
        _currentCallId = data['callId'];
        _showIncomingCallDialog(data['initiatorDeviceId']);
      }
    });

    _database.child("accounts/${widget.accountId}/calls").onChildAdded.listen(
        (event) async {
      if (_currentCallId != null && event.snapshot.key == _currentCallId) {
        final data = event.snapshot.value as Map?;
        if (data?['answer'] != null && _peerConnection != null) {
          final answer = RTCSessionDescription(
            data?['answer']['sdp'],
            data?['answer']['type'],
          );
          await _peerConnection!.setRemoteDescription(answer);
        }
      }
    });

    _database
        .child("accounts/${widget.accountId}/calls/$_currentCallId/candidates")
        .onChildAdded
        .listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && _peerConnection != null) {
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMlineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  void _showIncomingCallDialog(String callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Incoming Call",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "Device: $callerId",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(
                onPressed: () {
                  Navigator.pop(context);
                  _rejectCall();
                },
                icon: Icons.call_end,
                color: Colors.red,
                label: "Decline",
              ),
              _buildCallButton(
                onPressed: () {
                  Navigator.pop(context);
                  _acceptCall();
                },
                icon: Icons.call,
                color: Colors.green,
                label: "Accept",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptCall() async {
    setState(() => _isInitializing = true);
    try {
      await _initializePeerConnection(isInitiator: false);

      final offerSnapshot = await _database
          .child("accounts/${widget.accountId}/calls/$_currentCallId/offer")
          .get();

      if (offerSnapshot.value != null) {
        final offerData = offerSnapshot.value as Map;
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(offerData['sdp'], offerData['type']),
        );

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        await _sendAnswer(answer);
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _rejectCall() async {
    await _database
        .child(
            "accounts/${widget.accountId}/devices/${widget.deviceId}/calls/$_currentCallId")
        .remove();
    _currentCallId = null;
  }

  void _toggleCamera() {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      setState(() {
        _isCameraOn = !_isCameraOn;
        videoTrack.enabled = _isCameraOn;
      });
    }
  }

  void _switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      await Helper.switchCamera(videoTrack);
      setState(() => _isFrontCamera = !_isFrontCamera);
    }
  }

  void _toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!
          .getAudioTracks()
          .firstWhere((track) => track.kind == 'audio');
      setState(() {
        _isMicOn = !_isMicOn;
        audioTrack.enabled = _isMicOn;
      });
    }
  }

  Future<void> _endCall() async {
    setState(() => _isInitializing = true);
    try {
      _callTimer?.cancel();
      _localStream?.getTracks().forEach((track) => track.stop());
      await _peerConnection?.close();
      
      await _database
          .child("accounts/${widget.accountId}/calls/$_currentCallId")
          .remove();

      setState(() {
        _isInCall = false;
        _callDuration = 0;
        _currentCallId = null;
        _callStartTime = null;
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showDeviceList() async {
    try {
      final devicesSnapshot =
          await _database.child("accounts/${widget.accountId}/devices").get();

      if (!mounted) return;

      if (devicesSnapshot.value != null) {
        final devices = (devicesSnapshot.value as Map).keys.toList()
          ..remove(widget.deviceId);

        if (devices.isEmpty) {
          _showError('No other devices available');
          return;
        }

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Device to Call',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.devices),
                      ),
                      title: Text('Device ${devices[index]}'),
                      trailing: const Icon(Icons.call),
                      onTap: () {
                        Navigator.pop(context);
                        _makeCall(devices[index]);
                      },
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showError('No other devices found');
      }
    } catch (e) {
      _showError('Failed to load devices: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isInCall ? _buildCallUI() : _buildInitialUI(),
          if (_isInitializing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallUI() {
    return Stack(
      children: [
        // Remote Video (Full Screen)
        Positioned.fill(
          child: RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _endCall,
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.switch_camera, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Local Video (Picture in Picture)
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 80,
          width: 120,
          height: 160,
          child: GestureDetector(
            onTap: _toggleCamera,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  _localRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: _isFrontCamera,
                ),
              ),
            ),
          ),
        ),
        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.only(bottom: 48, top: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    onPressed: _toggleMicrophone,
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    color: _isMicOn ? Colors.white : Colors.red,
                    label: _isMicOn ? 'Mute' : 'Unmute',
                  ),
                  _buildControlButton(
                    onPressed: _endCall,
                    icon: Icons.call_end,
                    color: Colors.red,
                    size: 70,
                    label: 'End',
                  ),
                  _buildControlButton(
                    onPressed: _toggleCamera,
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: _isCameraOn ? Colors.white : Colors.red,
                    label: _isCameraOn ? 'Stop Video' : 'Start Video',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    double size = 60,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                color == Colors.white ? Colors.white.withOpacity(0.2) : color,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: size * 0.5),
            padding: EdgeInsets.zero,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInitialUI() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade900,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_call,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Start a Video Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton(
                onPressed: _showDeviceList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call),
                    SizedBox(width: 8),
                    Text(
                      'Select Device to Call',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
