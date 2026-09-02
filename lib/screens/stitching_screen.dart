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
  String _status = 'Preparing images...';
  double _progress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startStitching();
  }

  Future<void> _startStitching() async {
    try {
      setState(() {
        _status = 'Stitching ${widget.images.length} images...';
        _progress = 0.2;
      });

      final outputPath = await ImageUtils.getOutputPath();
      final stitcher = StitcherService();

      setState(() {
        _status = 'Processing panorama...';
        _progress = 0.5;
      });

      final result = await stitcher.stitchImages(
        images: widget.images,
        outputPath: outputPath,
        outputWidth: 4096,
        outputHeight: 2048,
      );

      setState(() {
        _status = 'Stitching complete!';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(imageFile: result),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Stitching failed: $e';
        _status = 'Error occurred';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error == null) ...[
                const SpinKitFoldingCube(
                  color: Color(0xFF1A73E8),
                  size: 80,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Creating your 360° panorama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1A73E8)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Processing ${widget.images.length} images into a 360° panoramic photo. This may take a few moments.',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Oops!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      child: const Text('Go Back'),
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
