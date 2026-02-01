import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/bike_path.dart';
import 'package:bbp_flutter/models/street_segment.dart';
import 'package:bbp_flutter/models/path_obstacle.dart';
import 'package:bbp_flutter/models/path_tag.dart';
import 'package:bbp_flutter/models/path_quality_report.dart';

void main() {
  group('BikePath Model Tests', () {
    test('should create BikePath with required fields', () {
      final now = DateTime.now();
      final segments = [
        StreetSegment(
          id: 'seg1',
          streetName: 'Main Street',
          formattedAddress: 'Main Street, City',
          lat: 45.0,
          lng: 9.0,
          order: 0,
        ),
        StreetSegment(
          id: 'seg2',
          streetName: 'Oak Avenue',
          formattedAddress: 'Oak Avenue, City',
          lat: 45.01,
          lng: 9.01,
          order: 1,
        ),
      ];

      final path = BikePath(
        id: 'path123',
        userId: 'user123',
        segments: segments,
        status: PathRateStatus.optimal,
        createdAt: now,
        updatedAt: now,
      );

      expect(path.id, 'path123');
      expect(path.userId, 'user123');
      expect(path.segments.length, 2);
      expect(path.status, PathRateStatus.optimal);
      expect(path.visibility, PathVisibility.private); // default
      expect(path.version, 1); // default
      expect(path.deleted, false); // default
    });

    test('should serialize to map correctly', () {
      final now = DateTime.now();
      final segments = [
        StreetSegment(
          id: 'seg1',
          streetName: 'Main Street',
          formattedAddress: 'Main Street, City',
          lat: 45.0,
          lng: 9.0,
          order: 0,
        ),
        StreetSegment(
          id: 'seg2',
          streetName: 'Oak Avenue',
          formattedAddress: 'Oak Avenue, City',
          lat: 45.01,
          lng: 9.01,
          order: 1,
        ),
      ];

      final path = BikePath(
        id: 'path123',
        userId: 'user123',
        name: 'Test Path',
        segments: segments,
        status: PathRateStatus.optimal,
        visibility: PathVisibility.published,
        tags: [PathTag.bikeLanePresent, PathTag.scenic],
        city: 'Milan',
        createdAt: now,
        updatedAt: now,
      );

      final map = path.toMap();

      expect(map['id'], 'path123');
      expect(map['userId'], 'user123');
      expect(map['name'], 'Test Path');
      expect(map['status'], 'optimal');
      expect(map['visibility'], 'published');
      expect(map['city'], 'Milan');
      expect(map['segments'], isA<List>());
      expect(map['tags'], ['bikeLanePresent', 'scenic']);
      expect(map['publishable'], true); // legacy field
    });

    test('should deserialize from map correctly', () {
      final map = {
        'id': 'path456',
        'userId': 'user456',
        'name': 'Deserialized Path',
        'segments': [
          {
            'id': 'seg1',
            'streetName': 'First Street',
            'formattedAddress': 'First Street, Town',
            'lat': 46.0,
            'lng': 10.0,
            'order': 0,
          },
          {
            'id': 'seg2',
            'streetName': 'Second Street',
            'formattedAddress': 'Second Street, Town',
            'lat': 46.01,
            'lng': 10.01,
            'order': 1,
          },
        ],
        'status': 'medium',
        'visibility': 'published',
        'tags': ['lowTraffic', 'speedLimitOk'],
        'obstacles': [
          {
            'id': 'obs1',
            'type': 'pothole',
            'severity': 3,
            'note': 'Near intersection',
          },
        ],
        'city': 'Rome',
        'version': 2,
        'deleted': false,
        'distanceMeters': 1500.0,
      };

      final path = BikePath.fromMap(map);

      expect(path.id, 'path456');
      expect(path.userId, 'user456');
      expect(path.name, 'Deserialized Path');
      expect(path.segments.length, 2);
      expect(path.status, PathRateStatus.medium);
      expect(path.visibility, PathVisibility.published);
      expect(path.tags.length, 2);
      expect(path.obstacles.length, 1);
      expect(path.obstacles.first.type, PathObstacleType.pothole);
      expect(path.city, 'Rome');
      expect(path.version, 2);
    });

    test('should handle legacy publishable field', () {
      final map = {
        'id': 'legacy1',
        'userId': 'user1',
        'segments': [],
        'status': 'optimal',
        'publishable': true, // legacy field
        // no 'visibility' field
      };

      final path = BikePath.fromMap(map);

      expect(path.visibility, PathVisibility.published);
      expect(path.publishable, true);
    });

    test('copyWith should create modified copy', () {
      final now = DateTime.now();
      final path = BikePath(
        id: 'path1',
        userId: 'user1',
        segments: [],
        status: PathRateStatus.optimal,
        visibility: PathVisibility.private,
        createdAt: now,
        updatedAt: now,
      );

      final modified = path.copyWith(
        name: 'New Name',
        visibility: PathVisibility.published,
        version: 2,
      );

      expect(modified.id, 'path1'); // unchanged
      expect(modified.name, 'New Name');
      expect(modified.visibility, PathVisibility.published);
      expect(modified.version, 2);
    });
  });

  group('StreetSegment Model Tests', () {
    test('should create StreetSegment with all fields', () {
      final segment = StreetSegment(
        id: 'seg1',
        streetName: 'Test Street',
        formattedAddress: 'Test Street 123, City',
        lat: 45.5,
        lng: 9.2,
        order: 0,
        placeId: 'ChIJ123abc',
      );

      expect(segment.id, 'seg1');
      expect(segment.streetName, 'Test Street');
      expect(segment.order, 0);
      expect(segment.placeId, 'ChIJ123abc');
    });

    test('should serialize and deserialize correctly', () {
      final segment = StreetSegment(
        id: 'seg1',
        streetName: 'Test Street',
        formattedAddress: 'Test Street 123, City',
        lat: 45.5,
        lng: 9.2,
        order: 1,
      );

      final map = segment.toMap();
      final restored = StreetSegment.fromMap(map);

      expect(restored.id, segment.id);
      expect(restored.streetName, segment.streetName);
      expect(restored.lat, segment.lat);
      expect(restored.lng, segment.lng);
      expect(restored.order, segment.order);
    });
  });

  group('PathObstacle Model Tests', () {
    test('should create PathObstacle with required fields', () {
      final now = DateTime.now();
      final obstacle = PathObstacle(
        id: 'obs1',
        type: PathObstacleType.pothole,
        severity: 4,
        createdAt: now,
      );

      expect(obstacle.id, 'obs1');
      expect(obstacle.type, PathObstacleType.pothole);
      expect(obstacle.severity, 4);
      expect(obstacle.note, isNull);
    });

    test('should serialize and deserialize correctly', () {
      final now = DateTime.now();
      final obstacle = PathObstacle(
        id: 'obs1',
        type: PathObstacleType.construction,
        severity: 3,
        note: 'Road work ahead',
        lat: 45.5,
        lng: 9.2,
        createdAt: now,
      );

      final map = obstacle.toMap();
      final restored = PathObstacle.fromMap(map);

      expect(restored.id, obstacle.id);
      expect(restored.type, obstacle.type);
      expect(restored.severity, obstacle.severity);
      expect(restored.note, obstacle.note);
      expect(restored.lat, obstacle.lat);
      expect(restored.lng, obstacle.lng);
    });

    test('PathObstacleType labels should be correct', () {
      expect(PathObstacleType.pothole.label, 'Pothole');
      expect(PathObstacleType.construction.label, 'Construction');
      expect(PathObstacleType.debris.label, 'Debris');
      expect(PathObstacleType.unsafeIntersection.label, 'Unsafe Intersection');
      expect(PathObstacleType.other.label, 'Other');
    });
  });

  group('PathTag Model Tests', () {
    test('PathTag labels should be correct', () {
      expect(PathTag.bikeLanePresent.label, 'Bike Lane Present');
      expect(PathTag.lowTraffic.label, 'Low Traffic');
      expect(PathTag.speedLimitOk.label, 'Speed Limit OK');
      expect(PathTag.scenic.label, 'Scenic');
    });

    test('PathTag icons should not be null', () {
      for (final tag in PathTag.values) {
        expect(tag.icon, isNotNull);
      }
    });
  });
}
