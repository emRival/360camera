import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class OrientationData {
  final double yaw;
  final double pitch;
  final double roll;

  const OrientationData({this.yaw = 0, this.pitch = 0, this.roll = 0});
}

class OrientationService {
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  final StreamController<OrientationData> _controller =
      StreamController<OrientationData>.broadcast();

  double _yaw = 0;
  double _pitch = 0;
  double _roll = 0;

  Stream<OrientationData> get onOrientationChanged => _controller.stream;

  void start() {
    _accelSub = accelerometerEventStream().listen((event) {
      _pitch = atan2(-event.y, sqrt(event.x * event.x + event.z * event.z)) *
          (180 / pi);
      _roll = atan2(event.x, sqrt(event.y * event.y + event.z * event.z)) *
          (180 / pi);
      _notify();
    });

    _gyroSub = gyroscopeEventStream().listen((event) {
      _yaw += event.z * (180 / pi) * 0.016;
      if (_yaw > 360) _yaw -= 360;
      if (_yaw < 0) _yaw += 360;
      _notify();
    });
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(OrientationData(yaw: _yaw, pitch: _pitch, roll: _roll));
    }
  }

  void resetYaw() {
    _yaw = 0;
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller.close();
  }
}
