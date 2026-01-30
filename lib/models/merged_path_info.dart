import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_quality_report.dart'; // For PathRateStatus
import 'path_obstacle.dart';

/// Aggregated community view of a path.
/// Computed from all published contributions for the same pathId.
class MergedPathInfo {
  /// FK to canonical Path entity
  final String pathId;

  /// Weighted average status from all contributions
  final PathRateStatus mergedStatus;

  /// Union of obstacles with confirmation counts
  final List<MergedObstacle> mergedObstacles;

  /// Score based on recency of contributions (0.0 - 1.0)
  final double freshnessScore;

  /// Number of published contributions for this path
  final int contributionsCount;

  /// Overall confidence based on freshness and confirmation count
  final double confidenceScore;

  /// When this merged info was last computed
  final DateTime lastMergedAt;

  MergedPathInfo({
    required this.pathId,
    required this.mergedStatus,
    this.mergedObstacles = const [],
    this.freshnessScore = 0.0,
    this.contributionsCount = 0,
    this.confidenceScore = 0.0,
    required this.lastMergedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'pathId': pathId,
      'mergedStatus': mergedStatus.name,
      'mergedObstacles': mergedObstacles.map((o) => o.toMap()).toList(),
      'freshnessScore': freshnessScore,
      'contributionsCount': contributionsCount,
      'confidenceScore': confidenceScore,
      'lastMergedAt': Timestamp.fromDate(lastMergedAt),
    };
  }

  factory MergedPathInfo.fromMap(Map<String, dynamic> map) {
    return MergedPathInfo(
      pathId: map['pathId'] ?? '',
      mergedStatus: PathRateStatus.values.firstWhere(
        (e) => e.name == map['mergedStatus'],
        orElse: () => PathRateStatus.medium,
      ),
      mergedObstacles: (map['mergedObstacles'] as List?)
              ?.map((o) => MergedObstacle.fromMap(o))
              .toList() ??
          [],
      freshnessScore: (map['freshnessScore'] as num?)?.toDouble() ?? 0.0,
      contributionsCount: (map['contributionsCount'] as num?)?.toInt() ?? 0,
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      lastMergedAt:
          (map['lastMergedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Merged obstacle with confirmation tracking
class MergedObstacle {
  final String id;
  final double lat;
  final double lng;
  final String type; // ObstacleType name
  final String severity; // ObstacleSeverity name
  final int confirmationsCount;
  final DateTime lastConfirmedAt;

  MergedObstacle({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.severity,
    this.confirmationsCount = 1,
    required this.lastConfirmedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'type': type,
      'severity': severity,
      'confirmationsCount': confirmationsCount,
      'lastConfirmedAt': Timestamp.fromDate(lastConfirmedAt),
    };
  }

  factory MergedObstacle.fromMap(Map<String, dynamic> map) {
    return MergedObstacle(
      id: map['id'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      type: map['type'] ?? 'other',
      severity: map['severity'] ?? 'medium',
      confirmationsCount: (map['confirmationsCount'] as num?)?.toInt() ?? 1,
      lastConfirmedAt:
          (map['lastConfirmedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
