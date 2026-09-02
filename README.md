# 360 Picture 📸🌐

A modern Flutter Android app to capture 360-degree panoramic and spherical photosphere photos with real-time sensor alignment guidance, OpenCV stitching, and interactive 360° VR viewing.

## Features

- **Multiple Capture Modes**:
  - **360° Horizontal** (8 photos, 1 ring, fast & reliable)
  - **Full Sphere Photosphere** (24 photos, 3 tilt levels: -25°, 0°, +25°)
  - **180° Ultra-Wide Sweep** (5 photos)
- **Interactive Sensor Guidance**:
  - Center reticle crosshair with target dots tracking device orientation in real-time
  - Directional guidance indicators pointing where to rotate / tilt
  - Automatic frame capture when aligned with green confirmation
  - Manual shutter, undo last shot, and finish-early stitching support
- **High-Performance OpenCV Stitching**:
  - Accelerated feature matching and blending
  - Automatic downscaling optimization to prevent mobile OOM
  - Fallback alignment modes (Panorama & Scans)
  - Equirectangular 2:1 PNG projection
- **Interactive 360° Viewer**:
  - Spherical 360° touch drag and zoom
  - Gyroscope sensor look-around mode
  - Flat panoramic view toggle
- **Local Gallery History**:
  - Access previously captured 360° panoramas directly from the home screen
  - Save to system gallery via modern storage APIs

## Requirements

- Flutter 3.24+ / 3.47+
- Android SDK 26+ (Android 8.0 Oreo or newer)
- Camera & Gyroscope hardware support

## Building Locally

```bash
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

## GitHub Actions Automated Build

Every push to `main` automatically triggers the GitHub Actions workflow to:
1. Verify dependencies and run tests
2. Build optimized release APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
3. Upload APK artifacts and publish an automated GitHub Release with downloadable APKs.
