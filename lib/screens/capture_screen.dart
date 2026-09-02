import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_service.dart';
import '../services/orientation_service.dart';
import '../models/capture_config.dart';
import 'stitching_screen.dart';

class CaptureScreen extends StatefulWidget {
  final CaptureConfig config;

  const CaptureScreen({
    super.key,
    this.config = CaptureConfig.horizontal360,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final OrientationService _orientationService = OrientationService();
  final List<File> _capturedImages = [];

  int _currentRow = 0;
  int _currentPhotoInRow = 0;
  bool _isCapturing = false;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  bool _autoCaptureEnabled = true;

  // Dwell / Hold-steady timer (1.2 seconds hold to capture)
  static const int _holdDurationMs = 1200;
  DateTime? _alignedStartTime;
  double _alignmentProgress = 0.0;
  Timer? _dwellTimer;
  bool _showFlashEffect = false;

  OrientationData _orientation = const OrientationData();
  String _statusMessage = 'Aim at the glowing dot to begin';
  double _targetYaw = 0.0;
  double _targetPitch = 0.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cameraStatus = await Permission.camera.request();

    if (!cameraStatus.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _statusMessage = 'Camera permission is required';
        });
      }
      return;
    }

    try {
      await _cameraService.initialize(preset: ResolutionPreset.high);
      _orientationService.start();

      // Reset initial yaw to 0 so the first photo is directly where the user points!
      _orientationService.resetYaw(0.0);

      _orientationService.onOrientationChanged.listen((data) {
        if (!mounted) return;
        setState(() {
          _orientation = data;
        });
        _updateAlignmentTimer();
      });

      // Start periodic timer for smooth countdown ring updates (60fps)
      _dwellTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted) return;
        _updateAlignmentTimer();
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _updateTarget();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera error: $e';
        });
      }
    }
  }

  void _updateTarget() {
    if (_currentRow >= widget.config.rowTiltAngles.length) return;
    _targetYaw = widget.config.anglePerPhoto(_currentRow) * _currentPhotoInRow;
    _targetPitch = widget.config.rowTiltAngles[_currentRow];
    _alignedStartTime = null;
    _alignmentProgress = 0.0;
  }

  double _getDeltaYaw() {
    double delta = _targetYaw - _orientation.yaw;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    return delta;
  }

  double _getDeltaPitch() {
    return _targetPitch - _orientation.pitch;
  }

  bool _isTargetAligned() {
    final dyaw = _getDeltaYaw().abs();
    final dpitch = _getDeltaPitch().abs();
    return dyaw <= 6.5 && dpitch <= 7.5;
  }

  void _updateAlignmentTimer() {
    if (!_isInitialized || _isCapturing) return;
    if (_currentRow >= widget.config.rowTiltAngles.length) return;

    if (_isTargetAligned()) {
      final now = DateTime.now();
      _alignedStartTime ??= now;

      final elapsedMs = now.difference(_alignedStartTime!).inMilliseconds;
      final progress = (elapsedMs / _holdDurationMs).clamp(0.0, 1.0);

      if (progress != _alignmentProgress) {
        setState(() {
          _alignmentProgress = progress;
        });
      }

      if (_autoCaptureEnabled && progress >= 1.0) {
        _alignedStartTime = null;
        _alignmentProgress = 0.0;
        _capturePhoto();
      }
    } else {
      if (_alignedStartTime != null || _alignmentProgress > 0.0) {
        setState(() {
          _alignedStartTime = null;
          _alignmentProgress = 0.0;
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isInitialized) return;
    if (_currentRow >= widget.config.rowTiltAngles.length) return;

    // Trigger visual shutter flash and haptic feedback
    HapticFeedback.heavyImpact();
    setState(() {
      _showFlashEffect = true;
      _isCapturing = true;
      _statusMessage = 'Capturing frame...';
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showFlashEffect = false);
      }
    });

    try {
      final file = await _cameraService.takePicture();
      _capturedImages.add(file);

      HapticFeedback.lightImpact();

      setState(() {
        _currentPhotoInRow++;
        _isCapturing = false;
        _alignedStartTime = null;
        _alignmentProgress = 0.0;

        if (_currentPhotoInRow >= widget.config.photosPerRow) {
          _currentPhotoInRow = 0;
          _currentRow++;

          if (_currentRow >= widget.config.rowTiltAngles.length) {
            _statusMessage = 'All photos captured! Ready to stitch.';
            _processImages();
            return;
          }
          _statusMessage =
              'Row ${_currentRow + 1}/${widget.config.totalRows} - Move to next target';
        } else {
          _statusMessage =
              'Photo ${_currentPhotoInRow + 1}/${widget.config.photosPerRow} - Rotate to next dot';
        }
        _updateTarget();
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Capture failed: $e';
      });
    }
  }

  void _undoLastPhoto() {
    if (_capturedImages.isEmpty) return;

    setState(() {
      final removed = _capturedImages.removeLast();
      try {
        removed.deleteSync();
      } catch (_) {}

      if (_currentPhotoInRow > 0) {
        _currentPhotoInRow--;
      } else if (_currentRow > 0) {
        _currentRow--;
        _currentPhotoInRow = widget.config.photosPerRow - 1;
      }
      _updateTarget();
      _statusMessage = 'Removed last photo';
    });
  }

  void _processImages() {
    if (_capturedImages.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture at least 2 photos before stitching'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StitchingScreen(images: List.from(_capturedImages)),
      ),
    );
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _cameraService.dispose();
    _orientationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 72, color: Colors.redAccent),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app needs camera access to capture 360° panoramic photos.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalPhotos = widget.config.totalPhotos;
    final totalProgress = _capturedImages.length / totalPhotos;
    final isAligned = _isTargetAligned();
    final deltaYaw = _getDeltaYaw();
    final deltaPitch = _getDeltaPitch();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _cameraService.controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraService.controller!.value.aspectRatio,
                child: CameraPreview(_cameraService.controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),

          // Interactive 360 Photosphere Target Overlay
          if (_isInitialized && _currentRow < widget.config.rowTiltAngles.length)
            CustomPaint(
              painter: _PhotosphereGuidePainter(
                deltaYaw: deltaYaw,
                deltaPitch: deltaPitch,
                isAligned: isAligned,
                alignmentProgress: _alignmentProgress,
                photoNumber: _currentPhotoInRow + 1,
                totalInRow: widget.config.photosPerRow,
                isCapturing: _isCapturing,
              ),
              size: Size.infinite,
            ),

          // Shutter Flash Animation Effect
          if (_showFlashEffect)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),

          // Top App Bar, Progress & Mini Radar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.config.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Row ${min(_currentRow + 1, widget.config.totalRows)}/${widget.config.totalRows} • Photo ${_currentPhotoInRow + 1}/${widget.config.photosPerRow}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Mini 360 Radar Compass
                      _buildMiniRadar(),

                      const SizedBox(width: 8),

                      // Flash toggle button
                      IconButton(
                        icon: Icon(
                          _cameraService.flashMode == FlashMode.torch
                              ? Icons.flash_on
                              : (_cameraService.flashMode == FlashMode.auto
                                  ? Icons.flash_auto
                                  : Icons.flash_off),
                          color: _cameraService.flashMode != FlashMode.off
                              ? Colors.yellowAccent
                              : Colors.white70,
                        ),
                        onPressed: () async {
                          await _cameraService.toggleFlash();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_capturedImages.length}/$totalPhotos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Prominent Direction Guidance Pill
          if (_isInitialized && _currentRow < widget.config.rowTiltAngles.length)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 16,
              right: 16,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAligned
                        ? const Color(0xFF00E676)
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isAligned ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isAligned ? const Color(0xFF00E676) : Colors.black)
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAligned
                            ? Icons.camera
                            : (deltaYaw > 0 ? Icons.arrow_forward : Icons.arrow_back),
                        color: isAligned ? Colors.black : const Color(0xFFFFB300),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAligned
                            ? 'HOLD STEADY... ${((1.0 - _alignmentProgress) * (_holdDurationMs / 1000)).toStringAsFixed(1)}s'
                            : _getGuidanceText(deltaYaw, deltaPitch),
                        style: TextStyle(
                          color: isAligned ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: isAligned ? const Color(0xFF00E676) : Colors.white70,
                      fontSize: 13,
                      fontWeight: isAligned ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Undo button
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white70, size: 28),
                        tooltip: 'Undo last photo',
                        onPressed: _capturedImages.isNotEmpty && !_isCapturing
                            ? _undoLastPhoto
                            : null,
                      ),

                      // Reset 0° heading button
                      IconButton(
                        icon: const Icon(Icons.compass_calibration, color: Colors.white70, size: 28),
                        tooltip: 'Reset Heading (0°)',
                        onPressed: () {
                          _orientationService.resetYaw(0.0);
                          _updateTarget();
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Target heading re-centered!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),

                      // Main Shutter Button
                      GestureDetector(
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAligned ? const Color(0xFF00E676) : Colors.white,
                              width: 4,
                            ),
                            color: isAligned
                                ? const Color(0xFF00E676).withValues(alpha: 0.3)
                                : Colors.white24,
                            boxShadow: isAligned
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                      blurRadius: 18,
                                      spreadRadius: 3,
                                    )
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: _isCapturing
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isAligned ? const Color(0xFF00E676) : Colors.white,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: isAligned ? Colors.black : const Color(0xFF1A1A2E),
                                      size: 30,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // Auto-capture toggle
                      IconButton(
                        icon: Icon(
                          _autoCaptureEnabled ? Icons.bolt : Icons.flash_off,
                          color: _autoCaptureEnabled ? const Color(0xFF00E5FF) : Colors.white38,
                          size: 28,
                        ),
                        tooltip: _autoCaptureEnabled ? 'Auto-capture ON' : 'Auto-capture OFF',
                        onPressed: () {
                          setState(() {
                            _autoCaptureEnabled = !_autoCaptureEnabled;
                          });
                        },
                      ),

                      // Finish & Stitch button
                      IconButton(
                        icon: Icon(
                          Icons.done_all,
                          color: _capturedImages.length >= 2
                              ? const Color(0xFF00E676)
                              : Colors.white24,
                          size: 28,
                        ),
                        tooltip: 'Finish & Stitch Now',
                        onPressed: _capturedImages.length >= 2 ? _processImages : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRadar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: CustomPaint(
        painter: _RadarPainter(
          photosPerRow: widget.config.photosPerRow,
          currentPhoto: _currentPhotoInRow,
          capturedCount: _currentPhotoInRow,
          currentYaw: _orientation.yaw,
        ),
      ),
    );
  }

  String _getGuidanceText(double dyaw, double dpitch) {
    final List<String> directions = [];
    if (dyaw > 5) {
      directions.add('ROTATE RIGHT 👉 ${dyaw.toStringAsFixed(0)}°');
    } else if (dyaw < -5) {
      directions.add('👈 ROTATE LEFT ${(-dyaw).toStringAsFixed(0)}°');
    }

    if (dpitch > 6) {
      directions.add('TILT UP 👆 ${dpitch.toStringAsFixed(0)}°');
    } else if (dpitch < -6) {
      directions.add('👇 TILT DOWN ${(-dpitch).toStringAsFixed(0)}°');
    }

    return directions.isEmpty ? 'ALIGNED! HOLD STEADY' : directions.join(' • ');
  }
}

