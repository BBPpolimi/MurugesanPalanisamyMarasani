import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/candidate_issue.dart';
import '../models/gps_point.dart';
import '../models/trip.dart';
import '../models/trip_state.dart';
import '../models/weather_data.dart';
import 'biking_detector_service.dart';
import 'trip_repository.dart';
import 'weather_service.dart';

class TripSummary {
  final double distanceMeters;
  final Duration duration;
  final double averageSpeed;

  TripSummary(
      {required this.distanceMeters,
      required this.duration,
      required this.averageSpeed});
}

class TripService extends ChangeNotifier {
  TripState _state = TripState.idle;
  TripState get state => _state;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  final List<GpsPoint> _points = [];
  List<GpsPoint> get points => List.unmodifiable(_points);

  // Auto-detection fields
  bool _isAutoDetectionEnabled = false;
  bool get isAutoDetectionEnabled => _isAutoDetectionEnabled;

  bool _isAutoDetectedTrip = false;
  bool get isAutoDetectedTrip => _isAutoDetectedTrip;

  final List<CandidateIssue> _candidates = [];
  List<CandidateIssue> get candidates => List.unmodifiable(_candidates);

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  DateTime? _startTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  // Current trip ID for linking candidates
  String? _currentTripId;
  String? get currentTripId => _currentTripId;

  TripSummary? lastSummary;
  Trip? lastSavedTrip;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double? _currentAccuracy;
  double? get currentAccuracy => _currentAccuracy;

  double _currentSpeed = 0.0;
  double get currentSpeed => _currentSpeed;

  final TripRepository _repository;
  final Uuid _uuid = const Uuid();
  final WeatherService _weatherService = WeatherService();

  // Biking detector for auto-start/stop
  BikingDetectorService? _bikingDetector;

  // Debounce for anomaly detection
  DateTime? _lastAnomalyTime;

  // Latest gyroscope reading for sensor fusion
  List<double> _lastGyroReading = [0, 0, 0];

  // User ID for trip ownership
  String? _userId;

  TripService({TripRepository? repository})
      : _repository = repository ?? TripRepository();

  void initialize(String userId) {
    _userId = userId;
    _repository.initialize(userId);
  }

  /// Enable/disable auto-detection mode.
  /// When enabled, monitors GPS speed and auto-starts/stops recording.
  Future<void> toggleAutoDetection(bool enabled) async {
    _isAutoDetectionEnabled = enabled;

    if (enabled) {
      await _startAutoMonitoring();
    } else {
      _stopAutoMonitoring();
    }

    notifyListeners();
  }

  Future<void> _startAutoMonitoring() async {
    if (_state != TripState.idle) return;

    _bikingDetector = BikingDetectorService();
    _bikingDetector!.onBikingStarted = _onBikingDetected;
    _bikingDetector!.onBikingStopped = _onBikingStopped;

    try {
      await _bikingDetector!.startMonitoring();
      _state = TripState.autoMonitoring;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = TripState.error;
      notifyListeners();
    }
  }

  void _stopAutoMonitoring() {
    _bikingDetector?.stopMonitoring();
    _bikingDetector = null;
    if (_state == TripState.autoMonitoring) {
      _state = TripState.idle;
      notifyListeners();
    }
  }

  void _onBikingDetected() {
    // Auto-start recording when biking is detected
    _isAutoDetectedTrip = true;
    startRecording();
  }

  void _onBikingStopped() {
    // Auto-stop recording when biking stops
    if (_state == TripState.recording || _state == TripState.paused) {
      stopRecording();
    }
  }

  Future<List<Trip>> get trips => _repository.getAllTrips();
  Stream<List<Trip>> get tripsStream => _repository.watchTrips();

