import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contribution.dart';
import '../models/path_quality_report.dart';
import '../models/path_obstacle.dart';
import '../models/path_tag.dart';
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

  /// Create an automatic contribution from a trip (starts as PENDING_CONFIRMATION)
  Future<Contribution> createAutomaticContribution({
    required String tripId,
    required List<LatLng> geometry,
    required PathRateStatus statusRating,
    String? city,
    List<PathObstacle> obstacles = const [],
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Resolve canonical path_id
    final pathId = await _pathService.resolvePathIdFromGeometry(geometry, city);

    final now = DateTime.now();
    final contribution = Contribution(
      id: _uuid.v4(),
      userId: _userId!,
      pathId: pathId,
      tripId: tripId,
      name: null,
      source: ContributionSource.automatic,
      state: ContributionState.pendingConfirmation,
      statusRating: statusRating,
      obstacles: obstacles,
      tags: const [],
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
    final contribution = await getContribution(id);
    if (contribution == null) throw Exception('Contribution not found');

    if (!contribution.canPublish) {
      if (contribution.source == ContributionSource.automatic &&
          contribution.confirmedAt == null) {
        throw Exception('Automatic contributions must be confirmed first');
      }
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
}
