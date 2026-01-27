import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bike_path.dart';
import '../models/blocked_user.dart';
import '../models/audit_log.dart';

/// Admin service for moderation capabilities
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  String? _userEmail;
  bool _isAdmin = false;

  void initialize(String userId, bool isAdmin, {String? email}) {
    _userId = userId;
    _isAdmin = isAdmin;
    _userEmail = email;
  }

  bool get isAdmin => _isAdmin;

  // ============ CONTRIBUTION MANAGEMENT ============

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

    await _logAction(
      action: AdminAction.flagContribution,
      targetId: pathId,
      targetType: AuditTargetType.contribution,
      details: reason,
    );
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

    await _logAction(
      action: AdminAction.unflagContribution,
      targetId: pathId,
      targetType: AuditTargetType.contribution,
    );
  }

  /// Hard delete a contribution (admin only)
  Future<void> removeContribution(String pathId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('bike_paths').doc(pathId).delete();

    await _logAction(
      action: AdminAction.removeContribution,
      targetId: pathId,
      targetType: AuditTargetType.contribution,
    );
  }

  // ============ USER MANAGEMENT ============

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

    await _logAction(
      action: AdminAction.setUserRole,
      targetId: userId,
      targetType: AuditTargetType.user,
      details: 'Role set to: $role',
    );
  }

  // ============ USER BLOCKING ============

  /// Block a user
  Future<void> blockUser(String userId, String reason, {String? email, String? displayName}) async {
    if (!_isAdmin) throw Exception('Admin access required');
    if (_userId == null) throw Exception('Admin not initialized');

    final blockedUser = BlockedUser(
      userId: userId,
      blockedBy: _userId!,
      blockedAt: DateTime.now(),
      reason: reason,
      email: email,
      displayName: displayName,
    );

    await _firestore.collection('blockedUsers').doc(userId).set(blockedUser.toMap());

    await _logAction(
      action: AdminAction.blockUser,
      targetId: userId,
      targetType: AuditTargetType.user,
      details: reason,
    );
  }

  /// Unblock a user
  Future<void> unblockUser(String userId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('blockedUsers').doc(userId).delete();

    await _logAction(
      action: AdminAction.unblockUser,
      targetId: userId,
      targetType: AuditTargetType.user,
    );
  }

  /// Get all blocked users
  Future<List<BlockedUser>> getBlockedUsers() async {
    if (!_isAdmin) throw Exception('Admin access required');

    final snapshot = await _firestore.collection('blockedUsers').get();
    
    final users = snapshot.docs
        .map((doc) => BlockedUser.fromMap(doc.data()))
        .toList();

    users.sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    return users;
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    final doc = await _firestore.collection('blockedUsers').doc(userId).get();
    return doc.exists;
  }

  // ============ AUDIT LOGGING ============

  /// Log an admin action
  Future<void> _logAction({
    required AdminAction action,
    required String targetId,
    required AuditTargetType targetType,
    String? details,
  }) async {
    if (_userId == null) return;

    final logId = _firestore.collection('auditLogs').doc().id;
    final log = AuditLog(
      id: logId,
      adminId: _userId!,
      adminEmail: _userEmail,
      action: action,
      targetId: targetId,
      targetType: targetType,
      details: details,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('auditLogs').doc(logId).set(log.toMap());
  }

  /// Get audit logs with optional filtering
  Future<List<AuditLog>> getAuditLogs({
    int limit = 100,
    AdminAction? filterByAction,
  }) async {
    if (!_isAdmin) throw Exception('Admin access required');

    Query query = _firestore.collection('auditLogs');

    if (filterByAction != null) {
      query = query.where('action', isEqualTo: filterByAction.name);
    }

    final snapshot = await query.limit(limit).get();

    final logs = snapshot.docs
        .map((doc) => AuditLog.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    // Sort in memory (descending by timestamp)
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  /// Get audit logs for a specific target
  Future<List<AuditLog>> getAuditLogsForTarget(String targetId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    final snapshot = await _firestore
        .collection('auditLogs')
        .where('targetId', isEqualTo: targetId)
        .get();

    final logs = snapshot.docs
        .map((doc) => AuditLog.fromMap(doc.data()))
        .toList();

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }
}
