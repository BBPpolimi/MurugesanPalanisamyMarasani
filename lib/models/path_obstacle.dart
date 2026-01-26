import 'package:cloud_firestore/cloud_firestore.dart';

/// Obstacle types that can be reported as part of a path contribution
enum PathObstacleType {
  pothole,
  construction,
  debris,
  unsafeIntersection,
  poorSurface,
  noLighting,
  other;

  String get label {
    switch (this) {
      case PathObstacleType.pothole:
        return 'Pothole';
      case PathObstacleType.construction:
        return 'Construction';
      case PathObstacleType.debris:
        return 'Debris';
      case PathObstacleType.unsafeIntersection:
        return 'Unsafe Intersection';
      case PathObstacleType.poorSurface:
        return 'Poor Surface';
      case PathObstacleType.noLighting:
        return 'No Lighting';
      case PathObstacleType.other:
        return 'Other';
    }
  }
}

/// Obstacle embedded within a BikePath contribution
class PathObstacle {
  final String id;
  final PathObstacleType type;
  final int severity; // 1-5
  final String? note;
  final double? lat;
  final double? lng;
  final String? photoUrl;
  final DateTime createdAt;

  PathObstacle({
    required this.id,
    required this.type,
    required this.severity,
    this.note,
    this.lat,
    this.lng,
    this.photoUrl,
    required this.createdAt,
  }) : assert(severity >= 1 && severity <= 5, 'Severity must be between 1 and 5');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity,
      'note': note,
      'lat': lat,
      'lng': lng,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PathObstacle.fromMap(Map<String, dynamic> map) {
    return PathObstacle(
      id: map['id'] ?? '',
      type: PathObstacleType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PathObstacleType.other,
      ),
      severity: (map['severity'] as num?)?.toInt().clamp(1, 5) ?? 3,
      note: map['note'],
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  PathObstacle copyWith({
    String? id,
    PathObstacleType? type,
    int? severity,
    String? note,
    double? lat,
    double? lng,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return PathObstacle(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      note: note ?? this.note,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
