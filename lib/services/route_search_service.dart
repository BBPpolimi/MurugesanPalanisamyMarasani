import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/ranked_route.dart';
import '../models/path_group.dart';
import '../models/path_quality_report.dart';
import '../utils/scoring.dart';
import 'path_group_service.dart';

/// Service for searching and ranking bike routes
class RouteSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PathGroupService _pathGroupService = PathGroupService();

  /// Google Directions API key (should be set from environment)
  String? _directionsApiKey;

  void setDirectionsApiKey(String key) {
    _directionsApiKey = key;
  }

  /// Search for routes between origin and destination
  /// Returns ranked list of candidates
  Future<RouteSearchResult> searchRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    RouteSearchOptions options = const RouteSearchOptions(),
  }) async {
    // Use local computation (Cloud Functions can be added later)
    return await _searchLocally(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      options: options,
    );
  }

  /// Local search using Directions API + BBP data
  Future<RouteSearchResult> _searchLocally({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required RouteSearchOptions options,
  }) async {
    // 1. Calculate direct distance
    final directDistance = RouteScoring.calculateDirectDistance(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    // 2. Try to get routes from Directions API
    List<DirectionsRoute> rawRoutes = [];
    if (_directionsApiKey != null && _directionsApiKey!.isNotEmpty) {
      rawRoutes = await _fetchDirectionsRoutes(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        alternatives: true,
      );
    }

    // 3. Get nearby path groups for annotation
    final nearbyGroups = await _pathGroupService.getPathGroupsNearLocation(
      lat: (originLat + destLat) / 2,
      lng: (originLng + destLng) / 2,
      radiusKm: 20,
    );

    // 4. Score and annotate routes
    final candidates = <RankedRoute>[];

    for (int i = 0; i < rawRoutes.length && i < 3; i++) {
      final route = rawRoutes[i];
      
      // Find matching path groups
      final matchedGroup = _findMatchingPathGroup(route, nearbyGroups);
      
      final status = matchedGroup?.mergedStatus ?? PathRateStatus.medium;
      final obstacleCount = matchedGroup?.obstaclesSummary.total ?? 0;
      final severityAvg = matchedGroup?.obstaclesSummary.averageSeverity ?? 0;
      final confirmations = matchedGroup?.confirmations ?? 0;
      final lastUpdated = matchedGroup?.updatedAt;

      final candidate = RouteScoring.scoreRoute(
        id: 'route_${i + 1}',
        name: 'Route ${i + 1}',
        encodedPolyline: route.polyline,
        distanceMeters: route.distanceMeters.toDouble(),
        directDistanceMeters: directDistance,
        durationSeconds: route.durationSeconds,
        status: status,
        obstacleCount: obstacleCount,
        obstaclesSeverityAvg: severityAvg,
        confirmations: confirmations,
        lastUpdated: lastUpdated,
        pathGroupId: matchedGroup?.id,
      );

      // Apply filters
      if (options.avoidMaintenance && status == PathRateStatus.requiresMaintenance) {
        continue;
      }

      candidates.add(candidate);
    }

    // 5. Add BBP-only routes if no Directions API routes
    if (candidates.isEmpty && nearbyGroups.isNotEmpty) {
      // Create candidates from path groups that span origin-destination area
      for (final group in nearbyGroups.take(3)) {
        final candidate = RouteScoring.scoreRoute(
          id: 'bbp_${group.id}',
          name: group.city ?? 'Community Path',
          encodedPolyline: group.representativePolyline ?? '',
          distanceMeters: group.distanceMeters,
          directDistanceMeters: directDistance,
          status: group.mergedStatus,
          obstacleCount: group.obstaclesSummary.total,
          obstaclesSeverityAvg: group.obstaclesSummary.averageSeverity,
          confirmations: group.confirmations,
          lastUpdated: group.updatedAt,
          pathGroupId: group.id,
        );
        candidates.add(candidate);
      }
    }

    // 6. Sort by score
    candidates.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return RouteSearchResult(
      candidates: candidates.take(3).toList(),
      searchedAt: DateTime.now(),
      fromCache: false,
    );
  }

  /// Fetch routes from Google Directions API
  Future<List<DirectionsRoute>> _fetchDirectionsRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    bool alternatives = true,
  }) async {
    if (_directionsApiKey == null) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$originLat,$originLng'
      '&destination=$destLat,$destLng'
      '&mode=bicycling'
      '&alternatives=$alternatives'
      '&key=$_directionsApiKey'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return [];

      final routes = <DirectionsRoute>[];
      for (final route in data['routes']) {
        final leg = route['legs'][0];
        routes.add(DirectionsRoute(
          polyline: route['overview_polyline']['points'],
          distanceMeters: leg['distance']['value'],
          durationSeconds: leg['duration']['value'],
          summary: route['summary'] ?? '',
        ));
      }
      return routes;
    } catch (e) {
      // Log error for debugging
      return [];
    }
  }

  /// Find a matching path group for a route
  PathGroup? _findMatchingPathGroup(DirectionsRoute route, List<PathGroup> groups) {
    // Simple matching: find group with similar polyline/distance
    // In production, this would use polyline comparison or geohash matching
    for (final group in groups) {
      if (group.representativePolyline != null &&
          group.representativePolyline!.isNotEmpty &&
          route.polyline.length >= 10 &&
          group.representativePolyline!.length >= 10) {
        // Simple heuristic: if polylines start similarly
        if (route.polyline.substring(0, 10) ==
            group.representativePolyline!.substring(0, 10)) {
          return group;
        }
      }
    }
    
    // Return first group as fallback for area-wide matching
    return groups.isNotEmpty ? groups.first : null;
  }

  /// Check cache for popular routes
  Future<RouteSearchResult?> checkCache(String cacheKey) async {
    final doc = await _firestore.collection('routesCache').doc(cacheKey).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final ttlSeconds = data['ttlSeconds'] ?? 3600;

    // Check if cache is still valid
    if (DateTime.now().difference(createdAt).inSeconds > ttlSeconds) {
      return null; // Cache expired
    }

    final candidates = (data['candidates'] as List)
        .map((c) => RankedRoute.fromMap(c as Map<String, dynamic>))
        .toList();

    return RouteSearchResult(
      candidates: candidates,
      searchedAt: createdAt,
      fromCache: true,
    );
  }

  /// Generate cache key for an OD pair
  String generateCacheKey(double originLat, double originLng, double destLat, double destLng) {
    // Use truncated coords for caching nearby queries
    final oLat = (originLat * 100).round();
    final oLng = (originLng * 100).round();
    final dLat = (destLat * 100).round();
    final dLng = (destLng * 100).round();
    return 'route_${oLat}_${oLng}_${dLat}_${dLng}';
  }
}

/// Result of a route search
class RouteSearchResult {
  final List<RankedRoute> candidates;
  final DateTime searchedAt;
  final bool fromCache;

  RouteSearchResult({
    required this.candidates,
    required this.searchedAt,
    this.fromCache = false,
  });

  bool get hasResults => candidates.isNotEmpty;
  RankedRoute? get bestRoute => candidates.isNotEmpty ? candidates.first : null;
}

/// Options for route search
class RouteSearchOptions {
  final bool avoidMaintenance;
  final bool preferBikeLanes;
  final bool avoidHighSeverityObstacles;
  final int maxCandidates;

  const RouteSearchOptions({
    this.avoidMaintenance = false,
    this.preferBikeLanes = false,
    this.avoidHighSeverityObstacles = false,
    this.maxCandidates = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'avoidMaintenance': avoidMaintenance,
      'preferBikeLanes': preferBikeLanes,
      'avoidHighSeverityObstacles': avoidHighSeverityObstacles,
      'maxCandidates': maxCandidates,
    };
  }
}

/// Raw directions route from API
class DirectionsRoute {
  final String polyline;
  final int distanceMeters;
  final int durationSeconds;
  final String summary;

  DirectionsRoute({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.summary,
  });
}
