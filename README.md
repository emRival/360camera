# 360 Picture

A Flutter app to capture 360-degree panoramic photos and export as equirectangular PNG images.

## Features

- **Multi-row capture**: 3 rows (top, middle, bottom) × 10 photos = 30 images
- **Guided capture**: On-screen dots guide you through the rotation
- **Auto stitching**: Uses OpenCV to stitch images into a panorama
- **360° preview**: View the result with a panorama viewer
- **PNG export**: Save as equirectangular PNG (4096×2048)

## Requirements

- Flutter 3.24.0+
- Android SDK 21+
- Camera permission
- Storage permission

## Build

```bash
flutter pub get
flutter build apk --release
```

## GitHub Actions

The app automatically builds APK on push to `main` or `develop` branches.

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── capture_screen.dart
│   ├── stitching_screen.dart
│   ├── preview_screen.dart
│   └── result_screen.dart
├── services/
│   ├── camera_service.dart
│   ├── orientation_service.dart
│   └── stitcher_service.dart
├── models/
│   └── capture_config.dart
└── utils/
    └── image_utils.dart
```
