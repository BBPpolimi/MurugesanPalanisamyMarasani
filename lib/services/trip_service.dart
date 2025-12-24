import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/gps_point.dart';
import '../models/trip.dart';
import 'trip_repository.dart';


class TripSummary {
  final double distanceMeters;
  final Duration duration;
  final double averageSpeed;

  TripSummary({required this.distanceMeters, required this.duration, required this.averageSpeed});
}

class TripService extends ChangeNotifier {
  bool _recording = false;
  bool get recording => _recording;

  final List<GpsPoint> _points = [];
  List<GpsPoint> get points => List.unmodifiable(_points);

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  DateTime? _startTime;

  TripSummary? lastSummary;
  
  final TripRepository _repository = TripRepository();
  final _uuid = const Uuid();

  List<Trip> get trips => _repository.getAllTrips();

  Future<void> startRecording() async {
    if (_recording) return;

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

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5, timeLimit: null),
    ).listen((pos) {
      _points.add(GpsPoint(latitude: pos.latitude, longitude: pos.longitude, elevation: pos.altitude, timestamp: DateTime.now()));
      notifyListeners();
    });

    // accelerometer for candidate detection (simple logging now)
    _accelSub = accelerometerEvents.listen((event) {
      // simple: if z-axis spike beyond threshold register candidate event (we'll leave actual detection to later)
      // print('accel: ${event.x}, ${event.y}, ${event.z}');
    });

    _recording = true;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_recording) return;

    _positionSub?.cancel();
    _accelSub?.cancel();
    _positionSub = null;
    _accelSub = null;

    final endTime = DateTime.now();
    final duration = _startTime == null ? Duration.zero : endTime.difference(_startTime!);

    double distance = 0.0;
    for (int i = 1; i < _points.length; i++) {
      final prev = _points[i - 1];
      final cur = _points[i];
      distance += Geolocator.distanceBetween(prev.latitude, prev.longitude, cur.latitude, cur.longitude);
    }

    final avgSpeed = duration.inSeconds > 0 ? (distance / duration.inSeconds) : 0.0; // m/s

    lastSummary = TripSummary(distanceMeters: distance, duration: duration, averageSpeed: avgSpeed);

    final trip = Trip(
      id: _uuid.v4(),
      startTime: _startTime!,
      endTime: endTime,
      points: List.from(_points),
      distanceMeters: distance,
      duration: duration,
      averageSpeed: avgSpeed,
    );

    _repository.saveTrip(trip);
    lastSummary = TripSummary(
      distanceMeters: distance,
      duration: duration,
      averageSpeed: avgSpeed,
    );

    _recording = false;
    notifyListeners();
  }

  void clear() {
    _points.clear();
    lastSummary = null;
    notifyListeners();
  }
}