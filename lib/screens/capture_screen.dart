import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_service.dart';
import '../services/orientation_service.dart';
import '../models/capture_config.dart';
import 'stitching_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final CameraService _cameraService = CameraService();
  final OrientationService _orientationService = OrientationService();
  final CaptureConfig _config = CaptureConfig.defaultConfig;
  final List<File> _capturedImages = [];

  int _currentRow = 0;
  int _currentPhotoInRow = 0;
  bool _isCapturing = false;
  bool _isInitialized = false;
  OrientationData _orientation = const OrientationData();
  String _statusMessage = 'Initializing camera...';
  double _targetYaw = 0;
  double _targetPitch = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();

    if (!cameraStatus.isGranted) {
      setState(() => _statusMessage = 'Camera permission denied');
      return;
    }
    if (!storageStatus.isGranted) {
      setState(() => _statusMessage = 'Storage permission denied');
      return;
    }

    try {
      await _cameraService.initialize();
      _orientationService.start();
      _orientationService.onOrientationChanged.listen((data) {
        if (mounted) {
          setState(() => _orientation = data);
        }
      });

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Tap to start capturing';
        _updateTarget();
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  void _updateTarget() {
    if (_currentRow >= _config.rowTiltAngles.length) return;
    _targetYaw = _config.anglePerPhoto(_currentRow) * _currentPhotoInRow;
    _targetPitch = _config.rowTiltAngles[_currentRow];
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isInitialized) return;
    if (_currentRow >= _config.rowTiltAngles.length) return;

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing...';
    });

    try {
      final file = await _cameraService.takePicture();
      _capturedImages.add(file);

      setState(() {
        _currentPhotoInRow++;
        _isCapturing = false;

        if (_currentPhotoInRow >= _config.photosPerRow) {
          _currentPhotoInRow = 0;
          _currentRow++;

          if (_currentRow >= _config.rowTiltAngles.length) {
            _statusMessage = 'All photos captured!';
            _processImages();
            return;
          }
          _statusMessage = 'Row ${_currentRow + 1}/${_config.totalRows} - Ready';
        } else {
          _statusMessage =
              'Row ${_currentRow + 1} - Photo ${_currentPhotoInRow + 1}/${_config.photosPerRow}';
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

  void _processImages() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StitchingScreen(images: _capturedImages),
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
    final totalProgress = _capturedImages.length / _config.totalPhotos;
    final rowProgress = _currentRow < _config.rowTiltAngles.length
        ? _currentPhotoInRow / _config.photosPerRow
        : 1.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isInitialized && _cameraService.controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraService.controller!.value.aspectRatio,
                child: CameraPreview(_cameraService.controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          if (_isInitialized) _buildGuideOverlay(),

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
              decoration: BoxDecoration(
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '360 Capture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Row ${min(_currentRow + 1, _config.totalRows)}/${_config.totalRows}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: totalProgress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF1A73E8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_capturedImages.length}/${_config.totalPhotos}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Photo ${_currentPhotoInRow + 1}/${_config.photosPerRow}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: rowProgress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.greenAccent,
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 24,
                right: 24,
                top: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  if (_currentRow < _config.rowTiltAngles.length)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Target: ${_targetYaw.toStringAsFixed(0)}° yaw, ${_targetPitch.toStringAsFixed(0)}° pitch',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Current: ${_orientation.yaw.toStringAsFixed(0)}° / ${_orientation.pitch.toStringAsFixed(0)}°',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: FloatingActionButton(
                      onPressed: _isCapturing ? null : _capturePhoto,
                      backgroundColor: Colors.white,
                      elevation: 8,
                      child: _isCapturing
                          ? const CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 3,
                            )
                          : const Icon(
                              Icons.camera,
                              color: Colors.blue,
                              size: 36,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isInitialized) _buildGuideDots(),
        ],
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return CustomPaint(
      painter: _GuidePainter(
        config: _config,
        currentRow: _currentRow,
        currentPhoto: _currentPhotoInRow,
        orientation: _orientation,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildGuideDots() {
    if (_currentRow >= _config.rowTiltAngles.length) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: 2,
        height: 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.8),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final CaptureConfig config;
  final int currentRow;
  final int currentPhoto;
  final OrientationData orientation;

  _GuidePainter({
    required this.config,
    required this.currentRow,
    required this.currentPhoto,
    required this.orientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentRow >= config.rowTiltAngles.length) return;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent.withOpacity(0.6);

    final activeDotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.yellowAccent.withOpacity(0.9);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white24;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.35;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      linePaint,
    );

    for (int i = 0; i < config.photosPerRow; i++) {
      final angle = (config.anglePerPhoto(currentRow) * i - 90) * pi / 180;
      final dotX = centerX + radius * cos(angle);
      final dotY = centerY + radius * sin(angle);

      final isActive = i == currentPhoto;
      final isTaken = i < currentPhoto;

      canvas.drawCircle(
        Offset(dotX, dotY),
        isActive ? 8.0 : 5.0,
        isActive ? activeDotPaint : (isTaken ? Paint()..color = Colors.blue : dotPaint),
      );

      if (isActive) {
        canvas.drawCircle(
          Offset(dotX, dotY),
          14.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.yellowAccent.withOpacity(0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
