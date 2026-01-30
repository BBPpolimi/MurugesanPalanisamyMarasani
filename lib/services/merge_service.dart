import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
import '../models/merged_path_info.dart';
import '../models/path_quality_report.dart';

/// Service for computing and managing merged path info.
/// Aggregates all published contributions for a canonical path.
class MergeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recompute merged info for a path from all published contributions
  Future<void> recomputeMergedPathInfo(String pathId) async {
    // Fetch all published contributions for this path
    final snapshot = await _firestore
        .collection('contributions')
        .where('pathId', isEqualTo: pathId)
        .where('state', isEqualTo: ContributionState.published.name)
        .get();

    final contributions =
        snapshot.docs.map((doc) => Contribution.fromMap(doc.data())).toList();

    if (contributions.isEmpty) {
      // No published contributions, delete merged info if exists
      await _firestore.collection('mergedPathInfo').doc(pathId).delete();
      return;
    }

    // Compute merged status (weighted by freshness)
    final mergedStatus = _computeMergedStatus(contributions);

    // Compute merged obstacles (union with clustering)
    final mergedObstacles = _computeMergedObstacles(contributions);

    // Compute freshness score (decay over time)
    final freshnessScore = _computeFreshnessScore(contributions);

    // Compute confidence score
    final confidenceScore = _computeConfidenceScore(
      contributions.length,
      freshnessScore,
    );

    final mergedInfo = MergedPathInfo(
      pathId: pathId,
      mergedStatus: mergedStatus,
      mergedObstacles: mergedObstacles,
      freshnessScore: freshnessScore,
      contributionsCount: contributions.length,
      confidenceScore: confidenceScore,
      lastMergedAt: DateTime.now(),
    );

    await _firestore
        .collection('mergedPathInfo')
        .doc(pathId)
        .set(mergedInfo.toMap());
  }

  /// Get merged info for a path
  Future<MergedPathInfo?> getMergedPathInfo(String pathId) async {
    final doc = await _firestore.collection('mergedPathInfo').doc(pathId).get();
    if (doc.exists && doc.data() != null) {
      return MergedPathInfo.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get all merged path infos (for community browse)
  Future<List<MergedPathInfo>> getAllMergedPathInfos({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('mergedPathInfo')
        .orderBy('confidenceScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => MergedPathInfo.fromMap(doc.data()))
        .toList();
  }

  /// Compute merged status using weighted average by freshness
  PathRateStatus _computeMergedStatus(List<Contribution> contributions) {
    if (contributions.isEmpty) return PathRateStatus.medium;

    // Weight by age (newer = higher weight)
    final now = DateTime.now();
    double totalWeight = 0;
    double weightedSum = 0;

    for (final c in contributions) {
      final ageInDays = now.difference(c.capturedAt).inDays;
      final weight = 1.0 / (1 + ageInDays / 30); // Decay over 30 days
      totalWeight += weight;

      // Map status to numeric value
      final statusValue = _statusToValue(c.statusRating);
      weightedSum += statusValue * weight;
    }

    final avgValue = totalWeight > 0 ? weightedSum / totalWeight : 2.0;
    return _valueToStatus(avgValue);
  }

  double _statusToValue(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return 4.0;
      case PathRateStatus.medium:
        return 2.0;
      case PathRateStatus.sufficient:
        return 1.0;
      case PathRateStatus.requiresMaintenance:
        return 0.0;
    }
  }

  PathRateStatus _valueToStatus(double value) {
    if (value >= 3.0) return PathRateStatus.optimal;
    if (value >= 1.5) return PathRateStatus.medium;
    if (value >= 0.5) return PathRateStatus.sufficient;
    return PathRateStatus.requiresMaintenance;
  }

  /// Compute merged obstacles by clustering nearby obstacles
  List<MergedObstacle> _computeMergedObstacles(List<Contribution> contributions) {
    final allObstacles = <_TempObstacle>[];

    for (final c in contributions) {
      for (final o in c.obstacles) {
        if (o.lat != null && o.lng != null) {
          allObstacles.add(_TempObstacle(
            lat: o.lat!,
            lng: o.lng!,
            type: o.type.name,
            severity: o.severity.toString(),
            timestamp: c.capturedAt,
          ));
        }
      }
    }

    if (allObstacles.isEmpty) return [];

    // Simple clustering: merge obstacles within ~20m of each other
    final clusters = <List<_TempObstacle>>[];
    final used = <int>{};

    for (int i = 0; i < allObstacles.length; i++) {
      if (used.contains(i)) continue;

      final cluster = <_TempObstacle>[allObstacles[i]];
      used.add(i);

      for (int j = i + 1; j < allObstacles.length; j++) {
        if (used.contains(j)) continue;

        if (_areNearby(allObstacles[i], allObstacles[j])) {
          cluster.add(allObstacles[j]);
          used.add(j);
        }
      }

      clusters.add(cluster);
    }

    // Convert clusters to MergedObstacles
    return clusters.map((cluster) {
      // Use centroid and most common type/severity
      final avgLat = cluster.map((o) => o.lat).reduce((a, b) => a + b) / cluster.length;
      final avgLng = cluster.map((o) => o.lng).reduce((a, b) => a + b) / cluster.length;
      final mostCommonType = _mostCommon(cluster.map((o) => o.type).toList());
      final mostCommonSeverity = _mostCommon(cluster.map((o) => o.severity).toList());
      final latestTime = cluster.map((o) => o.timestamp).reduce(
          (a, b) => a.isAfter(b) ? a : b);

      return MergedObstacle(
        id: '${avgLat.toStringAsFixed(5)}_${avgLng.toStringAsFixed(5)}',
        lat: avgLat,
        lng: avgLng,
        type: mostCommonType,
        severity: mostCommonSeverity,
        confirmationsCount: cluster.length,
        lastConfirmedAt: latestTime,
      );
    }).toList();
  }

  bool _areNearby(_TempObstacle a, _TempObstacle b) {
    // ~20m threshold in degrees (very rough approximation)
    const threshold = 0.0002;
    final dLat = (a.lat - b.lat).abs();
    final dLng = (a.lng - b.lng).abs();
    return dLat < threshold && dLng < threshold;
  }

  String _mostCommon(List<String> items) {
    if (items.isEmpty) return 'other';
    final counts = <String, int>{};
    for (final item in items) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Compute freshness score based on most recent contribution
  double _computeFreshnessScore(List<Contribution> contributions) {
    if (contributions.isEmpty) return 0.0;

    final now = DateTime.now();
    final mostRecent = contributions
        .map((c) => c.capturedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final ageInDays = now.difference(mostRecent).inDays;

    // Score decays from 1.0 to 0.0 over 90 days
    return (1.0 - (ageInDays / 90)).clamp(0.0, 1.0);
  }

  /// Compute confidence score based on contribution count and freshness
  double _computeConfidenceScore(int contributionsCount, double freshnessScore) {
    // More contributions = higher confidence, up to a cap
    final countScore = (contributionsCount / 10).clamp(0.0, 1.0);

    // Combined score
    return (countScore * 0.6 + freshnessScore * 0.4);
  }
}

class _TempObstacle {
  final double lat;
  final double lng;
  final String type;
  final String severity;
  final DateTime timestamp;

  _TempObstacle({
    required this.lat,
    required this.lng,
    required this.type,
    required this.severity,
    required this.timestamp,
  });
}
