import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  bool _isExposureLocked = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  FlashMode get flashMode => _flashMode;
  bool get isExposureLocked => _isExposureLocked;

  Future<void> initialize({ResolutionPreset preset = ResolutionPreset.high}) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('No cameras found', 'No cameras available on device');
    }

    final backCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      backCamera,
      preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();

    try {
      await controller.setFlashMode(_flashMode);
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {
      // Some devices may not support these settings
    }

    _controller = controller;
    _isInitialized = true;
  }

  Future<File> takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw CameraException('Camera not initialized', 'Camera is not ready');
    }

    final XFile file = await ctrl.takePicture();
    return File(file.path);
  }

  Future<void> toggleFlash() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final newMode = _flashMode == FlashMode.off
        ? FlashMode.auto
        : (_flashMode == FlashMode.auto ? FlashMode.torch : FlashMode.off);

    try {
      await ctrl.setFlashMode(newMode);
      _flashMode = newMode;
    } catch (_) {}
  }

  Future<void> toggleExposureLock() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      if (_isExposureLocked) {
        await ctrl.setExposureMode(ExposureMode.auto);
        _isExposureLocked = false;
      } else {
        await ctrl.setExposureMode(ExposureMode.locked);
        _isExposureLocked = true;
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    _isInitialized = false;
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      await ctrl.dispose();
    }
  }
}
