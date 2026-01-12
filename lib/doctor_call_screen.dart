import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:medsoft_doctor/constants.dart';
import 'package:permission_handler/permission_handler.dart';

class DoctorCallScreen extends StatefulWidget {
  const DoctorCallScreen({super.key});

  @override
  State<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends State<DoctorCallScreen> {
  Room? _room;
  late CancelListenFunc _listener;
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _frontCamera = true;

  @override
  void dispose() {
    try {
      _listener();
    } catch (_) {}
    _room?.disconnect();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<String> _getToken() async {
    // 1. Use the Token Server URL (Port 3000)
    final response = await http.get(
      Uri.parse('${Constants.liveKitTokenUrl}/token?identity=doctor1&room=testroom'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to fetch token');
    }
  }

  Future<void> _connect() async {
    try {
      await _requestPermissions();
      final token = await _getToken();

      final room = Room();

      // Setup listener to refresh UI when participants join
      _listener = room.events.listen((event) {
        setState(() {});
      });

      // 2. Use the LiveKit Server URL (ws://... port 7880)
      await room.connect(Constants.livekitUrl, token);

      // 3. Enable Local Media
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _room = room;
      });

      debugPrint("Doctor connected to room");
    } catch (e) {
      debugPrint('Connection error: $e');
      // Show a snackbar so you know why it failed on the phone
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connect Error: $e")));
      }
    }
  }

  // --- UI Helpers ---

  Widget _renderParticipant(Participant participant, {bool mirror = false}) {
    final trackPub = participant.videoTrackPublications.firstOrNull;
    final isMuted = participant is LocalParticipant ? !_camEnabled : trackPub?.muted ?? true;

    if (trackPub?.track is VideoTrack && !isMuted) {
      return VideoTrackRenderer(
        trackPub!.track as VideoTrack,
        mirrorMode: mirror ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
      );
    }
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Text('Camera Off', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Doctor Consultation')),
      body: _room == null
          ? Center(
              child: ElevatedButton(onPressed: _connect, child: const Text('Join Call')),
            )
          : Stack(
              children: [
                // 1. FULL SCREEN: Remote Participant
                Positioned.fill(
                  child: _room!.remoteParticipants.isNotEmpty
                      ? _renderParticipant(_room!.remoteParticipants.values.first)
                      : const Center(
                          child: Text(
                            "Waiting for Patient...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),

                // 2. OVERLAY: Local Preview
                Positioned(
                  top: 16,
                  right: 16,
                  width: 110,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _renderParticipant(_room!.localParticipant!, mirror: _frontCamera),
                  ),
                ),

                // 3. CONTROLS
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _micEnabled ? Icons.mic : Icons.mic_off,
                        color: _micEnabled ? Colors.white24 : Colors.red,
                        onPressed: () {
                          _micEnabled = !_micEnabled;
                          _room?.localParticipant?.setMicrophoneEnabled(_micEnabled);
                          setState(() {});
                        },
                      ),
                      _buildControlButton(
                        icon: _camEnabled ? Icons.videocam : Icons.videocam_off,
                        color: _camEnabled ? Colors.white24 : Colors.red,
                        onPressed: () {
                          _camEnabled = !_camEnabled;
                          _room?.localParticipant?.setCameraEnabled(_camEnabled);
                          setState(() {});
                        },
                      ),
                      _buildControlButton(
                        icon: Icons.cameraswitch,
                        color: Colors.white24,
                        onPressed: () async {
                          final track =
                              _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
                          if (track is LocalVideoTrack) {
                            _frontCamera = !_frontCamera;
                            await track.setCameraPosition(
                              _frontCamera ? CameraPosition.front : CameraPosition.back,
                            );
                            setState(() {});
                          }
                        },
                      ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onPressed: () async {
                          await _room?.disconnect();
                          setState(() => _room = null);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
