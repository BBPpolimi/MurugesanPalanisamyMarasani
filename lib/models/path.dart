import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Canonical community path entity.
/// Represents the "thing" the community browses, independent of who contributed.
class Path {
  /// Canonical stable identifier (hash of normalized geometry + city)
  final String id;

  /// Simplified, direction-normalized route polyline
  final String normalizedPolyline;

  /// City where the path is located
  final String? city;

  /// Starting point of the path
  final LatLng? originPoint;

  /// Ending point of the path
  final LatLng? destinationPoint;

  /// Total distance in meters
  final double distanceMeters;

  final DateTime createdAt;
  final DateTime updatedAt;

  Path({
    required this.id,
    required this.normalizedPolyline,
    this.city,
    this.originPoint,
    this.destinationPoint,
    this.distanceMeters = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'normalizedPolyline': normalizedPolyline,
      'city': city,
      'originPoint': originPoint != null
          ? {'lat': originPoint!.latitude, 'lng': originPoint!.longitude}
          : null,
      'destinationPoint': destinationPoint != null
          ? {
              'lat': destinationPoint!.latitude,
              'lng': destinationPoint!.longitude
            }
          : null,
      'distanceMeters': distanceMeters,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Path.fromMap(Map<String, dynamic> map) {
    return Path(
      id: map['id'] ?? '',
      normalizedPolyline: map['normalizedPolyline'] ?? '',
      city: map['city'],
      originPoint: map['originPoint'] != null
          ? LatLng(
              (map['originPoint']['lat'] as num).toDouble(),
              (map['originPoint']['lng'] as num).toDouble(),
            )
          : null,
      destinationPoint: map['destinationPoint'] != null
          ? LatLng(
              (map['destinationPoint']['lat'] as num).toDouble(),
              (map['destinationPoint']['lng'] as num).toDouble(),
            )
          : null,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Path copyWith({
    String? id,
    String? normalizedPolyline,
    String? city,
    LatLng? originPoint,
    LatLng? destinationPoint,
    double? distanceMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Path(
      id: id ?? this.id,
      normalizedPolyline: normalizedPolyline ?? this.normalizedPolyline,
      city: city ?? this.city,
      originPoint: originPoint ?? this.originPoint,
      destinationPoint: destinationPoint ?? this.destinationPoint,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
