import 'dart:io';
import 'dart:math';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:image/image.dart' as img;

class StitcherService {
  Future<File> stitchImages({
    required List<File> images,
    required String outputPath,
    int outputWidth = 4096,
    int outputHeight = 2048,
  }) async {
    final mats = <cv.Mat>[];

    try {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final dartImage = img.decodeImage(bytes);
        if (dartImage == null) continue;

        final mat = cv.Mat.fromBYTES(
          dartImage.height,
          dartImage.width,
          dartImage.channels == 4 ? cv.CV_8UC4 : cv.CV_8UC3,
          bytes: bytes,
        );
        mats.add(mat);
      }

      if (mats.length < 2) {
        throw Exception('Need at least 2 images to stitch');
      }

      final stitcher = cv.Stitcher.create(mode: cv.StitcherMode_PANORAMA);
      final pano = cv.Mat();
      final status = stitcher.stitch(mats, pano);

      if (status != cv.Stitcher_OK) {
        throw Exception('Stitching failed with status: $status');
      }

      final equirect = _projectToEquirectangular(pano, outputWidth, outputHeight);

      final pngBytes = cv.imencode('.png', equirect);
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(pngBytes);

      pano.dispose();
      equirect.dispose();
      stitcher.dispose();

      return outputFile;
    } finally {
      for (final mat in mats) {
        mat.dispose();
      }
    }
  }

  cv.Mat _projectToEquirectangular(cv.Mat panorama, int width, int height) {
    final result = cv.Mat.zeros(height, width, cv.CV_8UC3);
    final srcRows = panorama.rows;
    final srcCols = panorama.cols;

    final double thetaMax = pi;
    final double phiMax = pi / 2;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final double theta = (x / width) * 2 * thetaMax - thetaMax;
        final double phi = (y / height) * phiMax - phiMax / 2;

        final double srcX = (theta / pi + 1.0) * 0.5 * srcCols;
        final double srcY = (0.5 - phi / pi) * srcRows;

        final int srcXi = srcX.clamp(0, srcCols - 1).toInt();
        final int srcYi = srcY.clamp(0, srcRows - 1).toInt();

        final pixel = panorama.at<Vec3b>(srcYi, srcXi);
        result.set(y, x, pixel);
      }
    }

    return result;
  }
}
