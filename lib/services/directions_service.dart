import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/route_candidate.dart';

class DirectionsService {
  static const String _googleApiKey =
      'AIzaSyB0JGW9K_M69OPlEkUb4bjImj3ogpjJxNM'; // Using the new working API Key
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  final Dio _dio;
  final _uuid = const Uuid();

  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetches multiple route candidates between origin and destination.
  /// Returns an empty list if no routes found or error occurs.
  Future<List<RouteCandidate>> getAlternativeDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'bicycling',
  }) async {
    List<RouteCandidate> candidates = [];

    // 1. Try Google Directions API
    try {
      print(
          'DEBUG: Requesting Directions from $origin to $destination mode=$mode alternatives=true');
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': _googleApiKey,
          'mode': mode,
          'alternatives': 'true',
        },
      );

      print('DEBUG: Directions Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final routes = data['routes'] as List;

          for (var route in routes) {
            final overviewPolyline = route['overview_polyline']['points'];
            final legs = route['legs'][0];
            final distance = legs['distance']['text'];
            final duration = legs['duration']['text'];

            final candidate = RouteCandidate(
              id: _uuid.v4(),
              bounds: _boundsFrom(
                route['bounds']['northeast'],
                route['bounds']['southwest'],
              ),
              polylinePoints: _decodePolyline(overviewPolyline),
              encodedPolyline: overviewPolyline,
              totalDistance: distance,
              totalDuration: duration,
              distanceValue: (legs['distance']['value'] as num).toInt(),
            );
            candidates.add(candidate);
          }
          return candidates; // Return immediately if Google API succeeds
        } else {
          print(
              'DEBUG: Google API Error or Empty: ${data['status']} - ${data['error_message']}');
        }
      }
    } catch (e) {
      print('DEBUG: Directions Exception: $e');
    }

    // 2. OSRM Fallback - OSRM alternatives support is limited in public demo, but we can try.
    if (candidates.isEmpty) {
      try {
        print('DEBUG: Attempting OSRM Fallback...');
        // OSRM 'alternatives=true' query param
        final osrmUrl =
            'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
        final response = await _dio.get(osrmUrl,
            queryParameters: {'overview': 'full', 'alternatives': 'true'});

        if (response.statusCode == 200) {
          final routes = response.data['routes'] as List;
          for (var route in routes) {
            final geometry = route['geometry'] as String;
            final distance = route['distance']; // meters (num)
            final duration = route['duration']; // seconds

            final candidate = RouteCandidate(
              id: _uuid.v4(),
              bounds: LatLngBounds(
                  southwest: origin, northeast: destination), // Approx for OSRM
              polylinePoints: _decodePolyline(geometry),
              encodedPolyline: geometry,
              totalDistance: '${(distance / 1000).toStringAsFixed(1)} km',
              totalDuration: '${(duration / 60).toStringAsFixed(0)} mins',
              distanceValue: (distance as num).toInt(),
            );
            candidates.add(candidate);
          }
        }
      } catch (e) {
        print('DEBUG: OSRM Exception: $e');
      }
    }

    return candidates;
  }

  // Kept for backward compatibility if needed, but updated to use RouteCandidate logic internally if possible or just simplified.
  // Actually, the previous `getDirections` returned `Directions?`.
  // We can keep a simplified version or alias it to the first candidate.
  Future<RouteCandidate?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'bicycling',
  }) async {
    final candidates = await getAlternativeDirections(
        origin: origin, destination: destination, mode: mode);
    if (candidates.isNotEmpty) return candidates.first;
    return null;
  }

  LatLngBounds _boundsFrom(
      Map<String, dynamic> northeast, Map<String, dynamic> southwest) {
    return LatLngBounds(
      northeast: LatLng(northeast['lat'], northeast['lng']),
      southwest: LatLng(southwest['lat'], southwest['lng']),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}

// Deprecated Directions class removed in favor of RouteCandidate
