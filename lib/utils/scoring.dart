import 'dart:math' as math;
import '../models/path_quality_report.dart';
import '../models/ranked_route.dart';
import '../models/path_group.dart';

/// Scoring utilities for route ranking
class RouteScoring {
  /// Score weights (must sum to 1.0)
  static const double statusWeight = 0.40;
  static const double effectivenessWeight = 0.35;
  static const double obstacleWeight = 0.15;
  static const double freshnessWeight = 0.10;

  /// Status score mapping (0-100)
  static double getStatusScore(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return 100;
      case PathRateStatus.medium:
        return 75;
      case PathRateStatus.sufficient:
        return 50;
      case PathRateStatus.requiresMaintenance:
        return 25;
    }
  }

  /// Compute effectiveness score based on detour ratio
  /// detourRatio = (routeDistance - directDistance) / directDistance
  static double getEffectivenessScore(double routeDistanceM, double directDistanceM) {
    if (directDistanceM <= 0) return 100;
    
    final detourRatio = (routeDistanceM - directDistanceM) / directDistanceM;
    // Cap at 1.0 (100% detour = 0 score)
    final clampedRatio = detourRatio.clamp(0.0, 1.0);
    return 100 * (1 - clampedRatio);
  }

  /// Compute obstacle score (penalties for obstacles)
  /// obstaclesPerKm * severityFactor * 10 (capped at 100)
  static double getObstacleScore(int obstacleCount, double severityAvg, double distanceKm) {
    if (distanceKm <= 0) return 100;
    if (obstacleCount == 0) return 100;

    final obstaclesPerKm = obstacleCount / distanceKm;
    final severityFactor = severityAvg / 3; // Normalize to ~1 for avg severity
    final penalty = obstaclesPerKm * severityFactor * 15;
    
    return (100 - penalty).clamp(0.0, 100.0);
  }

  /// Compute freshness score based on days since update
  static double getFreshnessScore(DateTime? lastUpdated, {int halfLifeDays = 60}) {
    if (lastUpdated == null) return 0;
    
    final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
    // Exponential decay
    return 100 * math.exp(-daysSinceUpdate / halfLifeDays);
  }

  /// Compute total score from components
  static double computeTotalScore({
    required double statusScore,
    required double effectivenessScore,
    required double obstacleScore,
    required double freshnessScore,
  }) {
    return (statusScore * statusWeight) +
           (effectivenessScore * effectivenessWeight) +
           (obstacleScore * obstacleWeight) +
           (freshnessScore * freshnessWeight);
  }

  /// Compute all scores and return a RankedRoute
  static RankedRoute scoreRoute({
    required String id,
    String? name,
    required String encodedPolyline,
    required double distanceMeters,
    required double directDistanceMeters,
    int durationSeconds = 0,
    required PathRateStatus status,
    int obstacleCount = 0,
    double obstaclesSeverityAvg = 0,
    int confirmations = 0,
    DateTime? lastUpdated,
    String? pathGroupId,
    List<RouteObstacle> obstacles = const [],
  }) {
    final statusScore = getStatusScore(status);
    final effectivenessScore = getEffectivenessScore(distanceMeters, directDistanceMeters);
    final obstacleScore = getObstacleScore(
      obstacleCount, 
      obstaclesSeverityAvg, 
      distanceMeters / 1000,
    );
    final freshnessScore = getFreshnessScore(lastUpdated);
    
    final totalScore = computeTotalScore(
      statusScore: statusScore,
      effectivenessScore: effectivenessScore,
      obstacleScore: obstacleScore,
      freshnessScore: freshnessScore,
    );

    final explanation = generateExplanation(
      status: status,
      distanceMeters: distanceMeters,
      directDistanceMeters: directDistanceMeters,
      obstacleCount: obstacleCount,
      lastUpdated: lastUpdated,
      confirmations: confirmations,
    );

    return RankedRoute(
      id: id,
      name: name,
      encodedPolyline: encodedPolyline,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      totalScore: totalScore,
      statusScore: statusScore,
      effectivenessScore: effectivenessScore,
      obstacleScore: obstacleScore,
      freshnessScore: freshnessScore,
      status: status,
      obstacleCount: obstacleCount,
      confirmations: confirmations,
      lastUpdated: lastUpdated,
      explanation: explanation,
      pathGroupId: pathGroupId,
      obstacles: obstacles,
    );
  }

  /// Generate human-readable explanation
  static RouteExplanation generateExplanation({
    required PathRateStatus status,
    required double distanceMeters,
    required double directDistanceMeters,
    required int obstacleCount,
    DateTime? lastUpdated,
    int confirmations = 0,
  }) {
    // Status reason
    String statusReason;
    switch (status) {
      case PathRateStatus.optimal:
        statusReason = 'Optimal path condition';
        break;
      case PathRateStatus.medium:
        statusReason = 'Good path condition';
        break;
      case PathRateStatus.sufficient:
        statusReason = 'Sufficient path condition';
        break;
      case PathRateStatus.requiresMaintenance:
        statusReason = 'Path requires maintenance';
        break;
    }

    // Detour reason
    String detourReason;
    if (directDistanceMeters > 0) {
      final detourPercent = ((distanceMeters - directDistanceMeters) / directDistanceMeters * 100).round();
      if (detourPercent <= 5) {
        detourReason = 'Direct route';
      } else {
        final extraM = (distanceMeters - directDistanceMeters).round();
        final extraKm = extraM / 1000;
        if (extraKm < 1) {
          detourReason = '+$detourPercent% vs direct ($extraM m longer)';
        } else {
          detourReason = '+$detourPercent% vs direct (${extraKm.toStringAsFixed(1)} km longer)';
        }
      }
    } else {
      detourReason = 'Route distance unavailable';
    }

    // Obstacle reason
    String obstacleReason;
    if (obstacleCount == 0) {
      obstacleReason = 'No obstacles reported';
    } else if (obstacleCount == 1) {
      obstacleReason = '1 obstacle reported';
    } else {
      obstacleReason = '$obstacleCount obstacles reported';
    }

    // Freshness reason
    String freshnessReason;
    if (lastUpdated == null) {
      freshnessReason = 'No recent data';
    } else {
      final daysSince = DateTime.now().difference(lastUpdated).inDays;
      if (daysSince == 0) {
        freshnessReason = 'Updated today';
      } else if (daysSince == 1) {
        freshnessReason = 'Updated yesterday';
      } else if (daysSince <= 7) {
        freshnessReason = 'Updated $daysSince days ago';
      } else if (daysSince <= 30) {
        final weeks = (daysSince / 7).round();
        freshnessReason = 'Updated $weeks week${weeks > 1 ? 's' : ''} ago';
      } else {
        final months = (daysSince / 30).round();
        freshnessReason = 'Updated $months month${months > 1 ? 's' : ''} ago';
      }
    }

    // Confirmation reason
    String? confirmationReason;
    if (confirmations > 1) {
      confirmationReason = 'Verified by $confirmations users';
    }

    return RouteExplanation(
      statusReason: statusReason,
      detourReason: detourReason,
      obstacleReason: obstacleReason,
      freshnessReason: freshnessReason,
      confirmationReason: confirmationReason,
    );
  }

  /// Calculate direct distance between two points (Haversine formula)
  static double calculateDirectDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(destLat - originLat);
    final dLng = _toRadians(destLng - originLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(originLat)) * math.cos(_toRadians(destLat)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Merge algorithm utilities
class MergeAlgorithm {
  /// Time window for comparable votes (days)
  static const int timeWindowDays = 14;
  
  /// Half-life for freshness decay (days)
  static const int halfLifeDays = 30;

  /// Compute contribution weight
  static double computeWeight({
    required DateTime publishedAt,
    int confirmCount = 0,
    double baseFactor = 1.0,
  }) {
    final now = DateTime.now();
    final daysSincePublished = now.difference(publishedAt).inDays;
    
    // Exponential decay
    final freshnessDecay = math.exp(-daysSincePublished / halfLifeDays);
    
    // Confirmation bonus (max 1.5x)
    final confirmationBonus = 1 + (0.1 * confirmCount).clamp(0.0, 0.5);
    
    return baseFactor * freshnessDecay * confirmationBonus;
  }

  /// Compute merged status from contributions
  static PathRateStatus computeMergedStatus(List<StatusVote> votes) {
    if (votes.isEmpty) return PathRateStatus.medium;

    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: timeWindowDays));
    
    // Accumulate weighted votes
    final weightedVotes = <PathRateStatus, double>{};
    final freshest = <PathRateStatus, DateTime>{};
    
    for (final status in PathRateStatus.values) {
      weightedVotes[status] = 0;
    }
    
    for (final vote in votes) {
      // Skip votes outside time window (they still contribute but with decay)
      final weight = computeWeight(
        publishedAt: vote.publishedAt,
        confirmCount: vote.confirmCount,
      );
      
      weightedVotes[vote.status] = (weightedVotes[vote.status] ?? 0) + weight;
      
      // Track freshest vote per status
      if (freshest[vote.status] == null || 
          vote.publishedAt.isAfter(freshest[vote.status]!)) {
        freshest[vote.status] = vote.publishedAt;
      }
    }
    
    // Find winner (argmax)
    double maxVote = 0;
    final candidates = <PathRateStatus>[];
    
    for (final entry in weightedVotes.entries) {
      if (entry.value > maxVote) {
        maxVote = entry.value;
        candidates.clear();
        candidates.add(entry.key);
      } else if (entry.value == maxVote && entry.value > 0) {
        candidates.add(entry.key);
      }
    }
    
    if (candidates.isEmpty) return PathRateStatus.medium;
    if (candidates.length == 1) return candidates.first;
    
    // Break tie by freshest
    PathRateStatus winner = candidates.first;
    DateTime? freshestTime = freshest[winner];
    
    for (final candidate in candidates) {
      final candidateTime = freshest[candidate];
      if (candidateTime != null && 
          (freshestTime == null || candidateTime.isAfter(freshestTime))) {
        winner = candidate;
        freshestTime = candidateTime;
      }
    }
    
    return winner;
  }

  /// Convert weighted votes to map for storage
  static Map<String, double> votesToMap(List<StatusVote> votes) {
    final result = <String, double>{};
    
    for (final status in PathRateStatus.values) {
      result[status.name] = 0;
    }
    
    for (final vote in votes) {
      final weight = computeWeight(
        publishedAt: vote.publishedAt,
        confirmCount: vote.confirmCount,
      );
      result[vote.status.name] = (result[vote.status.name] ?? 0) + weight;
    }
    
    return result;
  }

  /// Compute overall freshness score for a group
  static double computeFreshnessScore(List<DateTime> publishDates) {
    if (publishDates.isEmpty) return 0;
    
    // Use most recent contribution
    final mostRecent = publishDates.reduce((a, b) => a.isAfter(b) ? a : b);
    return RouteScoring.getFreshnessScore(mostRecent);
  }
}

/// Represents a single status vote from a contribution
class StatusVote {
  final PathRateStatus status;
  final DateTime publishedAt;
  final int confirmCount;
  final String? userId;

  StatusVote({
    required this.status,
    required this.publishedAt,
    this.confirmCount = 0,
    this.userId,
  });
}
