import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'biking_detector_service.dart';
import 'contribute_service.dart';
import 'directions_service.dart';
import 'geocoding_service.dart';
import 'trip_repository.dart';
import 'trip_service.dart';
import 'weather_service.dart';

import '../models/trip.dart';
import '../models/bike_path.dart';

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

final tripsStreamProvider = StreamProvider<List<dynamic>>((ref) async* {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final contributeService = ref.watch(contributeServiceProvider);
  final authState = ref.watch(authStateProvider);
  
  if (authState.asData?.value == null) {
    yield [];
    return;
  }

  // Watch Trips Stream
  final tripsStream = tripRepository.watchTrips();
  
  // Fetch Bike Paths (Manual) - Currently a Future, so we fetch once per stream build
  // Ideally this should be a stream too, but for now we mix it in.
  // We yield whenever trips update, re-fetching bike paths to ensure data is relatively fresh.
  
  await for (final trips in tripsStream) {
     final bikePaths = await contributeService.getMyBikePaths();
     
     final combined = <dynamic>[...trips, ...bikePaths];
     // Sort by date descending
     combined.sort((a, b) {
        DateTime timeA;
        if (a is Trip) {
           timeA = a.startTime;
        } else if (a is BikePath) {
           timeA = a.createdAt;
        } else {
           timeA = DateTime.fromMillisecondsSinceEpoch(0);
        }

        DateTime timeB;
        if (b is Trip) {
           timeB = b.startTime;
        } else if (b is BikePath) {
           timeB = b.createdAt;
        } else {
           timeB = DateTime.fromMillisecondsSinceEpoch(0);
        }
            
        return timeB.compareTo(timeA);
     });
     
     yield combined;
  }
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

final bikingDetectorServiceProvider = ChangeNotifierProvider<BikingDetectorService>((ref) {
  return BikingDetectorService();
});

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());

final myBikePathsFutureProvider = FutureProvider<List<dynamic>>((ref) async { // dynamic to avoid circular import if BikePath not exported here, but imports are usually fine or propagated. Actually BikePath might need import.
  // Actually, providers.dart exports contribute_service, which imports BikePath. So BikePath is available transitively? 
  // No, I need to import BikePath in providers OR just use dynamic temporarily. 
  // Better to use strongly typed if possible.
  final service = ref.watch(contributeServiceProvider);
  final paths = await service.getMyBikePaths();
  return paths;
});
