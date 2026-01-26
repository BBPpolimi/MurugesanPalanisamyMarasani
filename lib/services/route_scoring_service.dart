import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_candidate.dart';
import '../models/scored_route.dart';
import '../models/obstacle.dart';
import '../models/path_quality_report.dart';
import 'contribute_service.dart';

class RouteScoringService {
  final ContributeService _contributeService;

  // Radius in meters to consider DB items relevant to the route
  static const double _searchRadius = 50.0;

  RouteScoringService({required ContributeService contributeService})
      : _contributeService = contributeService;

  Future<List<ScoredRoute>> scoreAndRankRoutes(
      List<RouteCandidate> routes) async {
    // 1. Fetch all public data (Optimization: In a real app, query by bounds of all routes)
    final allObstacles = await _contributeService.getPublicObstacles();
    final allReports = await _contributeService.getPublicPathQualityReports();

    List<ScoredRoute> scoredRoutes = [];

    for (var route in routes) {
      scoredRoutes.add(_scoreRoute(route, allObstacles, allReports));
    }

    // 2. Sort by score descending
    scoredRoutes.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return scoredRoutes;
  }

  ScoredRoute _scoreRoute(RouteCandidate route, List<Obstacle> allObstacles,
      List<PathQualityReport> allReports) {
    // Filter items relevant to this route
    final nearbyObstacles = _filterNearbyObstacles(route, allObstacles);
    final nearbyReports = _filterNearbyReports(route, allReports);

    bool hasDbData = nearbyObstacles.isNotEmpty || nearbyReports.isNotEmpty;

    double qualityScore = 0.7; // Start at Medium implicit
    double obstaclePenalty = 0.0;
    List<String> explanations = [];

    // --- Compute Quality ---
    if (nearbyReports.isNotEmpty) {
      double totalQuality = 0.0;
      for (var report in nearbyReports) {
        totalQuality += _getQualityWeight(report.status);
      }
      qualityScore = totalQuality / nearbyReports.length;

      if (qualityScore > 0.8) {
        explanations.add("Excellent surface quality");
      } else if (qualityScore < 0.4) {
        explanations.add("Poor surface reported");
      } else {
        explanations.add("Average surface quality");
      }
    } else {
      // If no reports, we iterate on qualityScore = 0.7 but don't claim we have data
    }

    // --- Compute Obstacles ---
    if (nearbyObstacles.isNotEmpty) {
      for (var obs in nearbyObstacles) {
        obstaclePenalty += _getObstacleWeight(obs.severity);
      }
      explanations.add("${nearbyObstacles.length} obstacle(s) on route");
    } else if (hasDbData) {
      explanations.add("No reported obstacles");
    }

    // --- Final Score Computation ---
    double finalScore;
    if (!hasDbData) {
      finalScore = 0.5; // Neutral
      explanations.add("No community data available");
    } else {
      // Base calculation: Quality minus Obstacles
      // We weight quality heavily
      finalScore = qualityScore - obstaclePenalty;

      // Bonus/Penalty logic refinement
      // If we have ONLY obstacles, start from 1.0 (assuming optimal path) and subtract?
      // No, sticking to: Quality (default 0.7) - Penalty.
    }

    // Clamp score
    finalScore = finalScore.clamp(0.0, 1.0);

    return ScoredRoute(
      route: route,
      totalScore: finalScore,
      qualityScore: qualityScore,
      obstaclePenalty: obstaclePenalty,
      explanations: explanations,
      nearbyObstacles: nearbyObstacles,
      nearbyReports: nearbyReports,
      hasDbData: hasDbData,
    );
  }

  // --- Filtering Helpers ---

  List<Obstacle> _filterNearbyObstacles(
      RouteCandidate route, List<Obstacle> obstacles) {
    return obstacles.where((obs) {
      // 1. Fast Bounds Check
      if (!_boundsContains(route.bounds, obs.lat, obs.lng)) return false;
      // 2. Proximity Check to Polyline
      return _isNearPolyline(obs.lat, obs.lng, route.polylinePoints);
    }).toList();
  }

  List<PathQualityReport> _filterNearbyReports(
      RouteCandidate route, List<PathQualityReport> reports) {
    return reports.where((rep) {
      if (!_boundsContains(route.bounds, rep.lat, rep.lng)) return false;
      return _isNearPolyline(rep.lat, rep.lng, route.polylinePoints);
    }).toList();
  }

  bool _boundsContains(LatLngBounds bounds, double lat, double lng) {
    // Expand bounds slightly for buffer
    return lat >= bounds.southwest.latitude - 0.001 &&
        lat <= bounds.northeast.latitude + 0.001 &&
        lng >= bounds.southwest.longitude - 0.001 &&
        lng <= bounds.northeast.longitude + 0.001;
  }

  bool _isNearPolyline(double lat, double lng, List<LatLng> polyline) {
    if (polyline.isEmpty) return false;

    // Check start point
    if (Geolocator.distanceBetween(
            lat, lng, polyline.first.latitude, polyline.first.longitude) <=
        _searchRadius) {
      return true;
    }

    // Check each segment
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];

      // Calculate distance from point (lat,lng) to segment (p1, p2)
      // Since we are working with small distances (meters), we can approximate using local projection
      // or simple Flat Earth for segments, but Geolocator doesn't support "distance to line".
      //
      // We'll implement a simple cross-track distance using geometric approximation logic.
      // Convert to meters using one degree approx (rough but enough for >50m checks?)
      // No, explicit geometric conversion is safer.

      double dist = _distanceToSegment(
          lat, lng, p1.latitude, p1.longitude, p2.latitude, p2.longitude);
      if (dist <= _searchRadius) return true;
    }
    return false;
  }

  // Returns distance in meters
  double _distanceToSegment(double lat, double lng, double lat1, double lng1,
      double lat2, double lng2) {
    // 1. Convert to Cartesian (approximation for small area)
    // center lat for scaling
    double centerLat = (lat1 + lat2) / 2 * (math.pi / 180.0);
    double metersPerLat = 111320.0;
    double metersPerLng = 111320.0 * math.cos(centerLat);

    double x = lng * metersPerLng;
    double y = lat * metersPerLat;

    double x1 = lng1 * metersPerLng;
    double y1 = lat1 * metersPerLat;

    double x2 = lng2 * metersPerLng;
    double y2 = lat2 * metersPerLat;

    double A = x - x1;
    double B = y - y1;
    double C = x2 - x1;
    double D = y2 - y1;

    double dot = A * C + B * D;
    double lenSq = C * C + D * D;
    double param = -1;

    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    double dx = x - xx;
    double dy = y - yy;

    return math.sqrt(dx * dx + dy * dy);
  }

  // --- Weight Mappings ---

  double _getQualityWeight(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return 1.0;
      case PathRateStatus.medium:
        return 0.7;
      case PathRateStatus.sufficient:
        return 0.5;
      case PathRateStatus.requiresMaintenance:
        return 0.2;
    }
  }

  double _getObstacleWeight(ObstacleSeverity severity) {
    switch (severity) {
      case ObstacleSeverity.low:
        return 0.05;
      case ObstacleSeverity.medium:
        return 0.15;
      case ObstacleSeverity.high:
        return 0.30;
    }
  }
}
