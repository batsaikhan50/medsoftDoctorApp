import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:medsoft_doctor/call_manager.dart';
import 'package:collection/collection.dart';

class PipOverlayWidget extends StatefulWidget {
  final CallManager callManager;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const PipOverlayWidget({
    super.key,
    required this.callManager,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<PipOverlayWidget> createState() => _PipOverlayWidgetState();
}

class _PipOverlayWidgetState extends State<PipOverlayWidget> {
  double _xPos = 20;
  double _yPos = 100;

  static const double _width = 120;
  static const double _height = 170;

  @override
  void initState() {
    super.initState();
    widget.callManager.addListener(_onCallStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _xPos = size.width - _width - 16;
        _yPos = size.height - _height - 120;
      });
    });
  }

  @override
  void dispose() {
    widget.callManager.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    if (!widget.callManager.isConnected) {
      widget.onClose();
      return;
    }
    if (mounted) setState(() {});
  }

  Widget _buildVideoContent() {
    final room = widget.callManager.room;
    if (room == null) return _buildPlaceholder();

    final remoteParticipant = room.remoteParticipants.values.firstOrNull;
    if (remoteParticipant == null) return _buildPlaceholder();

    final trackPub = remoteParticipant.videoTrackPublications.firstWhereOrNull(
      (e) => !e.isScreenShare,
    ) ?? remoteParticipant.videoTrackPublications.firstOrNull;

    if (trackPub?.track is VideoTrack && !(trackPub?.muted ?? true)) {
      return VideoTrackRenderer(
        trackPub!.track as VideoTrack,
        fit: VideoViewFit.cover,
        mirrorMode: VideoViewMirrorMode.off,
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white38, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.callManager.isConnected) return const SizedBox.shrink();

    return Positioned(
      left: _xPos,
      top: _yPos,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xPos += details.delta.dx;
            _yPos += details.delta.dy;
            final size = MediaQuery.of(context).size;
            _xPos = _xPos.clamp(0, size.width - _width);
            _yPos = _yPos.clamp(0, size.height - _height);
          });
        },
        onTap: widget.onTap,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black54,
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildVideoContent()),
                  // Close button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  // Expand icon
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_in_full, color: Colors.white, size: 12),
                    ),
                  ),
                  // Recording indicator
                  if (widget.callManager.isRecording)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
