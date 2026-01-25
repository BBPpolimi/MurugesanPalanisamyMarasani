import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'contribute_service.dart';
import 'directions_service.dart';
import 'geocoding_service.dart';
import 'trip_repository.dart';
import 'trip_service.dart';

export 'contribute_service.dart';
export 'directions_service.dart';
export 'geocoding_service.dart';
export 'trip_repository.dart';
export 'trip_service.dart';

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

final contributeServiceProvider = Provider<ContributeService>((ref) {
  final authState = ref.watch(authStateProvider);
  final service = ContributeService();
  
  // Initialize with user ID if authenticated
  authState.whenData((user) {
    if (user != null) {
      service.initialize(user.uid);
    }
  });
  
  return service;
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) => GeocodingService());

final myBikePathsFutureProvider = FutureProvider<List<dynamic>>((ref) async { // dynamic to avoid circular import if BikePath not exported here, but imports are usually fine or propagated. Actually BikePath might need import.
  // Actually, providers.dart exports contribute_service, which imports BikePath. So BikePath is available transitively? 
  // No, I need to import BikePath in providers OR just use dynamic temporarily. 
  // Better to use strongly typed if possible.
  final service = ref.watch(contributeServiceProvider);
  final paths = await service.getMyBikePaths();
  return paths;
});
