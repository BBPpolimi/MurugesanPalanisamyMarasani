import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking blocked users
class BlockedUser {
  final String userId;
  final String blockedBy;
  final DateTime blockedAt;
  final String reason;
  final String? email;
  final String? displayName;

  BlockedUser({
    required this.userId,
    required this.blockedBy,
    required this.blockedAt,
    required this.reason,
    this.email,
    this.displayName,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'blockedBy': blockedBy,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'reason': reason,
      'email': email,
      'displayName': displayName,
    };
  }

  factory BlockedUser.fromMap(Map<String, dynamic> map) {
    return BlockedUser(
      userId: map['userId'] as String,
      blockedBy: map['blockedBy'] as String,
      blockedAt: (map['blockedAt'] as Timestamp).toDate(),
      reason: map['reason'] as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
    );
  }

  BlockedUser copyWith({
    String? userId,
    String? blockedBy,
    DateTime? blockedAt,
    String? reason,
    String? email,
    String? displayName,
  }) {
    return BlockedUser(
      userId: userId ?? this.userId,
      blockedBy: blockedBy ?? this.blockedBy,
      blockedAt: blockedAt ?? this.blockedAt,
      reason: reason ?? this.reason,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
