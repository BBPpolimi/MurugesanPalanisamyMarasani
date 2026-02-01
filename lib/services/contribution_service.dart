import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contribution.dart';
import '../models/bike_path.dart';
import '../models/path_quality_report.dart';
import '../models/path_obstacle.dart';
import '../models/path_tag.dart';
import '../models/street_segment.dart';
import '../models/trip.dart';
import '../utils/polyline_utils.dart';
import 'path_service.dart';
import 'merge_service.dart';

/// Service for managing user Contributions.
/// Handles CRUD operations and state machine transitions.
class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PathService _pathService = PathService();
  final MergeService _mergeService = MergeService();
  final Uuid _uuid = const Uuid();

  String? _userId;

  void initialize(String userId) {
    _userId = userId;
  }

  /// Check if user is blocked
  Future<void> _checkNotBlocked() async {
    if (_userId == null) return;
    final doc = await _firestore.collection('blockedUsers').doc(_userId).get();
    if (doc.exists) {
      throw Exception('Your account has been suspended.');
    }
  }

  // ============ CREATE ============

  /// Create a manual contribution (starts as DRAFT)
  Future<Contribution> createManualContribution({
    required List<LatLng> geometry,
    required PathRateStatus statusRating,
    String? name,
    String? city,
    List<PathObstacle> obstacles = const [],
    List<PathTag> tags = const [],
  }) async {
    if (_userId == null) throw Exception('User not authenticated');
    await _checkNotBlocked();

    // Resolve canonical path_id
    final pathId = await _pathService.resolvePathIdFromGeometry(geometry, city);

    final now = DateTime.now();
    final contribution = Contribution(
      id: _uuid.v4(),
      userId: _userId!,
      pathId: pathId,
      tripId: null,
      name: name,
      source: ContributionSource.manual,
      state: ContributionState.draft,
      statusRating: statusRating,
      obstacles: obstacles,
      tags: tags,
      capturedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection('contributions')
        .doc(contribution.id)
        .set(contribution.toMap());

    return contribution;
  }

  /// Create an automatic contribution from a trip
  Future<Contribution> createAutomaticContribution({
    required String tripId,
    required List<LatLng> geometry,
    required PathRateStatus statusRating,
    String? city,
    List<PathObstacle> obstacles = const [],
    String? name,
    double distanceMeters = 0.0,
    bool isPublic = false,  // NEW: visibility option
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Resolve canonical path_id
    final pathId = await _pathService.resolvePathIdFromGeometry(geometry, city);

    // Encode GPS geometry to polyline
    final gpsPolyline = PolylineUtils.encodePolyline(geometry);

    final now = DateTime.now();
    
    // Set state based on visibility choice
    final state = isPublic 
        ? ContributionState.published 
        : ContributionState.privateSaved;

    final contribution = Contribution(
      id: _uuid.v4(),
      userId: _userId!,
      pathId: pathId,
      tripId: tripId,
      name: name,
      source: ContributionSource.automatic,
      state: state,
      statusRating: statusRating,
      obstacles: obstacles,
      tags: const [],
      distanceMeters: distanceMeters,
      gpsPolyline: gpsPolyline,           // NEW: store encoded polyline
      mapPreviewPolyline: gpsPolyline,     // Use GPS as preview too
      capturedAt: now,
      confirmedAt: now,                    // Set confirmedAt so contribution can be published later
      publishedAt: isPublic ? now : null,  // Set publishedAt if public
      createdAt: now,
      updatedAt: now,
    );

    // Calculate path score before saving
    final withScore = contribution.copyWith(
      pathScore: calculatePathScore(contribution),
    );

    await _firestore
        .collection('contributions')
        .doc(withScore.id)
        .set(withScore.toMap());

    return withScore;
  }

  // ============ READ ============

  /// Get all user's contributions
  Future<List<Contribution>> getMyContributions() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: _userId)
        .get();

    final contributions = snapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();

    contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return contributions;
  }

  /// Get contributions by state
  Future<List<Contribution>> getContributionsByState(
      ContributionState state) async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: _userId)
        .where('state', isEqualTo: state.name)
        .get();

    return snapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();
  }

  /// Get pending confirmations (for automatic trips awaiting review)
  Future<List<Contribution>> getPendingConfirmations() async {
    return getContributionsByState(ContributionState.pendingConfirmation);
  }

  /// Get contribution by ID
  Future<Contribution?> getContribution(String id) async {
    final doc = await _firestore.collection('contributions').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Contribution.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get contribution linked to a trip
  Future<Contribution?> getContributionByTripId(String tripId) async {
    final snapshot = await _firestore
        .collection('contributions')
        .where('tripId', isEqualTo: tripId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Contribution.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  // ============ STATE TRANSITIONS ============

  /// Save a draft contribution (DRAFT → PRIVATE_SAVED)
  Future<void> saveContribution(String id) async {
    await _transitionState(
      id,
      fromStates: [ContributionState.draft],
      toState: ContributionState.privateSaved,
    );
  }

  /// Confirm an automatic contribution (PENDING_CONFIRMATION → PRIVATE_SAVED)
  Future<void> confirmContribution(
    String id, {
    PathRateStatus? correctedStatus,
    List<PathObstacle>? correctedObstacles,
    String? name,
  }) async {
    final contribution = await getContribution(id);
    if (contribution == null) throw Exception('Contribution not found');

    if (contribution.state != ContributionState.pendingConfirmation) {
      throw Exception('Can only confirm contributions in pending state');
    }

    final now = DateTime.now();
    final updated = contribution.copyWith(
      state: ContributionState.privateSaved,
      confirmedAt: now,
      updatedAt: now,
      statusRating: correctedStatus,
      obstacles: correctedObstacles,
      name: name,
      version: contribution.version + 1,
    );

    await _firestore
        .collection('contributions')
        .doc(id)
        .update(updated.toMap());
  }

  /// Publish a contribution (PRIVATE_SAVED → PUBLISHED)
  Future<void> publishContribution(String id) async {
    var contribution = await getContribution(id);
    if (contribution == null) throw Exception('Contribution not found');

    // Auto-confirm legacy automatic contributions that don't have confirmedAt
    if (contribution.source == ContributionSource.automatic &&
        contribution.confirmedAt == null) {
      final now = DateTime.now();
      contribution = contribution.copyWith(
        confirmedAt: now,
        updatedAt: now,
      );
      // Update the confirmedAt in database first
      await _firestore
          .collection('contributions')
          .doc(id)
          .update({'confirmedAt': now, 'updatedAt': now});
    }

    // Re-check canPublish with updated contribution
    if (!contribution.canPublish) {
      throw Exception('Contribution cannot be published in current state');
    }

    final now = DateTime.now();
    final updated = contribution.copyWith(
      state: ContributionState.published,
      publishedAt: now,
      updatedAt: now,
      version: contribution.version + 1,
    );

    await _firestore
        .collection('contributions')
        .doc(id)
        .update(updated.toMap());

    // Trigger merge update for the path
    await _mergeService.recomputeMergedPathInfo(contribution.pathId);
  }

  /// Unpublish a contribution (PUBLISHED → PRIVATE_SAVED)
  Future<void> unpublishContribution(String id) async {
    await _transitionState(
      id,
      fromStates: [ContributionState.published],
      toState: ContributionState.privateSaved,
    );

    // Re-trigger merge update
    final contribution = await getContribution(id);
    if (contribution != null) {
      await _mergeService.recomputeMergedPathInfo(contribution.pathId);
    }
  }

  /// Archive/delete a contribution
  Future<void> archiveContribution(String id) async {
    final contribution = await getContribution(id);
    if (contribution == null) throw Exception('Contribution not found');

    final pathId = contribution.pathId;
    final wasPublished = contribution.state == ContributionState.published;

    final updated = contribution.copyWith(
      state: ContributionState.archived,
      updatedAt: DateTime.now(),
      version: contribution.version + 1,
    );

    await _firestore
        .collection('contributions')
        .doc(id)
        .update(updated.toMap());

    // Re-trigger merge if was published
    if (wasPublished) {
      await _mergeService.recomputeMergedPathInfo(pathId);
    }
  }

  /// Hard delete a contribution
  Future<void> deleteContribution(String id) async {
    if (_userId == null) return;
    await _firestore.collection('contributions').doc(id).delete();
  }

  // ============ UPDATE ============

  /// Update contribution details
  Future<void> updateContribution(Contribution contribution) async {
    if (_userId == null) throw Exception('User not authenticated');
    if (contribution.userId != _userId) {
      throw Exception('Not authorized to update this contribution');
    }

    final updated = contribution.copyWith(
      updatedAt: DateTime.now(),
      version: contribution.version + 1,
    );

    await _firestore
        .collection('contributions')
        .doc(contribution.id)
        .update(updated.toMap());
  }

  /// Rename a contribution
  Future<void> renameContribution(String id, String newName) async {
    await _firestore.collection('contributions').doc(id).update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ HELPERS ============

  Future<void> _transitionState(
    String id, {
    required List<ContributionState> fromStates,
    required ContributionState toState,
  }) async {
    final contribution = await getContribution(id);
    if (contribution == null) throw Exception('Contribution not found');

    if (!fromStates.contains(contribution.state)) {
      throw Exception(
          'Invalid state transition from ${contribution.state.name} to ${toState.name}');
    }

    final updated = contribution.copyWith(
      state: toState,
      updatedAt: DateTime.now(),
      version: contribution.version + 1,
    );

    await _firestore
        .collection('contributions')
        .doc(id)
        .update(updated.toMap());
  }

  // ============ PATH SCORE CALCULATION ============

  /// Calculate path score based on status, obstacles, and tags
  /// Returns a score from 0-100
  static double calculatePathScore(Contribution c) {
    double score = 50.0; // Base score

    // Status rating factor (0-40 points)
    score += switch (c.statusRating) {
      PathRateStatus.optimal => 40,
      PathRateStatus.medium => 25,
      PathRateStatus.sufficient => 10,
      PathRateStatus.requiresMaintenance => -10,
    };

    // Obstacle penalty (-2 per obstacle, max -20)
    final obstaclePenalty = c.obstacles.length * 2;
    score -= obstaclePenalty > 20 ? 20 : obstaclePenalty;

    // Tag bonuses (+2 per positive tag)
    score += c.tags.where((t) => _isPositiveTag(t)).length * 2;
    
    // Tag penalties (-2 per negative tag)
    score -= c.tags.where((t) => _isNegativeTag(t)).length * 2;

    return score.clamp(0, 100);
  }

  static bool _isPositiveTag(PathTag tag) {
    return switch (tag) {
      PathTag.bikeLanePresent => true,
      PathTag.lowTraffic => true,
      PathTag.scenic => true,
      PathTag.lightingGood => true,
      PathTag.familyFriendly => true,
      _ => false,
    };
  }

  static bool _isNegativeTag(PathTag tag) {
    return switch (tag) {
      PathTag.avoidAtNight => true,
      PathTag.steepHills => true,
      _ => false,
    };
  }

  // ============ ADDITIONAL QUERIES ============

  /// Convert legacy BikePath to Contribution
  Contribution _convertBikePathToContribution(Map<String, dynamic> data) {
    final now = DateTime.now();
    // Manual string check for enum conversion to avoid runtime errors
    // We strictly use toString().split('.').last to avoid NoSuchMethodError on .name
    final statusString = data['status'].toString();
    // If data['status'] stored 'PathRateStatus.optimal', split also works.
    // If stored 'optimal', split works on enum string.
    final status = PathRateStatus.values.firstWhere(
      (s) => s.toString().split('.').last == statusString || s.toString() == statusString,
      orElse: () => PathRateStatus.medium,
    );
    final visibility = data['visibility'] == 'published' 
        ? PathVisibility.published 
        : PathVisibility.private;
    
    List<StreetSegment> segments = [];
    if (data['segments'] != null) {
      segments = (data['segments'] as List)
          .map((s) => StreetSegment.fromMap(s as Map<String, dynamic>))
          .toList();
    }
    
    List<PathObstacle> obstacles = [];
    if (data['obstacles'] != null) {
      obstacles = (data['obstacles'] as List)
          .map((o) => PathObstacle.fromMap(o as Map<String, dynamic>))
          .toList();
    }
    
    List<PathTag> tags = [];
    if (data['tags'] != null) {
      tags = (data['tags'] as List)
          .map((t) => PathTag.values.firstWhere((e) => e.name == t, orElse: () => PathTag.lowTraffic))
          .toList();
    }

    return Contribution(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      pathId: data['id'] ?? '',
      tripId: null,
      name: data['name'],
      source: ContributionSource.manual,
      state: visibility == PathVisibility.published 
          ? ContributionState.published 
          : ContributionState.privateSaved,
      statusRating: status,
      obstacles: obstacles,
      tags: tags,
      segments: segments,
      gpsPolyline: null,
      mapPreviewPolyline: data['mapPreviewPolyline'],
      distanceMeters: (data['distanceMeters'] ?? 0.0).toDouble(),
      city: data['city'],
      deleted: data['deleted'] ?? false,
      pathScore: null,
      capturedAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.parse(data['createdAt']))
          : now,
      confirmedAt: now,
      publishedAt: data['publishedAt'] != null 
          ? (data['publishedAt'] is Timestamp 
              ? (data['publishedAt'] as Timestamp).toDate() 
              : DateTime.parse(data['publishedAt']))
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.parse(data['createdAt']))
          : now,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] is Timestamp 
              ? (data['updatedAt'] as Timestamp).toDate() 
              : DateTime.parse(data['updatedAt']))
          : now,
      version: data['version'] ?? 1,
    );
  }

  /// Convert Trip to Contribution
  Contribution _convertTripToContribution(Trip trip) {
    final now = DateTime.now();
    
    // Encode gps points to polyline
    final points = trip.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final encodedPolyline = PolylineUtils.encodePolyline(points);
    
    // Determine status based on average speed (simple heuristic)
    final status = trip.averageSpeed > 20 
        ? PathRateStatus.optimal 
        : PathRateStatus.medium;

    return Contribution(
      id: trip.id, // Use trip ID as contribution ID for display
      userId: trip.userId,
      pathId: trip.id,
      tripId: trip.id,
      name: trip.name ?? 'Trip ${trip.startTime.day}/${trip.startTime.month}',
      source: ContributionSource.automatic,
      state: ContributionState.privateSaved,
      statusRating: status,
      obstacles: [],
      tags: [],
      segments: [],
      gpsPolyline: encodedPolyline,
      mapPreviewPolyline: encodedPolyline, // Use GPS trace as preview initially
      distanceMeters: trip.distanceMeters,
      city: null, // Could geo-code this if needed
      deleted: false,
      pathScore: 50.0, // Default score
      capturedAt: trip.startTime,
      confirmedAt: now,
      publishedAt: null,
      createdAt: trip.startTime,
      updatedAt: trip.endTime,
      version: 1,
    );
  }

  /// Get user's draft/private contributions (includes automatic trips)
  Future<List<Contribution>> getMyDraftContributions() async {
    if (_userId == null) return [];

    // 1. Query ALL contributions to deduplicate trips
    final allContribsSnapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: _userId)
        .where('deleted', isEqualTo: false)
        .get();

    final allContributions = allContribsSnapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();

    // Filter for just drafts to return
    final draftContributions = allContributions.where((c) => c.isDraft).toList();

    // 2. Query trips collection for automatic recordings
    final tripsSnapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .get();

    final trips = tripsSnapshot.docs
        .map((doc) => Trip.fromJson(doc.data()))
        .toList();

    // 3. Convert trips that are NOT already in contributions
    final convertedTripIds = allContributions
        .where((c) => c.tripId != null)
        .map((c) => c.tripId!)
        .toSet();

    final tripContributions = trips
        .where((t) => !convertedTripIds.contains(t.id))
        .map((t) => _convertTripToContribution(t))
        .toList();

    // 4. Merge all (Drafts + Unconverted Trips)
    final merged = <String, Contribution>{};
    
    // Create a lookup map for trips to enrich contributions
    final tripMap = {for (var t in trips) t.id: t};

    // Add real draft contributions first (priority)
    for (final c in draftContributions) {
      // Heal missing name/distance for automatic trips if possible
      Contribution contribToAdd = c;
      if (c.tripId != null && tripMap.containsKey(c.tripId)) {
        final trip = tripMap[c.tripId]!;
        final hasGenericName = c.name == null || c.name!.isEmpty || c.name == 'Untitled Path';
        final hasZeroDistance = c.distanceMeters == 0 && trip.distanceMeters > 0;
        
        if (hasGenericName || hasZeroDistance) {
           final newName = hasGenericName ? (trip.name ?? c.name) : c.name;
           final newDistance = hasZeroDistance ? trip.distanceMeters : c.distanceMeters;
           
           contribToAdd = c.copyWith(
             name: newName,
             distanceMeters: newDistance,
           );
           
           // Persist the fix to Firestore
           _firestore.collection('contributions').doc(c.id).update({
             if (hasGenericName) 'name': newName,
             if (hasZeroDistance) 'distanceMeters': newDistance,
           });
        }
      }
      merged[c.id] = contribToAdd;
    }
    
    // Add unconverted trips
    for (final c in tripContributions) {
      if (!merged.containsKey(c.id)) merged[c.id] = c;
    }

    final result = merged.values.toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  /// Get user's published contributions
  Future<List<Contribution>> getMyPublishedContributions() async {
    if (_userId == null) return [];

    // Query contributions with state = 'published'
    final contribSnapshot = await _firestore
        .collection('contributions')
        .where('userId', isEqualTo: _userId)
        .where('state', isEqualTo: 'published')
        .where('deleted', isEqualTo: false)
        .get();

    final contributions = contribSnapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();

    contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return contributions;
  }

  /// Get all public contributions (for community browsing)
  Future<List<Contribution>> getPublicContributions() async {
    final snapshot = await _firestore
        .collection('contributions')
        .where('state', isEqualTo: 'published')
        .where('deleted', isEqualTo: false)
        .get();

    final contributions = snapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();

    contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return contributions;
  }

  /// Add a contribution with PathScore computed
  Future<Contribution> addContribution(Contribution contribution) async {
    if (_userId == null) throw Exception('User not authenticated');
    await _checkNotBlocked();

    // Compute PathScore before saving
    final withScore = contribution.copyWith(
      pathScore: calculatePathScore(contribution),
    );

    await _firestore
        .collection('contributions')
        .doc(withScore.id)
        .set(withScore.toMap());

    return withScore;
  }

  /// Toggle publish status
  Future<void> togglePublish(String id, bool publish) async {
    if (publish) {
      await publishContribution(id);
    } else {
      await unpublishContribution(id);
    }
  }
}

