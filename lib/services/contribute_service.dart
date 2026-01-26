import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bike_path.dart';
import '../models/obstacle.dart';
import '../models/path_quality_report.dart';

class ContributeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  void initialize(String userId) {
    _userId = userId;
  }

  // --- Bike Paths (Manual Mode) ---

  Future<void> addBikePath(BikePath path) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore.collection('bike_paths').doc(path.id).set(path.toMap());
  }

  Future<List<BikePath>> getMyBikePaths() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('bike_paths')
        .where('userId', isEqualTo: _userId)
        .get();

    final paths =
        snapshot.docs.map((doc) => BikePath.fromMap(doc.data())).toList();

    // Sort in memory to avoid Firestore Composite Index requirement
    paths.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return paths;
  }

  Future<List<BikePath>> getPublicBikePaths() async {
    final snapshot = await _firestore
        .collection('bike_paths')
        .where('publishable', isEqualTo: true)
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
        .update({'name': newName});
  }

  // --- Path Quality Reports ---

  Future<void> addPathQualityReport(PathQualityReport report) async {
    if (_userId == null) throw Exception('User not authenticated');

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
