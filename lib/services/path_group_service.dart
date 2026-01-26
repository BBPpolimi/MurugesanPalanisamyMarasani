import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/path_group.dart';
import '../models/obstacle_cluster.dart';
import '../models/bike_path.dart';
import '../models/path_quality_report.dart';
import '../utils/scoring.dart';

/// Service for managing path groups (merged views)
class PathGroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all path groups (merged views)
  Future<List<PathGroup>> getPathGroups({
    String? city,
    String? areaGeohash,
    PathRateStatus? status,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('pathGroups');
    
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    if (areaGeohash != null) {
      // Prefix match for geohash
      query = query.where('areaGeohash', isGreaterThanOrEqualTo: areaGeohash)
                   .where('areaGeohash', isLessThan: '${areaGeohash}z');
    }
    if (status != null) {
      query = query.where('mergedStatus', isEqualTo: status.name);
    }
    
    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) => PathGroup.fromMap(doc.data())).toList();
  }

  /// Get a single path group by ID
  Future<PathGroup?> getPathGroup(String groupId) async {
    final doc = await _firestore.collection('pathGroups').doc(groupId).get();
    if (!doc.exists) return null;
    return PathGroup.fromMap(doc.data()!);
  }

  /// Get path group by normalized key
  Future<PathGroup?> getPathGroupByKey(String normalizedKey) async {
    final snapshot = await _firestore
        .collection('pathGroups')
        .where('normalizedKey', isEqualTo: normalizedKey)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    return PathGroup.fromMap(snapshot.docs.first.data());
  }

  /// Get obstacle clusters for a path group
  Future<List<ObstacleCluster>> getObstacleClusters(String groupId) async {
    final snapshot = await _firestore
        .collection('pathGroups')
        .doc(groupId)
        .collection('obstacleClusters')
        .where('decayed', isEqualTo: false)
        .get();
    
    return snapshot.docs
        .map((doc) => ObstacleCluster.fromMap(doc.data()))
        .toList();
  }

  /// Get path groups near a location
  Future<List<PathGroup>> getPathGroupsNearLocation({
    required double lat,
    required double lng,
    int radiusKm = 10,
    int limit = 50,
  }) async {
    // Compute geohash for the location
    final geohash = ObstacleClusterUtils.encodeGeohash(lat, lng, precision: 4);
    
    final snapshot = await _firestore
        .collection('pathGroups')
        .where('areaGeohash', isGreaterThanOrEqualTo: geohash)
        .where('areaGeohash', isLessThan: '${geohash}z')
        .limit(limit)
        .get();
    
    return snapshot.docs
        .map((doc) => PathGroup.fromMap(doc.data()))
        .toList();
  }

  /// Stream path groups for real-time updates
  Stream<List<PathGroup>> streamPathGroups({String? city}) {
    Query<Map<String, dynamic>> query = _firestore.collection('pathGroups');
    
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    
    return query.limit(100).snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => PathGroup.fromMap(doc.data())).toList()
    );
  }

  // ============ LOCAL MERGE (for when Cloud Functions are not available) ============

  /// Recompute merged status locally (for development/testing)
  /// In production, this should be done via Cloud Functions
  Future<void> recomputePathGroupLocally(String normalizedKey) async {
    // 1. Fetch all published contributions for this key
    final contributionsSnapshot = await _firestore
        .collection('bike_paths')
        .where('normalizedKey', isEqualTo: normalizedKey)
        .where('visibility', isEqualTo: PathVisibility.published.name)
        .where('deleted', isEqualTo: false)
        .get();

    if (contributionsSnapshot.docs.isEmpty) {
      return; // No contributions to merge
    }

    final contributions = contributionsSnapshot.docs
        .map((doc) => BikePath.fromMap(doc.data()))
        .toList();

    // 2. Compute status votes
    final votes = contributions.map((c) => StatusVote(
      status: c.status,
      publishedAt: c.publishedAt ?? c.createdAt,
      userId: c.userId,
    )).toList();

    final mergedStatus = MergeAlgorithm.computeMergedStatus(votes);
    final statusVotes = MergeAlgorithm.votesToMap(votes);

    // 3. Compute freshness
    final publishDates = contributions
        .map((c) => c.publishedAt ?? c.createdAt)
        .toList();
    final freshnessScore = MergeAlgorithm.computeFreshnessScore(publishDates);

    // 4. Count unique contributors
    final uniqueContributors = contributions.map((c) => c.userId).toSet();

    // 5. Gather obstacles
    final allObstacles = contributions.expand((c) => c.obstacles).toList();
    final obstaclesSummary = _computeObstaclesSummary(allObstacles);

    // 6. Get representative data from first contribution
    final representative = contributions.first;
    final groupId = normalizedKey;

    // 7. Upsert path group
    await _firestore.collection('pathGroups').doc(groupId).set({
      'id': groupId,
      'normalizedKey': normalizedKey,
      'city': representative.city,
      'areaGeohash': representative.segments.isNotEmpty
          ? ObstacleClusterUtils.encodeGeohash(
              representative.segments.first.lat,
              representative.segments.first.lng,
              precision: 6,
            )
          : null,
      'representativePolyline': representative.mapPreviewPolyline,
      'mergedStatus': mergedStatus.name,
      'statusVotes': statusVotes,
      'freshnessScore': freshnessScore,
      'confirmations': contributions.length,
      'contributorCount': uniqueContributors.length,
      'distanceMeters': representative.distanceMeters,
      'obstaclesSummary': obstaclesSummary.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  ObstaclesSummary _computeObstaclesSummary(List<dynamic> obstacles) {
    if (obstacles.isEmpty) return ObstaclesSummary.empty();

    final bySeverity = List<int>.filled(5, 0);
    final byType = <String, int>{};

    for (final obs in obstacles) {
      final severity = (obs.severity as int).clamp(1, 5);
      bySeverity[severity - 1]++;

      final type = obs.type.name as String;
      byType[type] = (byType[type] ?? 0) + 1;
    }

    return ObstaclesSummary(
      total: obstacles.length,
      bySeverity: bySeverity,
      byType: byType,
    );
  }
}
