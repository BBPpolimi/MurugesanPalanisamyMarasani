import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

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
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('trips');
  }

  Future<List<Trip>> getAllTrips() async {
    if (_userId == null) return [];
    
    try {
      final snapshot = await _tripsCollection
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Trip.fromJson(doc.data()))
          .toList();
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
        .map((snapshot) => snapshot.docs
            .map((doc) => Trip.fromJson(doc.data()))
            .toList());
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
}
