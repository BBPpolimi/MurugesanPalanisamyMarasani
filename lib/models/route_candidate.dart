import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteCandidate {
  final String id;
  final List<LatLng> polylinePoints;
  final LatLngBounds bounds;
  final String totalDistance;
  final String totalDuration;
  final int distanceValue; // meters
  final String encodedPolyline;

  const RouteCandidate({
    required this.id,
    required this.polylinePoints,
    required this.bounds,
    required this.totalDistance,
    required this.totalDuration,
    required this.distanceValue,
    required this.encodedPolyline,
  });
}
