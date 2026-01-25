import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';



import '../models/candidate_issue.dart';
import '../models/gps_point.dart';
import '../models/trip.dart';
import '../models/trip_state.dart';
import 'trip_repository.dart';

class TripSummary {
  final double distanceMeters;
  final Duration duration;
  final double averageSpeed;

  TripSummary({required this.distanceMeters, required this.duration, required this.averageSpeed});
}

class TripService extends ChangeNotifier {
  TripState _state = TripState.idle;
  TripState get state => _state;
  
  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  final List<GpsPoint> _points = [];
  List<GpsPoint> get points => List.unmodifiable(_points);

  // F6: Auto-detection fields
  bool _isAutoDetectionEnabled = false;
  bool get isAutoDetectionEnabled => _isAutoDetectionEnabled;
  
  final List<CandidateIssue> _candidates = [];
  List<CandidateIssue> get candidates => List.unmodifiable(_candidates);

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub; // Use UserAccelerometer to filter gravity

  DateTime? _startTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime; 

  TripSummary? lastSummary;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double? _currentAccuracy;
  double? get currentAccuracy => _currentAccuracy;

  final TripRepository _repository;
  final Uuid _uuid = const Uuid();

  // Debounce for anomaly detection
  DateTime? _lastAnomalyTime;

  TripService({TripRepository? repository}) 
      : _repository = repository ?? TripRepository();

  void initialize(String userId) {
    _repository.initialize(userId);
  }
  
  void toggleAutoDetection(bool enabled) {
    _isAutoDetectionEnabled = enabled;
    notifyListeners();
  }

  Future<List<Trip>> get trips => _repository.getAllTrips();
  Stream<List<Trip>> get tripsStream => _repository.watchTrips();

  Future<void> startRecording() async {
    if (_state == TripState.recording || _state == TripState.paused || _isInitializing) return;
    
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
        if (permission == LocationPermission.denied) throw Exception('Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      _points.clear();
      _candidates.clear(); // Clear old candidates
      _startTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;

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

  Future<void> stopRecording() async {
    if (_state != TripState.recording && _state != TripState.paused) return;

    _state = TripState.processing;
    notifyListeners();

    _stopStreams();
    
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    final endTime = DateTime.now();
    final rawDuration = _startTime == null ? Duration.zero : endTime.difference(_startTime!);
    final activeDuration = rawDuration - _pausedDuration;

    double distance = 0.0;
    for (int i = 1; i < _points.length; i++) {
      final prev = _points[i - 1];
      final cur = _points[i];
      distance += Geolocator.distanceBetween(prev.latitude, prev.longitude, cur.latitude, cur.longitude);
    }

    final durationSeconds = activeDuration.inSeconds > 0 ? activeDuration.inSeconds : 0;
    final avgSpeed = durationSeconds > 0 ? (distance / durationSeconds) : 0.0;

    final summary = TripSummary(distanceMeters: distance, duration: activeDuration, averageSpeed: avgSpeed);
    lastSummary = summary;

    final trip = Trip(
      id: _uuid.v4(),
      startTime: _startTime!,
      endTime: endTime,
      points: List.from(_points),
      distanceMeters: distance,
      duration: activeDuration,
      averageSpeed: avgSpeed,
    );

    // Save trip
    await _repository.saveTrip(trip);
    
    // NOTE: Candidates are kept in memory for the 'Review' screen, which should come after 'Stop'.
    // Ideally, we persist them too, but for this MVP we pass them to the UI.

    _state = TripState.saved;
    notifyListeners();
  }

  void clear() {
    _points.clear();
    _candidates.clear();
    lastSummary = null;
    _resetError();
    _state = TripState.idle;
    notifyListeners();
  }

  void retry() {
    if (_state == TripState.error) {
       clear();
    }
  }

  void _resetError() {
    _errorMessage = null;
  }

  void _startStreams() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) {
      _currentAccuracy = pos.accuracy;
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

    // F6: Auto-detection logic
    if (_isAutoDetectionEnabled) {
      _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        _processAccelerometerEvent(event);
      });
    }
  }

  void _processAccelerometerEvent(UserAccelerometerEvent event) {
    // Simple magnitude check
    // UserAccelerometerEvent removes gravity, so we look for spikes.
    // Threshold: 2.0g (approx 20 m/s^2)? No, event is usually in m/s^2.
    // 1g ~ 9.8. A pothole might cause a sharp spike.
    // Let's retry threshold of 5.0 m/s^2 for a significant bump.
    
    final magnitude = (event.x.abs() + event.y.abs() + event.z.abs()); // Simple approximation or use sqrt
    const double threshold = 8.0; 

    if (magnitude > threshold) {
      final now = DateTime.now();
      // Debounce: ignore if we just detected something < 2 seconds ago
      if (_lastAnomalyTime != null && now.difference(_lastAnomalyTime!) < const Duration(seconds: 2)) {
        return;
      }
      _lastAnomalyTime = now;

      // Create candidate if we have a recent location
      if (_points.isNotEmpty) {
        final lastPoint = _points.last;
        // Verify location freshness (< 10 seconds old)
        if (now.difference(lastPoint.timestamp).inSeconds < 10) {
             final candidate = CandidateIssue(
               id: _uuid.v4(),
               userId: 'current_user', // Will be enriched later or handled by UI
               lat: lastPoint.latitude,
               lng: lastPoint.longitude,
               sensorSnapshot: [event.x, event.y, event.z],
               confidenceScore: 0.8, // Static for now
               timestamp: now,
               status: CandidateStatus.pending,
             );
             _candidates.add(candidate);
             // notifyListeners(); // Optional: if we want to show a counter in real-time
        }
      }
    }
  }

  void _stopStreams() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _positionSub = null;
    _accelSub = null;
  }
}