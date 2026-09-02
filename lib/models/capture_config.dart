enum CaptureMode {
  horizontal360,
  photosphere360,
  wide180,
}

class CaptureConfig {
  final int photosPerRow;
  final List<double> rowTiltAngles;
  final double overlapFactor;
  final CaptureMode mode;
  final String title;
  final String description;

  const CaptureConfig({
    this.photosPerRow = 10,
    this.rowTiltAngles = const [-30.0, 0.0, 30.0],
    this.overlapFactor = 1.2,
    this.mode = CaptureMode.photosphere360,
    this.title = 'Full Sphere 360°',
    this.description = 'Complete spherical coverage with 3 rows of photos',
  });

  int get totalPhotos => photosPerRow * rowTiltAngles.length;

  int get totalRows => rowTiltAngles.length;

  double anglePerPhoto(int row) => 360.0 / photosPerRow;

  static const defaultConfig = CaptureConfig();

  static const horizontal360 = CaptureConfig(
    photosPerRow: 8,
    rowTiltAngles: [0.0],
    overlapFactor: 1.2,
    mode: CaptureMode.horizontal360,
    title: '360° Horizontal',
    description: 'Fast 360° panorama around a single horizontal ring (8 photos)',
  );

  static const photosphere = CaptureConfig(
    photosPerRow: 8,
    rowTiltAngles: [-25.0, 0.0, 25.0],
    overlapFactor: 1.2,
    mode: CaptureMode.photosphere360,
    title: 'Full Sphere 360°',
    description: 'Full spherical photosphere with 3 tilt levels (24 photos)',
  );

  static const wide180 = CaptureConfig(
    photosPerRow: 5,
    rowTiltAngles: [0.0],
    overlapFactor: 1.2,
    mode: CaptureMode.wide180,
    title: '180° Ultra-Wide',
    description: 'Wide panorama sweep (5 photos)',
  );
}
