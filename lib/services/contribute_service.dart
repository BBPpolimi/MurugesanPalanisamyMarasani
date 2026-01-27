import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bike_path.dart';
import '../models/obstacle.dart';
import '../models/path_quality_report.dart';
import 'path_group_service.dart';

class ContributeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  void initialize(String userId) {
    _userId = userId;
  }

  /// Check if the current user is blocked (throws if blocked)
  Future<void> _checkNotBlocked() async {
    if (_userId == null) return;
    final doc = await _firestore.collection('blockedUsers').doc(_userId).get();
    if (doc.exists) {
      throw Exception('Your account has been suspended. Please contact support.');
    }
  }

  // --- Bike Paths (Manual Mode) ---

  Future<void> addBikePath(BikePath path) async {
    if (_userId == null) throw Exception('User not authenticated');
    await _checkNotBlocked();

    // Compute normalized key for future merging
    final normalizedKey = _computeNormalizedKey(path.segments, path.city);
    final pathWithKey = path.copyWith(normalizedKey: normalizedKey);

    await _firestore.collection('bike_paths').doc(path.id).set(pathWithKey.toMap());
  }

  Future<void> updateBikePath(BikePath path) async {
    if (_userId == null) throw Exception('User not authenticated');
    if (path.userId != _userId) throw Exception('Not authorized to update this path');

    final updated = path.copyWith(
      updatedAt: DateTime.now(),
      version: path.version + 1,
    );

    await _firestore.collection('bike_paths').doc(path.id).update(updated.toMap());
  }

  Future<void> togglePublish(String pathId, bool publish) async {
    if (_userId == null) throw Exception('User not authenticated');

    final updateData = <String, dynamic>{
      'visibility': publish ? PathVisibility.published.name : PathVisibility.private.name,
      'publishable': publish, // Legacy field
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (publish) {
      updateData['publishedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('bike_paths').doc(pathId).update(updateData);

    // Trigger client-side merge if publishing (Spark plan - no Cloud Functions)
    if (publish) {
      try {
        final doc = await _firestore.collection('bike_paths').doc(pathId).get();
        final normalizedKey = doc.data()?['normalizedKey'];
        if (normalizedKey != null) {
          final pathGroupService = PathGroupService();
          await pathGroupService.recomputePathGroupLocally(normalizedKey);
        }
      } catch (e) {
        // Log but don't fail - merge is best-effort
        print('Merge error: $e');
      }
    }
  }

  Future<void> softDeleteBikePath(String pathId) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore.collection('bike_paths').doc(pathId).update({
      'deleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<BikePath>> getMyBikePaths() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('bike_paths')
        .where('userId', isEqualTo: _userId)
        .where('deleted', isEqualTo: false)
        .get();

    final paths =
        snapshot.docs.map((doc) => BikePath.fromMap(doc.data())).toList();

    // Sort in memory to avoid Firestore Composite Index requirement
    paths.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return paths;
  }

  Future<List<BikePath>> getMyDraftPaths() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('bike_paths')
        .where('userId', isEqualTo: _userId)
        .where('deleted', isEqualTo: false)
        .get();

    final paths = snapshot.docs
        .map((doc) => BikePath.fromMap(doc.data()))
        .where((p) => p.visibility == PathVisibility.private)
        .toList();

    paths.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return paths;
  }

  Future<List<BikePath>> getMyPublishedPaths() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('bike_paths')
        .where('userId', isEqualTo: _userId)
        .where('deleted', isEqualTo: false)
        .get();

    final paths = snapshot.docs
        .map((doc) => BikePath.fromMap(doc.data()))
        .where((p) => p.visibility == PathVisibility.published)
        .toList();

    paths.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return paths;
  }

  Future<List<BikePath>> getPublicBikePaths() async {
    final snapshot = await _firestore
        .collection('bike_paths')
        .where('visibility', isEqualTo: PathVisibility.published.name)
        .where('deleted', isEqualTo: false)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) => BikePath.fromMap(doc.data())).toList();
  }

  Future<void> deleteBikePath(String pathId) async {
    if (_userId == null) return;
    await _firestore.collection('bike_paths').doc(pathId).delete();
  }

  Future<void> renameBikePath(String pathId, String newName) async {
    if (_userId == null) return;
    await _firestore
        .collection('bike_paths')
        .doc(pathId)
        .update({
          'name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Compute a normalized key from street segments for future merging
  String _computeNormalizedKey(List<dynamic> segments, String? city) {
    final streetNames = segments
        .map((s) => s.streetName.toLowerCase().trim())
        .join('|');
    final cityPart = (city ?? 'unknown').toLowerCase().trim();
    return '$cityPart:$streetNames'.hashCode.toString();
  }

  // --- Path Quality Reports ---

  Future<void> addPathQualityReport(PathQualityReport report) async {
    if (_userId == null) throw Exception('User not authenticated');
    await _checkNotBlocked();

    await _firestore
        .collection('path_quality_reports')
        .doc(report.id)
        .set(report.toMap());
  }

  Future<List<PathQualityReport>> getMyPathQualityReports() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('path_quality_reports')
        .where('userId', isEqualTo: _userId)
        .get();

    final reports = snapshot.docs
        .map((doc) => PathQualityReport.fromMap(doc.data()))
        .toList();

    // Sort in memory
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  // Fetch publishable reports (for map view)
  // In a real app, this would benefit from GeoHashing or bounds querying.
  Future<List<PathQualityReport>> getPublicPathQualityReports() async {
    final snapshot = await _firestore
        .collection('path_quality_reports')
        .where('publishable', isEqualTo: true)
        // .orderBy('createdAt', descending: true) // indexing might be needed
        .limit(100) // Limit for MVP
        .get();

    return snapshot.docs
        .map((doc) => PathQualityReport.fromMap(doc.data()))
        .toList();
  }

  Future<void> deletePathQualityReport(String reportId) async {
    if (_userId == null) return;
    // Ensure ownership check on server side (security rules) or client side check if strict
    await _firestore.collection('path_quality_reports').doc(reportId).delete();
  }

  // --- Obstacles ---

  Future<void> addObstacle(Obstacle obstacle) async {
    if (_userId == null) throw Exception('User not authenticated');
    await _checkNotBlocked();

    await _firestore
        .collection('obstacles')
        .doc(obstacle.id)
        .set(obstacle.toMap());
  }

  Future<List<Obstacle>> getMyObstacles() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('obstacles')
        .where('userId', isEqualTo: _userId)
        .get();

    final obstacles =
        snapshot.docs.map((doc) => Obstacle.fromMap(doc.data())).toList();

    // Sort in memory
    obstacles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return obstacles;
  }

  Future<List<Obstacle>> getPublicObstacles() async {
    final snapshot = await _firestore
        .collection('obstacles')
        .where('publishable', isEqualTo: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) => Obstacle.fromMap(doc.data())).toList();
  }

  Future<void> deleteObstacle(String obstacleId) async {
    if (_userId == null) return;
    await _firestore.collection('obstacles').doc(obstacleId).delete();
  }
}
