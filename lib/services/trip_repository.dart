import '../models/trip.dart';

class TripRepository {
  final List<Trip> _trips = [];

  List<Trip> getAllTrips() {
    return List.unmodifiable(_trips);
  }

  void saveTrip(Trip trip) {
    _trips.add(trip);
  }

  void clear() {
    _trips.clear();
  }
}
