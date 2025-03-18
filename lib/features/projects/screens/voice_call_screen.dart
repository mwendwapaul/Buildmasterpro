import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'dart:io';

const String appId = '0061a4a796f748ecbc8fe0eeadddec53';
const String temporaryToken = '007eJxTYPh4xOTR+68/Hbni1zotXcwUMfXSDEk2rhn8rc2XO+Ze1b2vwGBgYGaYaJJobmmWZm5ikZqclGyRlmqQmpqYkpKSmmxq7Lz/enpDICND/6o3DIxQCOLzMTiVZuak+CYWl6QWBRTlMzAAAFg9Ji8='; 
final Logger _logger = Logger('VoiceCallScreen');

class VoiceCallScreen extends StatefulWidget {
  final String number;
  final String contactName;
  final String channelName;

  const VoiceCallScreen({
    super.key,
    this.number = '',
    this.contactName = '',
    this.channelName = '',
  });

  @override
  VoiceCallScreenState createState() => VoiceCallScreenState();
}

class VoiceCallScreenState extends State<VoiceCallScreen> {
  String _mode = 'dialer';
  final TextEditingController _numberController = TextEditingController();
  String _contactName = 'Unknown';
  String _channelName = '';
  String _callState = 'disconnected';
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  int _callDuration = 0;
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initialize();
  }

  void _initializeControllers() {
    if (widget.number.isNotEmpty) {
      _numberController.text = widget.number;
    }
    if (widget.contactName.isNotEmpty) {
      _contactName = widget.contactName;
    }
    if (widget.channelName.isNotEmpty) {
      _channelName = widget.channelName;
      _mode = 'call';
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _numberController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _fetchToken(String channelName, int uid) async {
    return temporaryToken;
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection. Please check your network.');
      }
      await _requestPermissions();
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _registerEventHandlers();
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      if (widget.channelName.isNotEmpty) {
        await _joinChannel();
      }
    } catch (e) {
      _handleError('Initialization failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
    ].request();

    if (!statuses[Permission.microphone]!.isGranted) {
      throw Exception('Microphone permission denied. Please grant permission to proceed.');
    }
  }

  void _registerEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _logger.info('Local user joined: ${connection.localUid}');
          setState(() {
            _localUserJoined = true;
            _callState = 'connected';
            _startCallTimer();
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _logger.info('Remote user joined: $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
            _callState = 'connected';
            if (!_localUserJoined) _startCallTimer();
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          _logger.info('Remote user left: $remoteUid, reason: $reason');
          setState(() => _remoteUid = null);
          _endCallWithMessage('Call ended: Other user disconnected');
        },
        onError: (err, msg) => _handleError('Call error: $msg'),
        onConnectionStateChanged: (connection, state, reason) {
          _logger.info('Connection state changed: $state, reason: $reason');
          if (state == ConnectionStateType.connectionStateFailed) {
            _handleError('Connection failed: $reason');
          }
        },
        onTokenPrivilegeWillExpire: (connection, token) async {
          _logger.info('Token will expire soon, renewing...');
          try {
            final newToken = await _fetchToken(_channelName, 0);
            await _engine!.renewToken(newToken);
            _logger.info('Token renewed successfully');
          } catch (e) {
            _handleError('Failed to renew token: $e');
          }
        },
      ),
    );
  }

  Future<void> _joinChannel() async {
    if (_engine == null || !mounted) return;

    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      _handleError('No internet connection. Please check your network.');
      return;
    }

    setState(() {
      _callState = 'connecting';
      _isLoading = true;
    });
    try {
      final token = await _fetchToken(_channelName, 0);
      _logger.info('Joining channel: $_channelName with token: $token');
      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      _handleError('Failed to join call: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleError(String error) {
    _logger.severe(error);
    String userFriendlyMessage = error;
    if (error.contains('connectionChangedInvalidToken')) {
      userFriendlyMessage = 'Failed to connect: Invalid or expired token. Please try again.';
    } else if (error.contains('No internet connection')) {
      userFriendlyMessage = 'No internet connection. Please check your network and try again.';
    }
    setState(() {
      _errorMessage = userFriendlyMessage;
      _callState = 'error';
    });
    _showSnackBar(userFriendlyMessage);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      } else {
        timer.cancel();
      }
    });
  }

  void _endCall() => _endCallWithMessage(null);

  void _endCallWithMessage(String? message) {
    if (!mounted) return;

    setState(() {
      _mode = 'dialer';
      _callState = 'disconnected';
      _callTimer?.cancel();
      _remoteUid = null;
      _numberController.clear();
      _contactName = 'Unknown';
      _channelName = '';
      _callDuration = 0;
      _isMuted = false;
      _isSpeakerOn = false;
    });

    _engine?.leaveChannel();
    if (message != null) _showSnackBar(message);
  }

  void _toggleMute() {
    if (_engine != null && mounted) {
      setState(() {
        _isMuted = !_isMuted;
        _engine!.muteLocalAudioStream(_isMuted);
      });
    }
  }

  void _toggleSpeaker() {
    if (_engine != null && mounted) {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
        _engine!.setEnableSpeakerphone(_isSpeakerOn);
      });
    }
  }

  String _getCallStatus() {
    return switch (_callState) {
      'connecting' => 'Connecting...',
      'connected' => _remoteUid != null ? 'Connected' : 'Waiting for user...',
      'error' => 'Call Failed',
      _ => 'Disconnected',
    };
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _makeCall() {
    if (_numberController.text.isEmpty) {
      _showSnackBar('Please enter a phone number');
      return;
    }

    setState(() {
      _contactName = _numberController.text;
      _channelName = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _mode = 'call';
    });
    _joinChannel();
  }

  Widget _buildDialer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Voice Call',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.grey[800],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _makeCall,
            icon: const Icon(Icons.call, size: 24),
            label: const Text('Call', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recents & Contacts',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: const [
                      Tab(text: 'Recents'),
                      Tab(text: 'Contacts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) => ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.call)),
                            title: Text('Recent Call $index', style: TextStyle(color: Colors.white)),
                            subtitle: Text('Yesterday', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) => ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('Contact $index', style: TextStyle(color: Colors.white)),
                            subtitle: Text('+1 234 567 890', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    if (_isLoading && !_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return switch (_callState) {
      'connecting' => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _endCall,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('End Call', style: TextStyle(fontSize: 18)),
          ),
        ),
      'connected' => Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[800],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CallButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: 'Mute',
                onPressed: _toggleMute,
                isActive: _isMuted,
              ),
              CallButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                label: 'Speaker',
                onPressed: _toggleSpeaker,
                isActive: _isSpeakerOn,
              ),
              CallButton(
                icon: Icons.call_end,
                label: 'End',
                onPressed: _endCall,
                backgroundColor: Colors.red,
              ),
            ],
          ),
        ),
      'error' => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'An error occurred. Please check your internet connection or try again.',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _endCall,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('End Call', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_mode == 'dialer')
              _buildDialer()
            else
              Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[900],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[700],
                            child: Text(
                              _contactName.isNotEmpty ? _contactName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 48, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _contactName,
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _numberController.text,
                            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getCallStatus(),
                            style: TextStyle(
                              fontSize: 18,
                              color: _callState == 'error' ? Colors.red : Colors.white70,
                            ),
                          ),
                          if (_callState == 'connected') ...[
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(_callDuration),
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildCallControls(),
                ],
              ),
            if (_isLoading && !_isInitialized)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? backgroundColor;

  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            backgroundColor: backgroundColor ?? (isActive ? Colors.blue : Colors.grey[700]),
            foregroundColor: Colors.white,
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}