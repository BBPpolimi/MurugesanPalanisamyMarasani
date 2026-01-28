import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

/// Data class holding user statistics
class UserStats {
  final int tripsThisWeek;
  final int tripsThisMonth;
  final int tripsAllTime;
  final double distanceWeekKm;
  final double distanceMonthKm;
  final double distanceAllTimeKm;
  final Duration rideTimeWeek;
  final Duration rideTimeMonth;
  final Duration rideTimeAllTime;
  final double avgSpeedWeek;
  final double avgSpeedMonth;
  final Trip? longestRide;
  final Trip? fastestRide;
  final int streakDays;

  const UserStats({
    this.tripsThisWeek = 0,
    this.tripsThisMonth = 0,
    this.tripsAllTime = 0,
    this.distanceWeekKm = 0.0,
    this.distanceMonthKm = 0.0,
    this.distanceAllTimeKm = 0.0,
    this.rideTimeWeek = Duration.zero,
    this.rideTimeMonth = Duration.zero,
    this.rideTimeAllTime = Duration.zero,
    this.avgSpeedWeek = 0.0,
    this.avgSpeedMonth = 0.0,
    this.longestRide,
    this.fastestRide,
    this.streakDays = 0,
  });

  factory UserStats.empty() => const UserStats();
}

/// Service for computing user ride statistics
class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Compute stats from user's trips
  Future<UserStats> getStats(String userId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // Fetch all user trips
    final snapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      return UserStats.empty();
    }

    final trips = snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList();

    // Calculate metrics
    int tripsThisWeek = 0, tripsThisMonth = 0;
    double distanceWeek = 0, distanceMonth = 0, distanceTotal = 0;
    int timeWeekSecs = 0, timeMonthSecs = 0, timeTotalSecs = 0;

    Trip? longestRide;
    Trip? fastestRide;
    double maxDistance = 0;
    double maxSpeed = 0;

    for (final trip in trips) {
      final distance = trip.distanceMeters / 1000; // km
      final duration = trip.endTime.difference(trip.startTime).inSeconds;
      final speed = duration > 0 ? (distance / (duration / 3600)) : 0.0;

      // All-time
      distanceTotal += distance;
      timeTotalSecs += duration;

      // This week
      if (trip.startTime.isAfter(weekStart)) {
        tripsThisWeek++;
        distanceWeek += distance;
        timeWeekSecs += duration;
      }

      // This month
      if (trip.startTime.isAfter(monthStart)) {
        tripsThisMonth++;
        distanceMonth += distance;
        timeMonthSecs += duration;
      }

      // Longest ride
      if (distance > maxDistance) {
        maxDistance = distance;
        longestRide = trip;
      }

      // Fastest ride
      if (speed > maxSpeed && duration > 60) {
        // Min 1 minute
        maxSpeed = speed;
        fastestRide = trip;
      }
    }

    // Calculate average speeds
    final avgSpeedWeek =
        timeWeekSecs > 0 ? (distanceWeek / (timeWeekSecs / 3600)) : 0.0;
    final avgSpeedMonth =
        timeMonthSecs > 0 ? (distanceMonth / (timeMonthSecs / 3600)) : 0.0;

    // Calculate streak
    final streakDays = _calculateStreak(trips);

    return UserStats(
      tripsThisWeek: tripsThisWeek,
      tripsThisMonth: tripsThisMonth,
      tripsAllTime: trips.length,
      distanceWeekKm: distanceWeek,
      distanceMonthKm: distanceMonth,
      distanceAllTimeKm: distanceTotal,
      rideTimeWeek: Duration(seconds: timeWeekSecs),
      rideTimeMonth: Duration(seconds: timeMonthSecs),
      rideTimeAllTime: Duration(seconds: timeTotalSecs),
      avgSpeedWeek: avgSpeedWeek,
      avgSpeedMonth: avgSpeedMonth,
      longestRide: longestRide,
      fastestRide: fastestRide,
      streakDays: streakDays,
    );
  }

  int _calculateStreak(List<Trip> trips) {
    if (trips.isEmpty) return 0;

    // Sort by date descending
    trips.sort((a, b) => b.startTime.compareTo(a.startTime));

    int streak = 0;
    DateTime? lastDate;

    for (final trip in trips) {
      final tripDate = DateTime(
        trip.startTime.year,
        trip.startTime.month,
        trip.startTime.day,
      );

      if (lastDate == null) {
        // First trip - check if it's today or yesterday
        final today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        if (tripDate == today ||
            tripDate == today.subtract(const Duration(days: 1))) {
          streak = 1;
          lastDate = tripDate;
        } else {
          break; // Streak broken
        }
      } else {
        final diff = lastDate.difference(tripDate).inDays;
        if (diff == 1) {
          streak++;
          lastDate = tripDate;
        } else if (diff > 1) {
          break; // Streak broken
        }
        // diff == 0 means same day, continue checking
      }
    }

    return streak;
  }
}
