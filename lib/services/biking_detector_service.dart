import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service for detecting biking activity based on GPS speed.
/// Uses hysteresis/debounce to avoid flapping between states.
class BikingDetectorService extends ChangeNotifier {
  // Speed thresholds (m/s)
  static const double _bikingSpeedThresholdMs = 2.2; // ~8 km/h to start
  static const double _stopSpeedThresholdMs = 0.8; // ~3 km/h to stop

  // Debounce durations
  static const Duration _startDebounce = Duration(seconds: 10);
  static const Duration _stopDebounce = Duration(seconds: 30);

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  bool _isBikingDetected = false;
  bool get isBikingDetected => _isBikingDetected;

  double _currentSpeed = 0.0;
  double get currentSpeed => _currentSpeed;

  // Callbacks for biking start/stop events
  VoidCallback? onBikingStarted;
  VoidCallback? onBikingStopped;

  StreamSubscription<Position>? _positionSub;

  // Debounce state
  DateTime? _aboveThresholdSince;
  DateTime? _belowThresholdSince;

  /// Start monitoring GPS speed for biking detection
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isMonitoring = true;
    _isBikingDetected = false;
    _aboveThresholdSince = null;
    _belowThresholdSince = null;
    notifyListeners();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate, onError: (e) {
      debugPrint('BikingDetector GPS Error: $e');
    });
  }

  /// Stop monitoring GPS speed
  void stopMonitoring() {
    _positionSub?.cancel();
    _positionSub = null;
    _isMonitoring = false;
    _isBikingDetected = false;
    _aboveThresholdSince = null;
    _belowThresholdSince = null;
    notifyListeners();
  }

  void _onPositionUpdate(Position position) {
    _currentSpeed = position.speed >= 0 ? position.speed : 0;
    final now = DateTime.now();

    if (!_isBikingDetected) {
      // Not currently biking - check if we should start
      if (_currentSpeed >= _bikingSpeedThresholdMs) {
        _aboveThresholdSince ??= now;
        _belowThresholdSince = null;

        if (now.difference(_aboveThresholdSince!) >= _startDebounce) {
          _isBikingDetected = true;
          _aboveThresholdSince = null;
          notifyListeners();
          onBikingStarted?.call();
        }
      } else {
        _aboveThresholdSince = null;
      }
    } else {
      // Currently biking - check if we should stop
      if (_currentSpeed < _stopSpeedThresholdMs) {
        _belowThresholdSince ??= now;
        _aboveThresholdSince = null;

        if (now.difference(_belowThresholdSince!) >= _stopDebounce) {
          _isBikingDetected = false;
          _belowThresholdSince = null;
          notifyListeners();
          onBikingStopped?.call();
        }
      } else {
        _belowThresholdSince = null;
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
