
import 'package:cloud_firestore/cloud_firestore.dart';

enum ObstacleType {
  pothole,
  construction,
  closure,
  debris,
  other;

  String get label {
    switch (this) {
      case ObstacleType.pothole:
        return 'Pothole';
      case ObstacleType.construction:
        return 'Construction';
      case ObstacleType.closure:
        return 'Road Closure';
      case ObstacleType.debris:
        return 'Debris';
      case ObstacleType.other:
        return 'Other';
    }
  }
}

enum ObstacleSeverity {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case ObstacleSeverity.low:
        return 'Low';
      case ObstacleSeverity.medium:
        return 'Medium';
      case ObstacleSeverity.high:
        return 'High';
    }
  }
}

class Obstacle {
  final String id;
  final String userId;
  final double lat;
  final double lng;
  final ObstacleType obstacleType;
  final ObstacleSeverity severity;
  final bool publishable;
  final DateTime createdAt;

  Obstacle({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.obstacleType,
    required this.severity,
    required this.publishable,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'obstacleType': obstacleType.name,
      'severity': severity.name,
      'publishable': publishable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Obstacle.fromMap(Map<String, dynamic> map) {
    return Obstacle(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      obstacleType: ObstacleType.values.firstWhere(
        (e) => e.name == map['obstacleType'],
        orElse: () => ObstacleType.other,
      ),
      severity: ObstacleSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => ObstacleSeverity.medium,
      ),
      publishable: map['publishable'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
