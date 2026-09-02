import 'package:flutter_test/flutter_test.dart';
import 'package:picture360/models/capture_config.dart';

void main() {
  test('CaptureConfig default config', () {
    const config = CaptureConfig.defaultConfig;
    expect(config.photosPerRow, 10);
    expect(config.rowTiltAngles.length, 3);
    expect(config.totalPhotos, 30);
  });
}
