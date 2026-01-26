import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _googleApiKey = 'AIzaSyB0JGW9K_M69OPlEkUb4bjImj3ogpjJxNM'; // Using the new working API Key
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  final Dio _dio;

  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'bicycling',
  }) async {
    // 1. Try Google Directions API
    try {
      print('DEBUG: Requesting Directions from $origin to $destination mode=$mode');
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': _googleApiKey,
          'mode': mode, 
        },
      );
      
      print('DEBUG: Directions Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data);
        // Check for API-level errors even with 200 OK
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            final overviewPolyline = route['overview_polyline']['points'];
            final legs = route['legs'][0];
            final distance = legs['distance']['text'];
            final duration = legs['duration']['text'];

            return Directions(
              bounds: _boundsFrom(
                route['bounds']['northeast'],
                route['bounds']['southwest'],
              ),
              polylinePoints: _decodePolyline(overviewPolyline),
              totalDistance: distance,
              totalDuration: duration,
              distanceValue: (legs['distance']['value'] as num).toInt(),
            );
        } else {
           print('DEBUG: Google API Error or Empty: ${data['status']} - ${data['error_message']}');
           // Intentionally fall through to OSRM
        }
      } else {
        print('DEBUG: Non-200 Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Directions Exception: $e');
      // Continue to OSRM fallback
    }
    
    // 2. OSRM Fallback (Free, no key required for demo)
    try {
      print('DEBUG: Attempting OSRM Fallback...');
      // Use HTTPS for Android compliance. Use 'driving' profile as it's most reliable on public demo.
      final osrmUrl = 'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final response = await _dio.get(osrmUrl, queryParameters: {'overview': 'full'});
      
      print('DEBUG: OSRM Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
           final geometry = routes[0]['geometry'] as String;
           final distance = routes[0]['distance']; // meters (num)
           final duration = routes[0]['duration']; // seconds
           
           return Directions(
             bounds: LatLngBounds(southwest: origin, northeast: destination), // Approx
             polylinePoints: _decodePolyline(geometry), // OSRM uses same encoding
             totalDistance: '${(distance/1000).toStringAsFixed(1)} km',
             totalDuration: '${(duration/60).toStringAsFixed(0)} mins',
             distanceValue: (distance as num).toInt(),
           );
        }
      }
    } catch (e) {
      print('DEBUG: OSRM Exception: $e');
    }

    return null;
  }
  
  LatLngBounds _boundsFrom(Map<String, dynamic> northeast, Map<String, dynamic> southwest) {
      return LatLngBounds(
        northeast: LatLng(northeast['lat'], northeast['lng']),
        southwest: LatLng(southwest['lat'], southwest['lng']),
      );
  }

  // Initializing PolylinePoints in recent versions is tricky, so we decode manually.
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

class Directions {
  final LatLngBounds bounds;
  final List<LatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;
  final int distanceValue; // in meters

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    this.distanceValue = 0,
  });
}
