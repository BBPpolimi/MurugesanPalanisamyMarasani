/// User roles for access control
enum UserRole {
  user,
  admin;

  String get label {
    switch (this) {
      case UserRole.user:
        return 'User';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isGuest;
  final UserRole role;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.isGuest,
    this.role = UserRole.user,
  });

  bool get canRecordTrip => !isGuest;
  bool get canContribute => !isGuest;
  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isGuest,
    UserRole? role,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
    );
  }
}