  Future<void> startRecording() async {
    if (_state == TripState.recording ||
        _state == TripState.paused ||
        _isInitializing) return;

    _isInitializing = true;
    notifyListeners();
    _resetError();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      _points.clear();
      _candidates.clear();
      _currentTripId = _uuid.v4();
      _startTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;
      _lastGyroReading = [0, 0, 0];

      _startStreams();

      _state = TripState.recording;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = TripState.error;
      notifyListeners();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void pauseRecording() {
    if (_state != TripState.recording) return;

    _stopStreams();
    _pauseStartTime = DateTime.now();
    _state = TripState.paused;
    notifyListeners();
  }

  void resumeRecording() {
    if (_state != TripState.paused) return;

    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    _startStreams();
    _state = TripState.recording;
    notifyListeners();
  }

  Future<void> stopRecording({String? tripName}) async {
    if (_state != TripState.recording && _state != TripState.paused) return;

    _state = TripState.processing;
    notifyListeners();

    _stopStreams();

    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    final endTime = DateTime.now();
    final rawDuration =
        _startTime == null ? Duration.zero : endTime.difference(_startTime!);
    final activeDuration = rawDuration - _pausedDuration;

    double distance = 0.0;
    for (int i = 1; i < _points.length; i++) {
      final prev = _points[i - 1];
      final cur = _points[i];
      distance += Geolocator.distanceBetween(
          prev.latitude, prev.longitude, cur.latitude, cur.longitude);
    }

    final durationSeconds =
        activeDuration.inSeconds > 0 ? activeDuration.inSeconds : 0;
    final avgSpeed = durationSeconds > 0 ? (distance / durationSeconds) : 0.0;

    final summary = TripSummary(
        distanceMeters: distance,
        duration: activeDuration,
        averageSpeed: avgSpeed);
    lastSummary = summary;

    // Fetch weather data (optional enrichment)
    WeatherData? weatherData;
    if (_points.isNotEmpty) {
      final midPoint = _points[_points.length ~/ 2];
      weatherData = await _weatherService.getWeather(
          midPoint.latitude, midPoint.longitude);
    }

    final trip = Trip(
      id: _currentTripId ?? _uuid.v4(),
      userId: _userId ?? '',
      name: tripName,
      startTime: _startTime!,
      endTime: endTime,
      points: List.from(_points),
      distanceMeters: distance,
      duration: activeDuration,
      averageSpeed: avgSpeed,
      isAutoDetected: _isAutoDetectedTrip,
      weatherData: weatherData,
    );

    // Save trip
    await _repository.saveTrip(trip);
    lastSavedTrip = trip;

    // Save candidates linked to this trip
    if (_candidates.isNotEmpty) {
      await _repository.saveCandidates(_currentTripId!, _candidates);
    }

    // Reset auto-detected flag
    _isAutoDetectedTrip = false;

    _state = TripState.saved;

    // If auto-detection was on, go back to monitoring ONLY if no review needed
    if (_isAutoDetectionEnabled && _candidates.isEmpty) {
      _state = TripState.autoMonitoring;
      _startAutoMonitoring();
    }

    notifyListeners();
  }

  void clear() {
    _points.clear();
    _candidates.clear();
    lastSummary = null;
    lastSavedTrip = null;
    _currentTripId = null;
    _resetError();
    _state =
        _isAutoDetectionEnabled ? TripState.autoMonitoring : TripState.idle;

    if (_isAutoDetectionEnabled) {
      _startAutoMonitoring();
    }

    notifyListeners();
  }

  void retry() {
    if (_state == TripState.error) {
      clear();
    }
  }

  Future<void> deleteTrip(String tripId) async {
    await _repository.deleteTrip(tripId);
  }

  Future<void> renameTrip(Trip trip, String newName) async {
    final updatedTrip = trip.copyWith(name: newName);
    await _repository.saveTrip(updatedTrip);
  }

  /// Update trip's publishable status
  Future<void> setTripPublishable(String tripId, bool isPublishable) async {
    await _repository.updateTripPublishable(tripId, isPublishable);
  }

  /// Get candidates for a specific trip
  Future<List<CandidateIssue>> getCandidatesForTrip(String tripId) async {
    return await _repository.getCandidates(tripId);
  }

  /// Update a candidate's status (confirm/reject)
  Future<void> updateCandidateStatus(
      String tripId, CandidateIssue candidate) async {
    await _repository.updateCandidate(tripId, candidate);
  }

  void _resetError() {
    _errorMessage = null;
  }

  // Method to manually restart monitoring if needed (safeguard)
  void restartMonitoring() {
    if (_isAutoDetectionEnabled &&
        (_state == TripState.idle || _state == TripState.saved)) {
      _state = TripState.autoMonitoring;
      _startAutoMonitoring();
    }
  }

  void _startStreams() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) {
      _currentAccuracy = pos.accuracy;
      _currentSpeed = pos.speed >= 0 ? pos.speed : 0;

      if (pos.accuracy > 20.0) {
        notifyListeners();
        return;
      }
      _points.add(GpsPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        elevation: pos.altitude,
        accuracyMeters: pos.accuracy,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    }, onError: (e) {
      _errorMessage = 'GPS Error: $e';
      _state = TripState.error;
      _stopStreams();
      notifyListeners();
    });

    // Always start sensor streams for obstacle detection
    _accelSub =
        userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      _processSensorEvent(event);
    });

    // Gyroscope stream for enhanced detection
    _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _lastGyroReading = [event.x, event.y, event.z];
    });
  }

  void _processSensorEvent(UserAccelerometerEvent event) {
    // Combined sensor fusion: accelerometer magnitude + gyroscope angular velocity
    // Higher values indicate more violent motion -> more likely pothole

    final accelMagnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    final gyroMagnitude = math.sqrt(_lastGyroReading[0] * _lastGyroReading[0] +
        _lastGyroReading[1] * _lastGyroReading[1] +
        _lastGyroReading[2] * _lastGyroReading[2]);

    // Combined score: accelerometer spike + rotational motion
    // Pothole typically causes both vertical acceleration AND rotation
    final combinedScore = accelMagnitude + (gyroMagnitude * 0.5);

    // Threshold tuned for biking scenarios
    const double threshold = 10.0;

    if (combinedScore > threshold) {
      final now = DateTime.now();
      // Debounce: ignore if we just detected something < 2 seconds ago
      if (_lastAnomalyTime != null &&
          now.difference(_lastAnomalyTime!) < const Duration(seconds: 2)) {
        return;
      }
      _lastAnomalyTime = now;

      // Create candidate if we have a recent location
      if (_points.isNotEmpty) {
        final lastPoint = _points.last;
        // Verify location freshness (< 10 seconds old)
        if (now.difference(lastPoint.timestamp).inSeconds < 10) {
          // Calculate confidence based on sensor magnitude
          final confidence = (combinedScore / 20.0).clamp(0.5, 1.0);

          final candidate = CandidateIssue(
            id: _uuid.v4(),
            tripId: _currentTripId ?? '',
            userId: _userId ?? '',
            lat: lastPoint.latitude,
            lng: lastPoint.longitude,
            sensorSnapshot: [event.x, event.y, event.z],
            gyroSnapshot: List.from(_lastGyroReading),
            confidenceScore: confidence,
            timestamp: now,
            status: CandidateStatus.pending,
          );
          _candidates.add(candidate);
          notifyListeners(); // Notify for real-time counter
        }
      }
    }
  }

  void _stopStreams() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _positionSub = null;
    _accelSub = null;
    _gyroSub = null;
  }

  @override
  void dispose() {
    _stopStreams();
    _stopAutoMonitoring();
    super.dispose();
  }
}
