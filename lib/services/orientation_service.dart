import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class OrientationData {
  final double yaw; // Azimuth 0..360 degrees (increases when rotating right)
  final double pitch; // Tilt relative to horizon: 0° = vertical upright, + = tilt up to sky, - = tilt down to ground
  final double roll; // Left/right roll

  const OrientationData({
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  @override
  String toString() =>
      'Orientation(yaw: ${yaw.toStringAsFixed(1)}°, pitch: ${pitch.toStringAsFixed(1)}°, roll: ${roll.toStringAsFixed(1)}°)';
}

class OrientationService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final StreamController<OrientationData> _controller =
      StreamController<OrientationData>.broadcast();

  double _yaw = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;

  double _lastAx = 0.0;
  double _lastAy = 9.8;
  double _lastAz = 0.0;

  DateTime? _lastGyroTime;

  Stream<OrientationData> get onOrientationChanged => _controller.stream;
  OrientationData get current => OrientationData(yaw: _yaw, pitch: _pitch, roll: _roll);

  void start() {
    _accelSub = accelerometerEventStream().listen((event) {
      _lastAx = event.x;
      _lastAy = event.y;
      _lastAz = event.z;

      final norm = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (norm > 0.5) {
        // In Android portrait orientation:
        // When holding the phone upright facing the horizon: y ≈ +9.8 m/s², z ≈ 0 m/s².
        // Tilting backward (camera looks up at sky): z becomes positive (+z).
        // Tilting forward (camera looks down at ground): z becomes negative (-z).
        // Therefore, pitch relative to horizontal horizon is atan2(z, y):
        //   - Upright horizon: atan2(0, 9.8) = 0°
        //   - Tilting up +30°: atan2(>0, >0) = +30°
        //   - Tilting down -30°: atan2(<0, >0) = -30°
        final rawPitch = atan2(event.z, event.y) * (180.0 / pi);
        // Low-pass filter for smooth, jitter-free pitch
        _pitch = _pitch * 0.75 + rawPitch * 0.25;

        final rawRoll = atan2(event.x, sqrt(event.y * event.y + event.z * event.z)) * (180.0 / pi);
        _roll = _roll * 0.75 + rawRoll * 0.25;
      }
      _notify();
    });

    _gyroSub = gyroscopeEventStream().listen((event) {
      final now = DateTime.now();
      if (_lastGyroTime == null) {
        _lastGyroTime = now;
        return;
      }

      final dt = (now.difference(_lastGyroTime!).inMicroseconds) / 1000000.0;
      _lastGyroTime = now;

      if (dt > 0.001 && dt < 0.25) {
        // Project angular velocity onto gravity vector to get true vertical-axis rotation (yaw)
        final norm = sqrt(_lastAx * _lastAx + _lastAy * _lastAy + _lastAz * _lastAz);
        double yawRateRad = 0.0;

        if (norm > 1.0) {
          final gx = _lastAx / norm;
          final gy = _lastAy / norm;
          final gz = _lastAz / norm;
          // Dot product gives rotation around gravity direction
          yawRateRad = (event.x * gx + event.y * gy + event.z * gz);
        } else {
          // Fallback to Y-axis for upright portrait phone
          yawRateRad = event.y;
        }

        // In Android sensor coordinates with right-hand rule, turning body to the right (clockwise)
        // produces negative angular velocity around the +Y gravity axis.
        // We negate it so that rotating right INCREASES yaw (0° -> 45° -> 90° -> 135° -> ...).
        _yaw += (-yawRateRad * (180.0 / pi) * dt);

        // Normalize yaw to [0, 360)
        while (_yaw < 0) {
          _yaw += 360.0;
        }
        while (_yaw >= 360.0) {
          _yaw -= 360.0;
        }

        _notify();
      }
    });
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(OrientationData(yaw: _yaw, pitch: _pitch, roll: _roll));
    }
  }

  void resetYaw([double toAngle = 0.0]) {
    _yaw = toAngle;
    _notify();
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller.close();
  }
}
