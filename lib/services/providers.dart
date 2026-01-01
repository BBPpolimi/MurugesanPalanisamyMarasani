import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_service.dart';
import 'auth_service.dart';
import '../models/app_user.dart';

final tripServiceProvider =
    ChangeNotifierProvider<TripService>((ref) => TripService());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
