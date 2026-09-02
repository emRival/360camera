import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('No cameras found', 'No cameras available on device');
    }

    final backCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    _isInitialized = true;
  }

  Future<XFile> takePicture() async {
    if (_controller == null || !_isInitialized) {
      throw CameraException('Camera not initialized', 'Camera is not ready');
    }

    final XFile file = await _controller!.takePicture();
    return file;
  }

  Future<void> dispose() async {
    _isInitialized = false;
    await _controller?.dispose();
    _controller = null;
  }
}
