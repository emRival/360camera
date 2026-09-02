import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/stitcher_service.dart';
import '../utils/image_utils.dart';
import 'preview_screen.dart';

class StitchingScreen extends StatefulWidget {
  final List<File> images;

  const StitchingScreen({super.key, required this.images});

  @override
  State<StitchingScreen> createState() => _StitchingScreenState();
}

class _StitchingScreenState extends State<StitchingScreen> {
  String _status = 'Initializing stitcher engine...';
  double _progress = 0.05;
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startStitching();
  }

  Future<void> _startStitching() async {
    setState(() {
      _error = null;
      _isProcessing = true;
      _status = 'Preparing ${widget.images.length} photos...';
      _progress = 0.05;
    });

    try {
      final outputPath = await ImageUtils.getOutputPath();
      final stitcher = StitcherService();

      final result = await stitcher.stitchImages(
        images: widget.images,
        outputPath: outputPath,
        outputWidth: 2048,
        outputHeight: 1024,
        onProgress: (msg, prog) {
          if (mounted) {
            setState(() {
              _status = msg;
              _progress = prog;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _status = 'Success! Opening 360 viewer...';
          _progress = 1.0;
          _isProcessing = false;
        });

        await Future.delayed(const Duration(milliseconds: 400));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PreviewScreen(imageFile: result),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
          _status = 'Stitching failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error == null) ...[
                const SpinKitCubeGrid(
                  color: Color(0xFF00D2C4),
                  size: 72,
                ),
                const SizedBox(height: 36),
                const Text(
                  'Stitching 360° Panorama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00D2C4)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF00D2C4),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF00D2C4), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'OpenCV is aligning ${widget.images.length} frames into a seamless spherical equirectangular panorama.',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Stitching Unsuccessful',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _startStitching,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
