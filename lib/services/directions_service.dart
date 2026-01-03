import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _googleApiKey = 'AIzaSyB0JGW9K_M69OPlEkUb4bjImj3ogpjJxNM'; // Using the key found in other files
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  final Dio _dio;

  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': _googleApiKey,
          'mode': 'bicycling', 
        },
      );

      if (response.statusCode == 200) {
        if ((response.data['routes'] as List).isEmpty) return null;
        
        final data = Map<String, dynamic>.from(response.data);
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
        );
      }
    } catch (e) {
      // Handle error cleanly
      return null;
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

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
  });
}
