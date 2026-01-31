// F6 — Automatic Detection Unit Tests
// These are fast unit tests that run without a device

import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/obstacle.dart';

void main() {
  group('F6 - Automatic Detection Tests', () {
    test('F6.1 - Obstacle model exists', () {
      final obstacle = Obstacle(
        id: 'obs-1',
        userId: 'user-1',
        lat: 45.0,
        lng: 9.0,
        obstacleType: ObstacleType.pothole,
        severity: ObstacleSeverity.medium,
        publishable: true,
        createdAt: DateTime.now(),
      );
      
      expect(obstacle.obstacleType, ObstacleType.pothole);
      expect(obstacle.severity, ObstacleSeverity.medium);
    });

    test('F6.2 - Obstacle types defined', () {
      expect(ObstacleType.values.length, 5);
      expect(ObstacleType.pothole.label, 'Pothole');
      expect(ObstacleType.construction.label, 'Construction');
    });

    test('F6.3 - Obstacle severity levels defined', () {
      expect(ObstacleSeverity.values.length, 3);
      expect(ObstacleSeverity.low.label, 'Low');
      expect(ObstacleSeverity.high.label, 'High');
    });
  });
}
