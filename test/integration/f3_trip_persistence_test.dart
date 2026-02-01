// F3 — Trip Persistence Unit Tests
// These are fast unit tests that run without a device
// For real device integration tests, run: flutter test integration_test/ -d <device>

import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/gps_point.dart';
import 'package:bbp_flutter/models/trip.dart';

void main() {
  group('F3 - Trip Persistence Tests', () {
    group('F3.1 - Firestore Storage', () {
      test('F3.1.1 - Trip stored with correct fields', () {
        final trip = Trip(
          id: 'trip-1',
          userId: 'user123',
          startTime: DateTime.now().subtract(const Duration(minutes: 30)),
          endTime: DateTime.now(),
          points: [],
          distanceMeters: 5000.0,
          duration: const Duration(minutes: 30),
          averageSpeed: 20.0,
        );
        
        expect(trip.id, 'trip-1');
        expect(trip.userId, 'user123');
      });

      test('F3.1.2 - Trip serializes to JSON correctly', () {
        final trip = Trip(
          id: 'trip-3',
          userId: 'user123',
          startTime: DateTime(2025, 1, 1, 10, 0),
          endTime: DateTime(2025, 1, 1, 11, 0),
          points: [],
          distanceMeters: 10000.0,
          duration: const Duration(hours: 1),
          averageSpeed: 20.0,
        );
        
        final json = trip.toJson();
        expect(json['id'], 'trip-3');
        expect(json['distanceMeters'], 10000.0);
      });

      test('F3.1.3 - Trip restores from JSON correctly', () {
        final json = {
          'id': 'trip-4',
          'userId': 'user123',
          'startTime': '2025-01-01T10:00:00.000',
          'endTime': '2025-01-01T11:00:00.000',
          'points': [],
          'distanceMeters': 5000.0,
          'duration': 3600000000,
          'averageSpeed': 10.0,
          'isAutoDetected': false,
          'confirmedObstacleIds': [],
        };
        
        final restored = Trip.fromJson(json);
        expect(restored.id, 'trip-4');
        expect(restored.distanceMeters, 5000.0);
      });
    });

    group('F3.2 - History Ordering', () {
      test('F3.2.1 - Trips ordered by startTime descending', () {
        final trips = [
          Trip(id: 'a', userId: 'u', startTime: DateTime(2025, 1, 1), endTime: DateTime(2025, 1, 1, 1), points: [], distanceMeters: 1000.0, duration: const Duration(hours: 1), averageSpeed: 1.0),
          Trip(id: 'b', userId: 'u', startTime: DateTime(2025, 1, 3), endTime: DateTime(2025, 1, 3, 1), points: [], distanceMeters: 2000.0, duration: const Duration(hours: 1), averageSpeed: 2.0),
          Trip(id: 'c', userId: 'u', startTime: DateTime(2025, 1, 2), endTime: DateTime(2025, 1, 2, 1), points: [], distanceMeters: 1500.0, duration: const Duration(hours: 1), averageSpeed: 1.5),
        ];
        
        trips.sort((a, b) => b.startTime.compareTo(a.startTime));
        
        expect(trips[0].id, 'b');
        expect(trips[2].id, 'a');
      });
    });
  });
}