class _PhotosphereGuidePainter extends CustomPainter {
  final double deltaYaw;
  final double deltaPitch;
  final bool isAligned;
  final double alignmentProgress;
  final int photoNumber;
  final int totalInRow;
  final bool isCapturing;

  _PhotosphereGuidePainter({
    required this.deltaYaw,
    required this.deltaPitch,
    required this.isAligned,
    required this.alignmentProgress,
    required this.photoNumber,
    required this.totalInRow,
    required this.isCapturing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // --- 1. Center Reticle (Viewfinder Bullseye) ---
    const reticleRadius = 44.0;

    // Outer viewfinder ring
    final reticlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.5 : 2.0
      ..color = isAligned ? const Color(0xFF00E676) : Colors.white70;

    canvas.drawCircle(Offset(centerX, centerY), reticleRadius, reticlePaint);

    // Crosshair ticks
    const tickLen = 10.0;
    canvas.drawLine(
      Offset(centerX - reticleRadius - tickLen, centerY),
      Offset(centerX - reticleRadius, centerY),
      reticlePaint,
    );
    canvas.drawLine(
      Offset(centerX + reticleRadius, centerY),
      Offset(centerX + reticleRadius + tickLen, centerY),
      reticlePaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - reticleRadius - tickLen),
      Offset(centerX, centerY - reticleRadius),
      reticlePaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY + reticleRadius),
      Offset(centerX, centerY + reticleRadius + tickLen),
      reticlePaint,
    );

