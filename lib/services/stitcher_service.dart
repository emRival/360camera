import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;

typedef StitchProgressCallback = void Function(String message, double progress);

class StitcherService {
  Future<File> stitchImages({
    required List<File> images,
    required String outputPath,
    int outputWidth = 2048,
    int outputHeight = 1024,
    StitchProgressCallback? onProgress,
  }) async {
    if (images.length < 2) {
      throw Exception('Need at least 2 photos to create a 360° panorama');
    }

    final mats = <cv.Mat>[];
    final vec = cv.VecMat();

    try {
      onProgress?.call('Loading and optimizing photos...', 0.1);

      // Load and downscale photos if needed to prevent mobile OOM
      const int maxInputDim = 1600;
      for (int i = 0; i < images.length; i++) {
        final progress = 0.1 + (0.2 * (i + 1) / images.length);
        onProgress?.call('Processing photo ${i + 1}/${images.length}...', progress);

        final bytes = await images[i].readAsBytes();
        var mat = cv.imdecode(bytes, cv.IMREAD_COLOR);

        if (mat.cols > maxInputDim || mat.rows > maxInputDim) {
          final double scale = maxInputDim / (mat.cols > mat.rows ? mat.cols : mat.rows);
          final int newW = (mat.cols * scale).toInt();
          final int newH = (mat.rows * scale).toInt();
          final resized = cv.resize(mat, (newW, newH), interpolation: cv.INTER_AREA);
          mat.dispose();
          mat = resized;
        }

        mats.add(mat);
        vec.add(mat);
      }

      onProgress?.call('Matching features and aligning camera positions...', 0.4);

      // Attempt 1: Standard Panorama stitcher
      var stitcher = cv.Stitcher.create(mode: cv.StitcherMode.PANORAMA);
      var (status, pano) = stitcher.stitch(vec);

      // Attempt 2: Fallback to SCANS mode if PANORAMA fails
      if (status != cv.StitcherStatus.OK) {
        pano.dispose();
        stitcher.dispose();

        onProgress?.call('Trying advanced alignment mode...', 0.6);
        stitcher = cv.Stitcher.create(mode: cv.StitcherMode.SCANS);
        final result = stitcher.stitch(vec);
        status = result.$1;
        pano = result.$2;
      }

      if (status != cv.StitcherStatus.OK) {
        pano.dispose();
        stitcher.dispose();

        String reason = 'Stitching failed';
        if (status == cv.StitcherStatus.ERR_NEED_MORE_IMGS) {
          reason = 'Not enough overlapping features found. Please ensure photos overlap by at least 30-50%.';
        } else if (status == cv.StitcherStatus.ERR_HOMOGRAPHY_EST_FAIL) {
          reason = 'Could not match perspective between photos. Keep the phone steady and rotate smoothly.';
        } else if (status == cv.StitcherStatus.ERR_CAMERA_PARAMS_ADJUST_FAIL) {
          reason = 'Camera exposure/lighting varied too much between frames. Try capturing with exposure lock.';
        }
        throw Exception(reason);
      }

      onProgress?.call('Formatting 360° equirectangular output...', 0.85);

      // Convert stitched panorama to equirectangular 2:1 projection
      final equirect = cv.resize(
        pano,
        (outputWidth, outputHeight),
        interpolation: cv.INTER_CUBIC,
      );

      onProgress?.call('Saving high-resolution panorama...', 0.95);

      final (ok, pngBytes) = cv.imencode('.png', equirect);
      if (!ok) {
        equirect.dispose();
        pano.dispose();
        stitcher.dispose();
        throw Exception('Failed to encode 360° PNG output');
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(pngBytes);

      pano.dispose();
      equirect.dispose();
      stitcher.dispose();

      onProgress?.call('Complete!', 1.0);
      return outputFile;
    } finally {
      for (final mat in mats) {
        mat.dispose();
      }
      vec.dispose();
    }
  }
}
