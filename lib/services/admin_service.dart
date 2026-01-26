import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bike_path.dart';

/// Admin service for moderation capabilities
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  bool _isAdmin = false;

  void initialize(String userId, bool isAdmin) {
    _userId = userId;
    _isAdmin = isAdmin;
  }

  bool get isAdmin => _isAdmin;

  /// Get all contributions (for admin review)
  Future<List<BikePath>> getAllContributions({String? filterVisibility}) async {
    if (!_isAdmin) throw Exception('Admin access required');

    Query query = _firestore.collection('bike_paths');
    
    if (filterVisibility != null) {
      query = query.where('visibility', isEqualTo: filterVisibility);
    }

    final snapshot = await query.limit(200).get();
    
    final paths = snapshot.docs
        .map((doc) => BikePath.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    paths.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return paths;
  }

  /// Get flagged contributions for review
  Future<List<BikePath>> getFlaggedContributions() async {
    if (!_isAdmin) throw Exception('Admin access required');

    final snapshot = await _firestore
        .collection('bike_paths')
        .where('visibility', isEqualTo: PathVisibility.flagged.name)
        .get();

    final paths = snapshot.docs
        .map((doc) => BikePath.fromMap(doc.data()))
        .toList();

    paths.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return paths;
  }

  /// Flag a contribution for review
  Future<void> flagContribution(String pathId, String reason) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('bike_paths').doc(pathId).update({
      'visibility': PathVisibility.flagged.name,
      'flagReason': reason,
      'flaggedBy': _userId,
      'flaggedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unflag a contribution (restore to published)
  Future<void> unflagContribution(String pathId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('bike_paths').doc(pathId).update({
      'visibility': PathVisibility.published.name,
      'publishable': true,
      'flagReason': FieldValue.delete(),
      'flaggedBy': FieldValue.delete(),
      'flaggedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hard delete a contribution (admin only)
  Future<void> removeContribution(String pathId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('bike_paths').doc(pathId).delete();
  }

  /// Get user role from Firestore
  Future<String?> getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
    return null;
  }

  /// Set user role (super admin only - use with caution)
  Future<void> setUserRole(String userId, String role) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
