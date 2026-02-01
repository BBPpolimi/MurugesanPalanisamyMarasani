// F5 — Manual Path Contribution Unit Tests
// These are fast unit tests that run without a device

import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/bike_path.dart';
import 'package:bbp_flutter/models/street_segment.dart';
import 'package:bbp_flutter/models/path_quality_report.dart';

void main() {
  group('F5 - Manual Path Contribution Tests', () {
    test('F5.1 - BikePath model exists', () {
      final path = BikePath(
        id: 'path-1',
        userId: 'user-1',
        name: 'Test Path',
        city: 'Milan',
        segments: [],
        status: PathRateStatus.optimal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(path.name, 'Test Path');
      expect(path.status, PathRateStatus.optimal);
    });

    test('F5.2 - StreetSegment model exists', () {
      final segment = StreetSegment(
        id: 'seg-1',
        streetName: 'Via Roma',
        formattedAddress: 'Via Roma, Milan',
        lat: 45.0,
        lng: 9.0,
      );
      
      expect(segment.streetName, 'Via Roma');
    });

    test('F5.3 - Path visibility states', () {
      expect(PathVisibility.values.length, 3);
      expect(PathVisibility.private, isNotNull);
      expect(PathVisibility.published, isNotNull);
      expect(PathVisibility.flagged, isNotNull);
    });

    test('F5.4 - Path status values', () {
      expect(PathRateStatus.values.length, 4);
      expect(PathRateStatus.optimal, isNotNull);
      expect(PathRateStatus.medium, isNotNull);
      expect(PathRateStatus.sufficient, isNotNull);
      expect(PathRateStatus.requiresMaintenance, isNotNull);
    });
  });
}
