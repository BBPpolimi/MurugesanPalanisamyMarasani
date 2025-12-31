import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';



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

  final List<GpsPoint> _points = [];
  List<GpsPoint> get points => List.unmodifiable(_points);

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  DateTime? _startTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime; // To track current pause interval

  TripSummary? lastSummary;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double? _currentAccuracy;
  double? get currentAccuracy => _currentAccuracy;

  final TripRepository _repository = TripRepository();
  final _uuid = const Uuid();

  List<Trip> get trips => _repository.getAllTrips();

  Future<void> startRecording() async {
    if (_state == TripState.recording || _state == TripState.paused) return;
    
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

    // Transition to processing
    _state = TripState.processing;
    notifyListeners();

    _stopStreams();
    
    // Handle pending pause duration if we were paused
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

    // prevent negative duration or division by zero
    final durationSeconds = activeDuration.inSeconds > 0 ? activeDuration.inSeconds : 0;
    final avgSpeed = durationSeconds > 0 ? (distance / durationSeconds) : 0.0; // m/s

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

    _repository.saveTrip(trip);

    _state = TripState.saved;
    notifyListeners();
  }

  void clear() {
    _points.clear();
    lastSummary = null;
    _resetError();
    _state = TripState.idle;
    notifyListeners();
  }

  void retry() {
    // Allows user to try starting again from error state
    if (_state == TripState.error) {
       // Just reset state to idle so they can press start again
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
      
      // Accuracy filter: reject points with accuracy > 20 meters (if available)
      // Note: pos.accuracy is in meters. Lower is better.
      if (pos.accuracy > 20.0) {
        notifyListeners(); // Notify so UI can show poor accuracy
        return;
      }
      
      _points.add(GpsPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        elevation: pos.altitude,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    }, onError: (e) {
      _errorMessage = 'GPS Error: $e';
      _state = TripState.error;
      _stopStreams();
      notifyListeners();
    });

    _accelSub = accelerometerEventStream().listen((event) {
      // simple accelerometer logging/processing
    });
  }

  void _stopStreams() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _positionSub = null;
    _accelSub = null;
  }
}