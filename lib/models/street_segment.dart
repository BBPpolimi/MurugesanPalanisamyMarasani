import 'package:google_maps_flutter/google_maps_flutter.dart';

class StreetSegment {
  final String id; // Unique reference (Place ID or composite hash)
  final String streetName;
  final String formattedAddress;
  final double lat;
  final double lng;
  final List<LatLng>? polyline; // Optional geometry

  StreetSegment({
    required this.id,
    required this.streetName,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.polyline,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'streetName': streetName,
      'formattedAddress': formattedAddress,
      'lat': lat,
      'lng': lng,
      'polyline': polyline
          ?.map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

  factory StreetSegment.fromMap(Map<String, dynamic> map) {
    return StreetSegment(
      id: map['id'] ?? '',
      streetName: map['streetName'] ?? '',
      formattedAddress: map['formattedAddress'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      polyline: (map['polyline'] as List?)
          ?.map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
    );
  }
}
