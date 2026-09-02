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

class _CaptureScreenState extends State<CaptureScreen> {
  final CameraService _cameraService = CameraService();
  final OrientationService _orientationService = OrientationService();
  final List<File> _capturedImages = [];

  int _currentRow = 0;
  int _currentPhotoInRow = 0;
  bool _isCapturing = false;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  bool _autoCaptureEnabled = true;
  DateTime _lastAutoCaptureTime = DateTime.now();

  OrientationData _orientation = const OrientationData();
  String _statusMessage = 'Align the dot with the center ring';
  double _targetYaw = 0;
  double _targetPitch = 0;

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
          _statusMessage = 'Camera permission is required to capture photos';
        });
      }
      return;
    }

    try {
      await _cameraService.initialize(preset: ResolutionPreset.high);
      _orientationService.start();
      _orientationService.onOrientationChanged.listen((data) {
        if (!mounted) return;
        setState(() {
          _orientation = data;
        });
        _checkAlignment(data);
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
    return dyaw <= 5.0 && dpitch <= 6.0;
  }

  void _checkAlignment(OrientationData data) {
    if (!_isInitialized || _isCapturing) return;
    if (_currentRow >= widget.config.rowTiltAngles.length) return;

    if (_isTargetAligned()) {
      final now = DateTime.now();
      if (_autoCaptureEnabled && now.difference(_lastAutoCaptureTime).inMilliseconds > 1500) {
        _lastAutoCaptureTime = now;
        _capturePhoto();
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isInitialized) return;
    if (_currentRow >= widget.config.rowTiltAngles.length) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing frame...';
    });

    try {
      final file = await _cameraService.takePicture();
      _capturedImages.add(file);

      HapticFeedback.lightImpact();

      setState(() {
        _currentPhotoInRow++;
        _isCapturing = false;

        if (_currentPhotoInRow >= widget.config.photosPerRow) {
          _currentPhotoInRow = 0;
          _currentRow++;

          if (_currentRow >= widget.config.rowTiltAngles.length) {
            _statusMessage = 'All photos captured! Ready to stitch.';
            _processImages();
            return;
          }
          _statusMessage = 'Row ${_currentRow + 1}/${widget.config.totalRows} - Align dot';
        } else {
          _statusMessage =
              'Photo ${_currentPhotoInRow + 1}/${widget.config.photosPerRow} - Align dot';
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
      _statusMessage = 'Removed previous photo';
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
              child: CircularProgressIndicator(color: Color(0xFF00D2C4)),
            ),

          // Interactive 360 Guidance Overlay
          if (_isInitialized && _currentRow < widget.config.rowTiltAngles.length)
            CustomPaint(
              painter: _PhotosphereGuidePainter(
                deltaYaw: deltaYaw,
                deltaPitch: deltaPitch,
                isAligned: isAligned,
                isCapturing: _isCapturing,
              ),
              size: Size.infinite,
            ),

          // Top App Bar & Progress
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
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
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
                      // Flash button
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
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF00D2C4)),
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

          // Alignment Direction Guidance Pill
          if (_isInitialized && _currentRow < widget.config.rowTiltAngles.length)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAligned
                        ? Colors.greenAccent.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAligned ? Colors.greenAccent : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAligned ? Icons.check_circle : Icons.navigation,
                        color: isAligned ? Colors.black : const Color(0xFF00D2C4),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAligned
                            ? 'ALIGNED - HOLD STEADY'
                            : _getGuidanceText(deltaYaw, deltaPitch),
                        style: TextStyle(
                          color: isAligned ? Colors.black : Colors.white,
                          fontSize: 12,
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
                  // Status message
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: isAligned ? Colors.greenAccent : Colors.white70,
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

                      // Reset yaw / center button
                      IconButton(
                        icon: const Icon(Icons.compass_calibration, color: Colors.white70, size: 28),
                        tooltip: 'Reset Center (0°)',
                        onPressed: () {
                          _orientationService.resetYaw(0.0);
                          _updateTarget();
                          HapticFeedback.lightImpact();
                        },
                      ),

                      // Main Capture Shutter Button
                      GestureDetector(
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAligned ? Colors.greenAccent : Colors.white,
                              width: 4,
                            ),
                            color: isAligned
                                ? Colors.greenAccent.withValues(alpha: 0.3)
                                : Colors.white24,
                            boxShadow: isAligned
                                ? [
                                    BoxShadow(
                                      color: Colors.greenAccent.withValues(alpha: 0.5),
                                      blurRadius: 16,
                                      spreadRadius: 2,
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
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isAligned ? Colors.greenAccent : Colors.white,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: isAligned ? Colors.black : const Color(0xFF1A1A2E),
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // Auto-capture toggle button
                      IconButton(
                        icon: Icon(
                          _autoCaptureEnabled ? Icons.bolt : Icons.flash_off,
                          color: _autoCaptureEnabled ? const Color(0xFF00D2C4) : Colors.white38,
                          size: 28,
                        ),
                        tooltip: 'Auto-capture on alignment',
                        onPressed: () {
                          setState(() {
                            _autoCaptureEnabled = !_autoCaptureEnabled;
                          });
                        },
                      ),

                      // Finish & Stitch button (available once >= 2 photos taken)
                      IconButton(
                        icon: Icon(
                          Icons.done_all,
                          color: _capturedImages.length >= 2
                              ? Colors.greenAccent
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

  String _getGuidanceText(double dyaw, double dpitch) {
    final List<String> directions = [];
    if (dyaw > 5) {
      directions.add('Rotate Right ${dyaw.toStringAsFixed(0)}°');
    } else if (dyaw < -5) {
      directions.add('Rotate Left ${(-dyaw).toStringAsFixed(0)}°');
    }

    if (dpitch > 6) {
      directions.add('Tilt Up ${dpitch.toStringAsFixed(0)}°');
    } else if (dpitch < -6) {
      directions.add('Tilt Down ${(-dpitch).toStringAsFixed(0)}°');
    }

    return directions.isEmpty ? 'Center Target' : directions.join(' • ');
  }
}

class _PhotosphereGuidePainter extends CustomPainter {
  final double deltaYaw;
  final double deltaPitch;
  final bool isAligned;
  final bool isCapturing;

  _PhotosphereGuidePainter({
    required this.deltaYaw,
    required this.deltaPitch,
    required this.isAligned,
    required this.isCapturing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Center Crosshairs / Reticle
    final reticlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.0 : 1.8
      ..color = isAligned ? Colors.greenAccent : Colors.white70;

    const reticleRadius = 32.0;
    canvas.drawCircle(Offset(centerX, centerY), reticleRadius, reticlePaint);

    // Crosshair ticks
    const tickLen = 8.0;
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

    // Project target angle onto screen coordinates
    // Approximate phone camera field of view: 60° horizontal, 80° vertical
    final screenDx = (deltaYaw / 30.0) * (size.width / 2);
    final screenDy = -(deltaPitch / 40.0) * (size.height / 2);

    final targetX = centerX + screenDx;
    final targetY = centerY + screenDy;

    final isInsideScreen = targetX >= 24 &&
        targetX <= size.width - 24 &&
        targetY >= 100 &&
        targetY <= size.height - 140;

    if (isInsideScreen) {
      // Draw target sphere / dot inside screen
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isAligned
            ? Colors.greenAccent
            : const Color(0xFF00D2C4).withValues(alpha: 0.9);

      final haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = isAligned
            ? Colors.greenAccent.withValues(alpha: 0.6)
            : const Color(0xFF00D2C4).withValues(alpha: 0.4);

      canvas.drawCircle(Offset(targetX, targetY), 16.0, haloPaint);
      canvas.drawCircle(Offset(targetX, targetY), 9.0, dotPaint);

      // Line connecting center reticle to target dot
      if (!isAligned) {
        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF00D2C4).withValues(alpha: 0.35);
        canvas.drawLine(Offset(centerX, centerY), Offset(targetX, targetY), linePaint);
      }
    } else {
      // Draw indicator arrow at the edge of the screen pointing to off-screen target
      final angle = atan2(screenDy, screenDx);
      final edgeRadius = min(size.width / 2 - 32, size.height / 2 - 120);
      final arrowX = centerX + edgeRadius * cos(angle);
      final arrowY = centerY + edgeRadius * sin(angle);

      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF00D2C4);

      canvas.save();
      canvas.translate(arrowX, arrowY);
      canvas.rotate(angle);

      final path = Path()
        ..moveTo(14, 0)
        ..lineTo(-8, -10)
        ..lineTo(-4, 0)
        ..lineTo(-8, 10)
        ..close();

      canvas.drawPath(path, arrowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PhotosphereGuidePainter oldDelegate) => true;
}
