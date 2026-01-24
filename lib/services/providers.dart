import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_service.dart';
import 'trip_repository.dart';
import 'auth_service.dart';
import 'directions_service.dart';
import '../models/app_user.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = TripRepository();
  
  // Initialize with user ID if authenticated
  authState.whenData((user) {
    if (user != null) {
      repository.initialize(user.uid);
    }
  });
  
  return repository;
});

final tripServiceProvider = ChangeNotifierProvider<TripService>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  final service = TripService(repository: repository);
  
  // Initialize service with user ID if authenticated (though mostly delegated to repo)
  authState.whenData((user) {
    if (user != null) {
      service.initialize(user.uid);
    }
  });
  
  return service;
});

final tripsStreamProvider = StreamProvider<List<dynamic>>((ref) { // Using dynamic temporarily to resolve import issues if any, but it returns List<Trip>
  final repository = ref.watch(tripRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  // Only watch trips if user is logged in
  if (authState.asData?.value != null) {
    return repository.watchTrips();
  }
  return Stream.value([]);
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final directionsServiceProvider = Provider<DirectionsService>((ref) => DirectionsService());
