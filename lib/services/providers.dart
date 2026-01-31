import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/path_group.dart';
import 'admin_service.dart';
import 'auth_service.dart';
import 'biking_detector_service.dart';
import 'contribute_service.dart';
import 'directions_service.dart';
import 'geocoding_service.dart';
import 'merge_scheduler.dart';
import 'route_scoring_service.dart';
import 'stats_service.dart';
import 'trip_repository.dart';
import 'trip_service.dart';
import 'weather_service.dart';
import 'path_group_service.dart';
import 'route_search_service.dart';
import 'path_service.dart';
import 'contribution_service.dart' as contribution;
import 'merge_service.dart';



import '../models/trip.dart';
import '../models/bike_path.dart';
import '../models/contribution.dart';

export 'contribute_service.dart';
export 'directions_service.dart';
export 'geocoding_service.dart';
export 'route_scoring_service.dart';
export 'trip_repository.dart';
export 'trip_service.dart';
export 'admin_service.dart';
export 'path_group_service.dart';
export 'route_search_service.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = TripRepository();

  // Use synchronous data access to ensure immediate initialization
  final user = authState.asData?.value;
  if (user != null) {
    repository.initialize(user.uid);
  }

  return repository;
});

final tripServiceProvider = ChangeNotifierProvider<TripService>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  final service = TripService(repository: repository);

  // Use synchronous data access to ensure immediate initialization
  final user = authState.asData?.value;
  if (user != null) {
    service.initialize(user.uid);
  }

  return service;
});

