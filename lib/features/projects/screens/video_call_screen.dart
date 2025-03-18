import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

final Logger _logger = Logger('VideoCallScreen');

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String receiverId;
  final String receiverName;
  final bool isInitiator;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.receiverId,
    required this.receiverName,
    required this.isInitiator,
  });

  @override
  VideoCallScreenState createState() => VideoCallScreenState();
}

class VideoCallScreenState extends State<VideoCallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isCallActive = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  String _callState = 'initializing';
  final _database = FirebaseDatabase.instance;
  late DatabaseReference _callRef;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _callRef = _database.ref('calls').child(widget.callId);
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _requestPermissions();
      await _initializeWebRTC();
      if (widget.isInitiator) {
        await _startCall();
      } else {
        await _answerCall();
      }
      _startTimeout();
    } catch (e) {
      _logger.severe('Initialization failed: $e');
      _endCallWithError('Initialization failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final status = await [Permission.camera, Permission.microphone].request();
    if (!status.values.every((s) => s.isGranted)) {
      throw Exception('Camera or microphone permission denied');
    }
  }

  Future<void> _initializeWebRTC() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = _localStream;

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {
          'urls': 'turn:your.turn.server:3478', // Replace with your TURN server
          'username': 'your_username',
          'credential': 'your_password',
        },
      ]
    };

    _peerConnection = await createPeerConnection(configuration);
    _localStream!.getTracks().forEach((track) => _peerConnection!.addTrack(track, _localStream!));

    _peerConnection!.onIceCandidate = (candidate) {
      _sendSignalingMessage('candidate', candidate.toMap());
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isCallActive = true;
          _callState = 'connected';
        });
      }
    };

    _listenForSignaling();
  }

  Future<void> _startCall() async {
    setState(() => _callState = 'ringing');
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _callRef.set({
      'callId': widget.callId,
      'initiator': {
        'accountId': FirebaseAuth.instance.currentUser!.uid,
        'deviceId': FirebaseAuth.instance.currentUser!.uid, // Simplified for this example
      },
      'receiver': {
        'accountId': widget.receiverId,
        'deviceId': widget.receiverId, // Simplified
      },
      'status': 'ringing',
    });
    _sendSignalingMessage('offer', offer.toMap());
  }

  Future<void> _answerCall() async {
    setState(() => _callState = 'answering');
    _callRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && data['status'] == 'ringing' && !_isCallActive) {
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        await _callRef.update({'status': 'answered'});
        _sendSignalingMessage('answer', answer.toMap());
        setState(() => _isCallActive = true);
      }
    });
  }

  void _listenForSignaling() {
    _callRef.child('signaling').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map;
      final type = data['type'];
      final senderDeviceId = data['senderDeviceId'];

      if (senderDeviceId != FirebaseAuth.instance.currentUser!.uid) {
        switch (type) {
          case 'offer':
            _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
            break;
          case 'answer':
            _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
            setState(() => _callState = 'connected');
            break;
          case 'candidate':
            _peerConnection!.addCandidate(
              RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
            );
            break;
        }
      }
    });
  }

  void _sendSignalingMessage(String type, Map<String, dynamic> data) {
    _callRef.child('signaling').push().set({
      'type': type,
      'senderDeviceId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': ServerValue.timestamp,
      ...data,
    });
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_isCallActive) {
        _endCallWithError('Call timed out');
      }
    });
  }

  void _toggleMic() {
    if (_localStream != null) {
      setState(() {
        _isMicOn = !_isMicOn;
        _localStream!.getAudioTracks().forEach((track) => track.enabled = _isMicOn);
      });
    }
  }

  void _toggleCamera() {
    if (_localStream != null) {
      setState(() {
        _isCameraOn = !_isCameraOn;
        _localStream!.getVideoTracks().forEach((track) => track.enabled = _isCameraOn);
      });
    }
  }

  void _endCall() {
    _peerConnection?.close();
    _localStream?.dispose();
    _callRef.update({'status': 'ended'});
    _timeoutTimer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  void _endCallWithError(String error) {
    _logger.severe(error);
    _showSnackBar(error);
    _endCall();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(_remoteRenderer, mirror: false),
          ),
          Positioned(
            top: 20,
            right: 20,
            width: 100,
            height: 150,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
                  onPressed: _toggleMic,
                  color: Colors.white,
                ),
                IconButton(
                  icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off),
                  onPressed: _toggleCamera,
                  color: Colors.white,
                ),
                IconButton(
                  icon: const Icon(Icons.call_end),
                  onPressed: _endCall,
                  color: Colors.red,
                ),
              ],
            ),
          ),
          if (!_isCallActive)
            Center(child: Text(_callState, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}