    // Countdown / Hold-steady progress ring around the reticle
    if (isAligned && alignmentProgress > 0.0) {
      final timerArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF00E676);

      const sweepAngle = 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: reticleRadius + 4),
        -pi / 2,
        sweepAngle * alignmentProgress,
        false,
        timerArcPaint,
      );
    }

    // --- 2. Project Target Angle onto Screen ---
    // Phone camera FOV: ~60° horizontal, ~80° vertical
    final screenDx = (deltaYaw / 30.0) * (size.width / 2);
    final screenDy = -(deltaPitch / 40.0) * (size.height / 2);

    final targetX = centerX + screenDx;
    final targetY = centerY + screenDy;

    final isInsideScreen = targetX >= 36 &&
        targetX <= size.width - 36 &&
        targetY >= 110 &&
        targetY <= size.height - 150;

    if (isInsideScreen) {
      // --- Draw Target Dot (Large, High-Contrast Glowing Orb) ---
      const dotRadius = 24.0;

      // Outer glowing halo
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isAligned ? const Color(0xFF00E676) : const Color(0xFFFFB300))
            .withValues(alpha: 0.35);
      canvas.drawCircle(Offset(targetX, targetY), dotRadius + 14.0, haloPaint);

      // Outer sharp border ring
      final outerRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = isAligned ? const Color(0xFF00E676) : Colors.white;
      canvas.drawCircle(Offset(targetX, targetY), dotRadius, outerRingPaint);

      // Inner solid luminous circle
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isAligned ? const Color(0xFF00E676) : const Color(0xFFFFB300);
      canvas.drawCircle(Offset(targetX, targetY), dotRadius - 2.0, dotPaint);

      // Draw photo number inside target dot
      final textSpan = TextSpan(
        text: '$photoNumber',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(targetX - textPainter.width / 2, targetY - textPainter.height / 2),
      );

      // Guiding connecting line between center and target dot
      if (!isAligned) {
        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.6);
        canvas.drawLine(Offset(centerX, centerY), Offset(targetX, targetY), linePaint);
      }
    } else {
      // --- Target is Off-Screen: Draw Large Glowing Direction Indicator ---
      final angle = atan2(screenDy, screenDx);
      final edgeRadius = min(size.width / 2 - 40, size.height / 2 - 140);
      final arrowX = centerX + edgeRadius * cos(angle);
      final arrowY = centerY + edgeRadius * sin(angle);

      // Arrow background circle
      final circleBgPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFB300);
      canvas.drawCircle(Offset(arrowX, arrowY), 20.0, circleBgPaint);

      // Arrow path
      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black;

      canvas.save();
      canvas.translate(arrowX, arrowY);
      canvas.rotate(angle);

      final path = Path()
        ..moveTo(10, 0)
        ..lineTo(-6, -8)
        ..lineTo(-3, 0)
        ..lineTo(-6, 8)
        ..close();

      canvas.drawPath(path, arrowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PhotosphereGuidePainter oldDelegate) => true;
}

