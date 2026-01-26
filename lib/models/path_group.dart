import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_quality_report.dart';

/// Represents a merged view of multiple user contributions for the same path
/// This is a derived/computed document that aggregates individual contributions
class PathGroup {
  final String id;
  final String normalizedKey;
  final String? city;
  final String? areaGeohash;
  final String? representativePolyline;
  
  // Merged status from voting
  final PathRateStatus mergedStatus;
  final Map<String, double> statusVotes; // {optimal: 1.88, medium: 0, ...}
  
  // Confidence metrics
  final double freshnessScore; // 0-100
  final int confirmations;
  final int contributorCount;
  final double distanceMeters;
  
  // Obstacles summary
  final ObstaclesSummary obstaclesSummary;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  PathGroup({
    required this.id,
    required this.normalizedKey,
    this.city,
    this.areaGeohash,
    this.representativePolyline,
    required this.mergedStatus,
    this.statusVotes = const {},
    this.freshnessScore = 0,
    this.confirmations = 0,
    this.contributorCount = 0,
    this.distanceMeters = 0,
    ObstaclesSummary? obstaclesSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : obstaclesSummary = obstaclesSummary ?? ObstaclesSummary.empty(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'normalizedKey': normalizedKey,
      'city': city,
      'areaGeohash': areaGeohash,
      'representativePolyline': representativePolyline,
      'mergedStatus': mergedStatus.name,
      'statusVotes': statusVotes,
      'freshnessScore': freshnessScore,
      'confirmations': confirmations,
      'contributorCount': contributorCount,
      'distanceMeters': distanceMeters,
      'obstaclesSummary': obstaclesSummary.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PathGroup.fromMap(Map<String, dynamic> map) {
    return PathGroup(
      id: map['id'] ?? '',
      normalizedKey: map['normalizedKey'] ?? '',
      city: map['city'],
      areaGeohash: map['areaGeohash'],
      representativePolyline: map['representativePolyline'],
      mergedStatus: PathRateStatus.values.firstWhere(
        (e) => e.name == map['mergedStatus'],
        orElse: () => PathRateStatus.medium,
      ),
      statusVotes: Map<String, double>.from(map['statusVotes'] ?? {}),
      freshnessScore: (map['freshnessScore'] ?? 0).toDouble(),
      confirmations: map['confirmations'] ?? 0,
      contributorCount: map['contributorCount'] ?? 0,
      distanceMeters: (map['distanceMeters'] ?? 0).toDouble(),
      obstaclesSummary: map['obstaclesSummary'] != null
          ? ObstaclesSummary.fromMap(map['obstaclesSummary'])
          : ObstaclesSummary.empty(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  PathGroup copyWith({
    String? id,
    String? normalizedKey,
    String? city,
    String? areaGeohash,
    String? representativePolyline,
    PathRateStatus? mergedStatus,
    Map<String, double>? statusVotes,
    double? freshnessScore,
    int? confirmations,
    int? contributorCount,
    double? distanceMeters,
    ObstaclesSummary? obstaclesSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PathGroup(
      id: id ?? this.id,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      city: city ?? this.city,
      areaGeohash: areaGeohash ?? this.areaGeohash,
      representativePolyline: representativePolyline ?? this.representativePolyline,
      mergedStatus: mergedStatus ?? this.mergedStatus,
      statusVotes: statusVotes ?? this.statusVotes,
      freshnessScore: freshnessScore ?? this.freshnessScore,
      confirmations: confirmations ?? this.confirmations,
      contributorCount: contributorCount ?? this.contributorCount,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      obstaclesSummary: obstaclesSummary ?? this.obstaclesSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get confidence level based on freshness and confirmations
  String get confidenceLevel {
    if (freshnessScore >= 80 && confirmations >= 3) return 'High';
    if (freshnessScore >= 50 && confirmations >= 2) return 'Medium';
    return 'Low';
  }

  /// Get confidence as a percentage (0-100)
  double get confidencePercent {
    // Weight: 60% freshness, 40% confirmations (capped at 5)
    final confirmationScore = (confirmations / 5).clamp(0.0, 1.0) * 100;
    return (freshnessScore * 0.6) + (confirmationScore * 0.4);
  }
}

/// Summary of obstacles for a path group
class ObstaclesSummary {
  final int total;
  final List<int> bySeverity; // [count_sev1, count_sev2, count_sev3, count_sev4, count_sev5]
  final Map<String, int> byType; // {pothole: 2, construction: 1, ...}

  ObstaclesSummary({
    required this.total,
    required this.bySeverity,
    required this.byType,
  });

  factory ObstaclesSummary.empty() {
    return ObstaclesSummary(
      total: 0,
      bySeverity: [0, 0, 0, 0, 0],
      byType: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'bySeverity': bySeverity,
      'byType': byType,
    };
  }

  factory ObstaclesSummary.fromMap(Map<String, dynamic> map) {
    return ObstaclesSummary(
      total: map['total'] ?? 0,
      bySeverity: List<int>.from(map['bySeverity'] ?? [0, 0, 0, 0, 0]),
      byType: Map<String, int>.from(map['byType'] ?? {}),
    );
  }

  /// Get average severity (1-5 scale)
  double get averageSeverity {
    if (total == 0) return 0;
    double sum = 0;
    for (int i = 0; i < bySeverity.length; i++) {
      sum += bySeverity[i] * (i + 1);
    }
    return sum / total;
  }

  /// Get human-readable summary
  String get summary {
    if (total == 0) return 'No obstacles reported';
    final avgSev = averageSeverity;
    final sevLabel = avgSev <= 2 ? 'minor' : (avgSev <= 3.5 ? 'moderate' : 'significant');
    return '$total $sevLabel obstacle${total > 1 ? 's' : ''}';
  }
}
