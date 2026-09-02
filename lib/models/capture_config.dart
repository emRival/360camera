class CaptureConfig {
  final int photosPerRow;
  final List<double> rowTiltAngles;
  final double overlapFactor;

  const CaptureConfig({
    this.photosPerRow = 10,
    this.rowTiltAngles = const [-30.0, 0.0, 30.0],
    this.overlapFactor = 1.2,
  });

  int get totalPhotos => photosPerRow * rowTiltAngles.length;

  int get totalRows => rowTiltAngles.length;

  double anglePerPhoto(int row) => 360.0 / photosPerRow;

  static const defaultConfig = CaptureConfig();
}