class _RadarPainter extends CustomPainter {
  final int photosPerRow;
  final int currentPhoto;
  final int capturedCount;
  final double currentYaw;

  _RadarPainter({
    required this.photosPerRow,
    required this.currentPhoto,
    required this.capturedCount,
    required this.currentYaw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Outer circle
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white24;
    canvas.drawCircle(center, radius, linePaint);

    // Current camera heading line
    final headingAngle = (currentYaw - 90) * pi / 180;
    final headingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF00E5FF);
    canvas.drawLine(
      center,
      Offset(center.dx + radius * cos(headingAngle), center.dy + radius * sin(headingAngle)),
      headingPaint,
    );

    // Photo dots around 360 ring
    for (int i = 0; i < photosPerRow; i++) {
      final angle = (i * (360.0 / photosPerRow) - 90) * pi / 180;
      final dotPos = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));

      final paint = Paint()..style = PaintingStyle.fill;
      if (i < capturedCount) {
        paint.color = const Color(0xFF00E676); // Already captured: green
      } else if (i == currentPhoto) {
        paint.color = const Color(0xFFFFB300); // Current target: amber
      } else {
        paint.color = Colors.white38; // Remaining: dim white
      }

      canvas.drawCircle(dotPos, i == currentPhoto ? 3.5 : 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
