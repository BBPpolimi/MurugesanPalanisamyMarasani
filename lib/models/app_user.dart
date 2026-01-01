class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isGuest;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.isGuest,
  });

  bool get canRecordTrip => !isGuest;
  bool get canContribute => !isGuest;
}
