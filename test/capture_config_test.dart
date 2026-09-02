import 'package:flutter_test/flutter_test.dart';
import 'package:picture360/models/capture_config.dart';

void main() {
  test('CaptureConfig default config', () {
    const config = CaptureConfig.defaultConfig;
    expect(config.photosPerRow, 10);
    expect(config.rowTiltAngles.length, 3);
    expect(config.totalPhotos, 30);
  });

  test('CaptureConfig horizontal360 config', () {
    const config = CaptureConfig.horizontal360;
    expect(config.photosPerRow, 8);
    expect(config.rowTiltAngles.length, 1);
    expect(config.totalPhotos, 8);
    expect(config.anglePerPhoto(0), 45.0);
  });

  test('CaptureConfig photosphere config', () {
    const config = CaptureConfig.photosphere;
    expect(config.photosPerRow, 8);
    expect(config.rowTiltAngles.length, 3);
    expect(config.totalPhotos, 24);
  });
}
