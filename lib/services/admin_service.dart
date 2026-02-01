import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
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
  Future<List<Contribution>> getAllContributions({String? filterState}) async {
    if (!_isAdmin) throw Exception('Admin access required');

    Query query = _firestore.collection('contributions');
    
    if (filterState != null) {
      query = query.where('state', isEqualTo: filterState);
    }

    final snapshot = await query.limit(200).get();
    
    final contributions = snapshot.docs
        .map((doc) => Contribution.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return contributions;
  }

  /// Get flagged contributions for review (using 'archived' state or 'flagged' boolean)
  Future<List<Contribution>> getFlaggedContributions() async {
    if (!_isAdmin) throw Exception('Admin access required');

    // Try to get contributions that have been flagged
    // First check if there's a 'flagged' field, otherwise use 'archived' state
    final snapshot = await _firestore
        .collection('contributions')
        .where('flagged', isEqualTo: true)
        .get();

    // If no flagged field exists, try archived state
    if (snapshot.docs.isEmpty) {
      final archivedSnapshot = await _firestore
          .collection('contributions')
          .where('state', isEqualTo: 'archived')
          .get();
      
      final contributions = archivedSnapshot.docs
          .map((doc) => Contribution.fromMap(doc.data()))
          .toList();
      
      contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return contributions;
    }

    final contributions = snapshot.docs
        .map((doc) => Contribution.fromMap(doc.data()))
        .toList();

    contributions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return contributions;
  }

  /// Flag a contribution for review
  Future<void> flagContribution(String contributionId, String reason) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('contributions').doc(contributionId).update({
      'flagged': true,
      'flagReason': reason,
      'flaggedBy': _userId,
      'flaggedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAction(
      action: AdminAction.flagContribution,
      targetId: contributionId,
      targetType: AuditTargetType.contribution,
      details: reason,
    );
  }

  /// Unflag a contribution (restore to published)
  Future<void> unflagContribution(String contributionId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('contributions').doc(contributionId).update({
      'flagged': false,
      'state': 'published',
      'flagReason': FieldValue.delete(),
      'flaggedBy': FieldValue.delete(),
      'flaggedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAction(
      action: AdminAction.unflagContribution,
      targetId: contributionId,
      targetType: AuditTargetType.contribution,
    );
  }

  /// Hard delete a contribution (admin only)
  Future<void> removeContribution(String contributionId) async {
    if (!_isAdmin) throw Exception('Admin access required');

    await _firestore.collection('contributions').doc(contributionId).delete();

    await _logAction(
      action: AdminAction.removeContribution,
      targetId: contributionId,
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
