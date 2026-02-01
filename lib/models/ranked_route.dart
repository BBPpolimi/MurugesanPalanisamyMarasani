import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_quality_report.dart';
import 'path_obstacle.dart';

/// Represents a ranked route result from the BBP route search
/// This contains merged path data with scores and explanations
class RankedRoute {
  final String id;
  final String? name;
  final String encodedPolyline;
  final double distanceMeters;
  final int durationSeconds;
  
  // Score components
  final double totalScore;
  final double statusScore;
  final double effectivenessScore;
  final double obstacleScore;
  final double freshnessScore;
  
  // Path info
  final PathRateStatus status;
  final int obstacleCount;
  final int confirmations;
  final DateTime? lastUpdated;
  
  // Explanation
  final RouteExplanation explanation;
  
  // Associated path group (if matched)
  final String? pathGroupId;
  
  // Obstacles along the route
  final List<RouteObstacle> obstacles;

  RankedRoute({
    required this.id,
    this.name,
    required this.encodedPolyline,
    required this.distanceMeters,
    this.durationSeconds = 0,
    required this.totalScore,
    this.statusScore = 0,
    this.effectivenessScore = 0,
    this.obstacleScore = 0,
    this.freshnessScore = 0,
    required this.status,
    this.obstacleCount = 0,
    this.confirmations = 0,
    this.lastUpdated,
    required this.explanation,
    this.pathGroupId,
    this.obstacles = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'encodedPolyline': encodedPolyline,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'totalScore': totalScore,
      'statusScore': statusScore,
      'effectivenessScore': effectivenessScore,
      'obstacleScore': obstacleScore,
      'freshnessScore': freshnessScore,
      'status': status.name,
      'obstacleCount': obstacleCount,
      'confirmations': confirmations,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'explanation': explanation.toMap(),
      'pathGroupId': pathGroupId,
      'obstacles': obstacles.map((o) => o.toMap()).toList(),
    };
  }

  factory RankedRoute.fromMap(Map<String, dynamic> map) {
    return RankedRoute(
      id: map['id'] ?? '',
      name: map['name'],
      encodedPolyline: map['encodedPolyline'] ?? '',
      distanceMeters: (map['distanceMeters'] ?? 0).toDouble(),
      durationSeconds: map['durationSeconds'] ?? 0,
      totalScore: (map['totalScore'] ?? 0).toDouble(),
      statusScore: (map['statusScore'] ?? 0).toDouble(),
      effectivenessScore: (map['effectivenessScore'] ?? 0).toDouble(),
      obstacleScore: (map['obstacleScore'] ?? 0).toDouble(),
      freshnessScore: (map['freshnessScore'] ?? 0).toDouble(),
      status: PathRateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PathRateStatus.medium,
      ),
      obstacleCount: map['obstacleCount'] ?? 0,
      confirmations: map['confirmations'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
      explanation: RouteExplanation.fromMap(map['explanation'] ?? {}),
      pathGroupId: map['pathGroupId'],
      obstacles: (map['obstacles'] as List<dynamic>?)
              ?.map((o) => RouteObstacle.fromMap(o))
              .toList() ??
          [],
    );
  }

  /// Get formatted distance
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Get formatted duration
  String get formattedDuration {
    if (durationSeconds < 60) {
      return '$durationSeconds sec';
    }
    final minutes = durationSeconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  /// Get score as percentage
  int get scorePercent => totalScore.round().clamp(0, 100);

  /// Get score level (for color coding)
  String get scoreLevel {
    if (totalScore >= 80) return 'excellent';
    if (totalScore >= 60) return 'good';
    if (totalScore >= 40) return 'fair';
    return 'poor';
  }
}

/// Human-readable explanation of why a route was scored
class RouteExplanation {
  final String statusReason;
  final String detourReason;
  final String obstacleReason;
  final String freshnessReason;
  final String? confirmationReason;

  RouteExplanation({
    required this.statusReason,
    required this.detourReason,
    required this.obstacleReason,
    required this.freshnessReason,
    this.confirmationReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'statusReason': statusReason,
      'detourReason': detourReason,
      'obstacleReason': obstacleReason,
      'freshnessReason': freshnessReason,
      'confirmationReason': confirmationReason,
    };
  }

  factory RouteExplanation.fromMap(Map<String, dynamic> map) {
    return RouteExplanation(
      statusReason: map['statusReason'] ?? '',
      detourReason: map['detourReason'] ?? '',
      obstacleReason: map['obstacleReason'] ?? '',
      freshnessReason: map['freshnessReason'] ?? '',
      confirmationReason: map['confirmationReason'],
    );
  }

  factory RouteExplanation.empty() {
    return RouteExplanation(
      statusReason: 'No data',
      detourReason: 'Direct route',
      obstacleReason: 'No obstacles',
      freshnessReason: 'No recent data',
    );
  }

  /// Get all reasons as a list
  List<String> get allReasons {
    return [
      statusReason,
      detourReason,
      obstacleReason,
      freshnessReason,
      if (confirmationReason != null) confirmationReason!,
    ].where((r) => r.isNotEmpty).toList();
  }
}

/// Simplified obstacle info for route display
class RouteObstacle {
  final String id;
  final PathObstacleType type;
  final double lat;
  final double lng;
  final int severity;
  final String? note;

  RouteObstacle({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    required this.severity,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'lat': lat,
      'lng': lng,
      'severity': severity,
      'note': note,
    };
  }

  factory RouteObstacle.fromMap(Map<String, dynamic> map) {
    return RouteObstacle(
      id: map['id'] ?? '',
      type: PathObstacleType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PathObstacleType.other,
      ),
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      severity: map['severity'] ?? 1,
      note: map['note'],
    );
  }
}
