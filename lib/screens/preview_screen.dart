import 'dart:io';
import 'package:flutter/material.dart';
import 'package:panorama_image/panorama_image.dart';
import 'result_screen.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;

  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  double _longitude = 0;
  double _latitude = 0;
  bool _isFlatView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 360 Viewer or Flat Image View
          if (!_isFlatView)
            PanoramaViewer(
              image: FileImage(widget.imageFile),
              onViewChanged: (details) {
                setState(() {
                  _longitude = details.longitude;
                  _latitude = details.latitude;
                });
              },
            )
          else
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '360° Interactive Viewer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Flat vs 360 toggle
                  IconButton(
                    icon: Icon(
                      _isFlatView ? Icons.threed_rotation : Icons.crop_original,
                      color: Colors.white70,
                    ),
                    tooltip: _isFlatView ? 'Switch to 360 Sphere' : 'Switch to Flat View',
                    onPressed: () {
                      setState(() {
                        _isFlatView = !_isFlatView;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls & Export Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isFlatView)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.explore, color: Color(0xFF00D2C4), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Yaw: ${_longitude.toStringAsFixed(0)}°  |  Pitch: ${_latitude.toStringAsFixed(0)}°',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _isFlatView ? 'Pinch to zoom, drag to pan' : 'Drag screen to look around in 360°',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(imageFile: widget.imageFile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_alt, size: 22),
                      label: const Text(
                        'Save & Export Panorama',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                      ),
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
}
