import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/candidate_issue.dart';

class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  void initialize(String userId) {
    _userId = userId;
  }

  // Get collection reference for the current user's trips
  CollectionReference<Map<String, dynamic>> get _tripsCollection {
    if (_userId == null) {
      throw Exception('TripRepository not initialized with userId');
    }
    return _firestore.collection('users').doc(_userId).collection('trips');
  }

  Future<List<Trip>> getAllTrips() async {
    if (_userId == null) return [];

    try {
      final snapshot =
          await _tripsCollection.orderBy('startTime', descending: true).get();

      return snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching trips: $e');
      return [];
    }
  }

  Stream<List<Trip>> watchTrips() {
    if (_userId == null) return Stream.value([]);

    return _tripsCollection
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList());
  }

  Future<void> saveTrip(Trip trip) async {
    if (_userId == null) return;

    // Using trip.id as the document ID
    await _tripsCollection.doc(trip.id).set(trip.toJson());
  }

  Future<void> deleteTrip(String tripId) async {
    if (_userId == null) return;

    await _tripsCollection.doc(tripId).delete();
  }

  // --- Candidate Persistence ---

  /// Save candidates for a trip
  Future<void> saveCandidates(
      String tripId, List<CandidateIssue> candidates) async {
    if (_userId == null) return;

    final batch = _firestore.batch();
    final candidatesRef = _tripsCollection.doc(tripId).collection('candidates');

    for (final candidate in candidates) {
      batch.set(candidatesRef.doc(candidate.id), candidate.toMap());
    }

    await batch.commit();
  }

  /// Get candidates for a trip
  Future<List<CandidateIssue>> getCandidates(String tripId) async {
    if (_userId == null) return [];

    try {
      final snapshot =
          await _tripsCollection.doc(tripId).collection('candidates').get();

      return snapshot.docs
          .map((doc) => CandidateIssue.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching candidates: $e');
      return [];
    }
  }

  /// Update a candidate (confirm/reject/edit)
  Future<void> updateCandidate(String tripId, CandidateIssue candidate) async {
    if (_userId == null) return;

    await _tripsCollection
        .doc(tripId)
        .collection('candidates')
        .doc(candidate.id)
        .set(candidate.toMap());
  }

  /// Delete a candidate
  Future<void> deleteCandidate(String tripId, String candidateId) async {
    if (_userId == null) return;

    await _tripsCollection
        .doc(tripId)
        .collection('candidates')
        .doc(candidateId)
        .delete();
  }

  // --- Publishable Status ---

  /// Update trip's publishable status
  Future<void> updateTripPublishable(String tripId, bool isPublishable) async {
    if (_userId == null) return;

    await _tripsCollection.doc(tripId).update({
      'isPublishable': isPublishable,
    });
  }

  /// Update trip's confirmed obstacle IDs
  Future<void> updateTripConfirmedObstacles(
      String tripId, List<String> obstacleIds) async {
    if (_userId == null) return;

    await _tripsCollection.doc(tripId).update({
      'confirmedObstacleIds': obstacleIds,
    });
  }

  // --- Public Queries (for community viewing) ---

  /// Get all publishable trips from all users
  Future<List<Trip>> getPublishableTrips() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('trips')
          .where('isPublishable', isEqualTo: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList();
    } catch (e) {
      print('Error fetching publishable trips: $e');
      return [];
    }
  }

  /// Get a specific trip by ID (across all users, for public viewing)
  Future<Trip?> getPublicTrip(String tripId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('trips')
          .where('id', isEqualTo: tripId)
          .where('isPublishable', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Trip.fromJson(snapshot.docs.first.data());
      }
    } catch (e) {
      print('Error fetching public trip: $e');
    }
    return null;
  }
}
