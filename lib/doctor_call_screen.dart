import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:medsoft_doctor/constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart'; // REQUIRED for firstWhereOrNull

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
  bool _isScreenShared = false;
  bool _isConnecting = false;
  bool _isRecording = false;
  bool _isProcessing = false;

  // --- UI Test Variables ---
  bool uiTest = false; // Toggle to true to see layouts without connecting
  int roomSize = 3; // Number of mock users to show in test mode

  // Track which participant is currently "zoomed"
  Participant? _focusedParticipant;

  @override
  void dispose() {
    try {
      _listener();
    } catch (_) {}
    _room?.disconnect();

    // Reset orientations to default when leaving the call
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('Username');
    if (username == null || username.isEmpty) {
      throw Exception('Username not found in SharedPreferences');
    }
    final response = await http.get(
      Uri.parse('${Constants.liveKitTokenUrl}/token?identity=$username&room=testroom'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to fetch token');
    }
  }

  Future<void> _connect() async {
    setState(() => _isConnecting = true);
    try {
      await _requestPermissions();
      final token = await _getToken();
      final room = Room();

      // Listener ensures UI updates when remote tracks (like screen shares) are added
      // Listener ensures UI updates when remote tracks (like screen shares) are added
      _listener = room.events.listen((event) {
        if (event is RoomRecordingStatusChanged) {
          setState(() => _isRecording = event.activeRecording);
        } else if (event is DataReceivedEvent) {
          // Listen for manual sync messages from Web or other Apps
          final message = utf8.decode(event.data);
          if (message == 'rec_on') setState(() => _isRecording = true);
          if (message == 'rec_off') setState(() => _isRecording = false);
        } else {
          setState(() {});
        }
      });

      await room.connect(Constants.livekitUrl, token);
      setState(() {
        _isRecording = room.isRecording;
        _room = room;
      });
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);
      setState(() => _room = room);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connect Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final bool starting = !_isRecording;
    final endpoint = starting ? 'start-recording' : 'stop-recording';
    final url = Uri.parse('${Constants.recordingUrl}/$endpoint?room=testroom');

    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        // 1. Update own UI immediately
        setState(() => _isRecording = starting);

        // 2. BROADCAST to everyone else (Web/App)
        final data = utf8.encode(starting ? 'rec_on' : 'rec_off');
        await _room?.localParticipant?.publishData(data);
      }
    } catch (e) {
      debugPrint("Recording Toggle Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _renderParticipantTile(Participant participant, {bool isLocal = false}) {
    // Priority: 1. Screen Share, 2. Camera
    var trackPub = participant.videoTrackPublications.firstWhereOrNull((e) => e.isScreenShare);
    trackPub ??= participant.videoTrackPublications.firstOrNull;

    final isMuted = isLocal ? !_camEnabled : (trackPub?.muted ?? true);

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle zoom: if already focused, return to grid; otherwise, zoom in
          _focusedParticipant = (_focusedParticipant == participant) ? null : participant;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: trackPub?.isScreenShare == true
                ? Colors.greenAccent
                : (isLocal ? Colors.blueAccent : Colors.white10),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: (trackPub?.track is VideoTrack && !isMuted)
                    ? VideoTrackRenderer(
                        trackPub!.track as VideoTrack,
                        fit: trackPub.isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
                        mirrorMode: (isLocal && !trackPub.isScreenShare)
                            ? VideoViewMirrorMode.mirror
                            : VideoViewMirrorMode.off,
                      )
                    : Container(
                        color: Colors.blueGrey.withOpacity(0.1),
                        child: const Center(
                          child: Icon(Icons.person, color: Colors.white24, size: 50),
                        ),
                      ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${participant.identity ?? (isLocal ? "You" : "User")}${trackPub?.isScreenShare == true ? " (Screen)" : ""}",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for UI testing without real participants
  Widget _buildDummyTile(int index) {
    return GestureDetector(
      onTap: () => setState(() => uiTest = false), // Tap mock to exit test mode
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bug_report, color: Colors.white24, size: 40),
              Text("Mock User $index", style: const TextStyle(color: Colors.white24)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Device detection for rotation locking
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    final bool isTablet = shortestSide >= 600;

    if (!isTablet) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // 2. Participant Logic
    List<Participant> allParticipants = [];
    if (_room != null) {
      allParticipants = [_room!.localParticipant!, ..._room!.remoteParticipants.values];
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(uiTest ? 'UI TEST MODE ($roomSize)' : 'Doctor Portal'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: (_room == null && !uiTest)
          ? _buildInitialUI()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _focusedParticipant != null
                        ? _buildZoomedView(allParticipants)
                        : _buildDefaultLayout(allParticipants),
                  ),
                  _buildControlBar(),
                ],
              ),
            ),
    );
  }

  Widget _buildInitialUI() {
    return Center(
      child: _isConnecting
          ? const CircularProgressIndicator(color: Colors.white)
          : ElevatedButton(onPressed: _connect, child: const Text('Start Consultation')),
    );
  }

  Widget _buildZoomedView(List<Participant> allParticipants) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _renderParticipantTile(
            _focusedParticipant!,
            isLocal: _focusedParticipant is LocalParticipant,
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: allParticipants
                .where((p) => p != _focusedParticipant)
                .map(
                  (p) => SizedBox(
                    width: 120,
                    child: _renderParticipantTile(p, isLocal: p is LocalParticipant),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultLayout(List<Participant> allParticipants) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int effectiveCount = uiTest ? roomSize : allParticipants.length;
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (uiTest) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLandscape ? 3 : 2,
              childAspectRatio: 1.0,
            ),
            itemCount: roomSize,
            itemBuilder: (context, index) => _buildDummyTile(index),
          );
        }

        if (effectiveCount == 2 && (MediaQuery.of(context).size.shortestSide < 600)) {
          return _buildIPhone1vs1(allParticipants);
        }

        return _buildNoScrollGrid(allParticipants, isLandscape);
      },
    );
  }

  Widget _buildIPhone1vs1(List<Participant> participants) {
    return Stack(
      children: [
        Positioned.fill(child: _renderParticipantTile(participants[1])),
        Positioned(
          top: 10,
          right: 10,
          width: 110,
          height: 160,
          child: _renderParticipantTile(participants[0], isLocal: true),
        ),
      ],
    );
  }

  Widget _buildNoScrollGrid(List<Participant> participants, bool isLandscape) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 3 : 2,
        childAspectRatio: 1.0,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        return _renderParticipantTile(p, isLocal: index == 0);
      },
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: _micEnabled ? Icons.mic : Icons.mic_off,
            color: _micEnabled ? Colors.white24 : Colors.red,
            onPressed: () {
              _micEnabled = !_micEnabled;
              _room?.localParticipant?.setMicrophoneEnabled(_micEnabled);
              setState(() {});
            },
          ),
          _buildActionButton(
            icon: _camEnabled ? Icons.videocam : Icons.videocam_off,
            color: _camEnabled ? Colors.white24 : Colors.red,
            onPressed: () {
              _camEnabled = !_camEnabled;
              _room?.localParticipant?.setCameraEnabled(_camEnabled);
              setState(() {});
            },
          ),
          _buildActionButton(
            icon: Icons.flip_camera_ios,
            color: Colors.white24,
            onPressed: () async {
              final track = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
              if (track is LocalVideoTrack) {
                // Access the facing mode from the map correctly using ['facingMode']
                final settings = track.mediaStreamTrack.getSettings();
                final isFront = settings['facingMode'] == 'user';

                await track.restartTrack(
                  CameraCaptureOptions(
                    // Use the class constructor directly
                    cameraPosition: isFront ? CameraPosition.back : CameraPosition.front,
                  ),
                );
                setState(() {}); // Refresh UI
              }
            },
          ),

          _buildActionButton(
            icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
            color: _isRecording ? Colors.red : Colors.white24,
            onPressed: _toggleRecording,
          ),

          _buildActionButton(
            icon: _isScreenShared ? Icons.stop_screen_share : Icons.screen_share,
            color: _isScreenShared ? Colors.green : Colors.white24,
            onPressed: () async {
              try {
                _isScreenShared = !_isScreenShared;
                await _room?.localParticipant?.setScreenShareEnabled(_isScreenShared);
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Screen Share Error: $e")));
              }
            },
          ),
          _buildActionButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: () async {
              await _room?.disconnect();
              setState(() => _room = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
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
}
