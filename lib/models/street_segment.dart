import 'package:google_maps_flutter/google_maps_flutter.dart';

class StreetSegment {
  final String id; // Unique reference (Place ID or composite hash)
  final String streetName;
  final String formattedAddress;
  final double lat;
  final double lng;
  final int order; // Position in path (0-indexed)
  final String? placeId; // Google Places ID for normalization
  final List<LatLng>? polyline; // Optional geometry

  StreetSegment({
    required this.id,
    required this.streetName,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.order = 0,
    this.placeId,
    this.polyline,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'streetName': streetName,
      'formattedAddress': formattedAddress,
      'lat': lat,
      'lng': lng,
      'order': order,
      'placeId': placeId,
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
      order: (map['order'] as num?)?.toInt() ?? 0,
      placeId: map['placeId'],
      polyline: (map['polyline'] as List?)
          ?.map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
    );
  }

  StreetSegment copyWith({
    String? id,
    String? streetName,
    String? formattedAddress,
    double? lat,
    double? lng,
    int? order,
    String? placeId,
    List<LatLng>? polyline,
  }) {
    return StreetSegment(
      id: id ?? this.id,
      streetName: streetName ?? this.streetName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      order: order ?? this.order,
      placeId: placeId ?? this.placeId,
      polyline: polyline ?? this.polyline,
    );
  }
}
