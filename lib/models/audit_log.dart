import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin action types for audit logging
enum AdminAction {
  blockUser,
  unblockUser,
  flagContribution,
  unflagContribution,
  removeContribution,
  setUserRole;

  String get label {
    switch (this) {
      case AdminAction.blockUser:
        return 'Block User';
      case AdminAction.unblockUser:
        return 'Unblock User';
      case AdminAction.flagContribution:
        return 'Flag Contribution';
      case AdminAction.unflagContribution:
        return 'Unflag Contribution';
      case AdminAction.removeContribution:
        return 'Remove Contribution';
      case AdminAction.setUserRole:
        return 'Set User Role';
    }
  }

  String get icon {
    switch (this) {
      case AdminAction.blockUser:
        return '🚫';
      case AdminAction.unblockUser:
        return '✅';
      case AdminAction.flagContribution:
        return '🚩';
      case AdminAction.unflagContribution:
        return '✓';
      case AdminAction.removeContribution:
        return '🗑️';
      case AdminAction.setUserRole:
        return '👤';
    }
  }
}

/// Target type for audit log entries
enum AuditTargetType {
  user,
  contribution;
}

/// Model for audit log entries
class AuditLog {
  final String id;
  final String adminId;
  final String? adminEmail;
  final AdminAction action;
  final String targetId;
  final AuditTargetType targetType;
  final String? details;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.adminId,
    this.adminEmail,
    required this.action,
    required this.targetId,
    required this.targetType,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adminId': adminId,
      'adminEmail': adminEmail,
      'action': action.name,
      'targetId': targetId,
      'targetType': targetType.name,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      adminId: map['adminId'] as String,
      adminEmail: map['adminEmail'] as String?,
      action: AdminAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => AdminAction.removeContribution,
      ),
      targetId: map['targetId'] as String,
      targetType: AuditTargetType.values.firstWhere(
        (e) => e.name == map['targetType'],
        orElse: () => AuditTargetType.contribution,
      ),
      details: map['details'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
