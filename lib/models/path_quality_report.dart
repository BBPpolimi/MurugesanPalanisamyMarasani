import 'package:cloud_firestore/cloud_firestore.dart';

enum PathRateStatus {
  optimal,
  medium,
  sufficient,
  requiresMaintenance;

  String get label {
    switch (this) {
      case PathRateStatus.optimal:
        return 'Optimal';
      case PathRateStatus.medium:
        return 'Medium';
      case PathRateStatus.sufficient:
        return 'Sufficient';
      case PathRateStatus.requiresMaintenance:
        return 'Requires Maintenance';
    }
  }
}

class PathQualityReport {
  final String id;
  final String userId;
  final double lat;
  final double lng;
  final String? routeContext; // Optional: routeId or polyline hash
  final PathRateStatus status;
  final bool publishable;
  final DateTime createdAt;

  PathQualityReport({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    this.routeContext,
    required this.status,
    required this.publishable,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'routeContext': routeContext,
      'status': status.name,
      'publishable': publishable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PathQualityReport.fromMap(Map<String, dynamic> map) {
    return PathQualityReport(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      routeContext: map['routeContext'],
      status: PathRateStatus.values.firstWhere((e) => e.name == map['status'],
          orElse: () => PathRateStatus.medium),
      publishable: map['publishable'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