final tripsStreamProvider = StreamProvider<List<dynamic>>((ref) async* {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final contributionService = ref.watch(contributionServiceProvider);
  final authState = ref.watch(authStateProvider);

  if (authState.asData?.value == null) {
    yield [];
    return;
  }

  // Watch Trips Stream
  final tripsStream = tripRepository.watchTrips();

  // Fetch Contributions (both manual and automatic) and combine with trips
  await for (final trips in tripsStream) {
    // Get all user contributions
    final contributions = await contributionService.getMyContributions();

    // Combine trips and contributions, avoiding duplicates
    // (contributions with tripId are already linked to trips)
    final tripIds = trips.map((t) => t.id).toSet();
    final contributionTripIds = contributions
        .where((c) => c.tripId != null)
        .map((c) => c.tripId!)
        .toSet();

    final combined = <dynamic>[
      ...trips, // All trips
      // Only add contributions that are NOT linked to a trip (manual contributions)
      ...contributions.where((c) => c.tripId == null),
    ];

    // Sort by date descending
    combined.sort((a, b) {
      DateTime timeA;
      if (a is Trip) {
        timeA = a.startTime;
      } else if (a is Contribution) {
        timeA = a.createdAt;
      } else {
        timeA = DateTime.fromMillisecondsSinceEpoch(0);
      }

      DateTime timeB;
      if (b is Trip) {
        timeB = b.startTime;
      } else if (b is Contribution) {
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

// Provider for user with role (async fetch - re-fetches when auth state changes)
final userWithRoleProvider = FutureProvider<AppUser?>((ref) async {
  // Watch auth state to trigger re-fetch on login/logout
  final authState = ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  
  // Wait for auth state to resolve, then fetch full user with role
  return authState.maybeWhen(
    data: (user) async {
      if (user == null) return null;
      // Fetch fresh user with role from Firestore
      return await authService.getCurrentUserWithRole();
    },
    orElse: () => null,
  ) ?? Future.value(null);
});

final directionsServiceProvider =
    Provider<DirectionsService>((ref) => DirectionsService());

final contributeServiceProvider = Provider<ContributeService>((ref) {
  final authState = ref.watch(authStateProvider);
  final service = ContributeService();

  // Use synchronous data access to ensure immediate initialization
  final user = authState.asData?.value;
  if (user != null) {
    service.initialize(user.uid);
  }

  return service;
});

final adminServiceProvider = Provider<AdminService>((ref) {
  final authState = ref.watch(userWithRoleProvider);
  final service = AdminService();

  // Use synchronous data access to ensure immediate initialization
  final user = authState.asData?.value;
  if (user != null) {
    service.initialize(user.uid, user.isAdmin, email: user.email);
  }

  return service;
});

final mergeSchedulerProvider = Provider<MergeScheduler>((ref) => MergeScheduler());

final statsServiceProvider = Provider<StatsService>((ref) => StatsService());

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final authState = ref.watch(userWithRoleProvider);
  return authState.maybeWhen(
    data: (user) async {
      if (user == null || user.isGuest) return UserStats.empty();
      return ref.read(statsServiceProvider).getStats(user.uid);
    },
    orElse: () async => UserStats.empty(),
  );
});

final geocodingServiceProvider =
    Provider<GeocodingService>((ref) => GeocodingService());

final bikingDetectorServiceProvider =
    ChangeNotifierProvider<BikingDetectorService>((ref) {
  return BikingDetectorService();
});

final weatherServiceProvider =
    Provider<WeatherService>((ref) => WeatherService());

// --- New RDD-compliant services ---

final pathServiceProvider = Provider<PathService>((ref) => PathService());

final mergeServiceProvider = Provider<MergeService>((ref) => MergeService());

final contributionServiceProvider = Provider<contribution.ContributionService>((ref) {
  final authState = ref.watch(authStateProvider);
  final service = contribution.ContributionService();

  // Use synchronous data access to ensure immediate initialization
  final user = authState.asData?.value;
  if (user != null) {
    service.initialize(user.uid);
  }

  return service;
});

final routeScoringServiceProvider = Provider<RouteScoringService>((ref) {
  final contributeService = ref.watch(contributeServiceProvider);
  return RouteScoringService(contributeService: contributeService);
});

final myBikePathsFutureProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(contributeServiceProvider);
  final paths = await service.getMyBikePaths();
  return paths;
});

final myDraftPathsProvider = FutureProvider<List<BikePath>>((ref) async {
  final service = ref.watch(contributeServiceProvider);
  return await service.getMyDraftPaths();
});

final myPublishedPathsProvider = FutureProvider<List<BikePath>>((ref) async {
  final service = ref.watch(contributeServiceProvider);
  return await service.getMyPublishedPaths();
});

final publicBikePathsProvider = FutureProvider<List<BikePath>>((ref) async {
  final service = ref.watch(contributeServiceProvider);
  return await service.getPublicBikePaths();
});

// ============ NEW Contribution-Based Providers ============
// These use the new unified Contribution model for both manual and automatic paths

/// Provider for user's draft contributions (both manual and automatic)
final myDraftContributionsProvider = FutureProvider<List<Contribution>>((ref) async {
  final service = ref.watch(contributionServiceProvider);
  return await service.getMyDraftContributions();
});

/// Provider for user's published contributions
final myPublishedContributionsProvider = FutureProvider<List<Contribution>>((ref) async {
  final service = ref.watch(contributionServiceProvider);
  return await service.getMyPublishedContributions();
});

/// Provider for all public contributions (community view)
final publicContributionsProvider = FutureProvider<List<Contribution>>((ref) async {
  final service = ref.watch(contributionServiceProvider);
  return await service.getPublicContributions();
});

/// Provider for all user's contributions (drafts + published)
final myContributionsProvider = FutureProvider<List<Contribution>>((ref) async {
  final service = ref.watch(contributionServiceProvider);
  return await service.getMyContributions();
});

// ============ Path Groups (Merged View) ============


final pathGroupServiceProvider = Provider<PathGroupService>((ref) {
  return PathGroupService();
});

final pathGroupsProvider = FutureProvider<List<PathGroup>>((ref) async {
  final service = ref.watch(pathGroupServiceProvider);
  return await service.getPathGroups();
});

final pathGroupsByCity = FutureProvider.family<List<PathGroup>, String>((ref, city) async {
  final service = ref.watch(pathGroupServiceProvider);
  return await service.getPathGroups(city: city);
});

// ============ Route Search ============

final routeSearchServiceProvider = Provider<RouteSearchService>((ref) {
  return RouteSearchService();
});

/// Provider for route search results
/// Usage: ref.read(routeSearchProvider({'originLat': x, 'originLng': y, 'destLat': z, 'destLng': w}))
final routeSearchProvider = FutureProvider.family<RouteSearchResult, Map<String, double>>((ref, params) async {
  final service = ref.watch(routeSearchServiceProvider);
  return await service.searchRoutes(
    originLat: params['originLat']!,
    originLng: params['originLng']!,
    destLat: params['destLat']!,
    destLng: params['destLng']!,
  );
});

