import 'package:cloud_firestore/cloud_firestore.dart';
import 'street_segment.dart';
import 'path_quality_report.dart'; // For PathRateStatus reuse

class BikePath {
  final String id;
  final String userId;
  final List<StreetSegment> segments;
  final PathRateStatus status;
  final bool publishable;
  final String? name; // Added name field
  final double distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  BikePath({
    required this.id,
    required this.userId,
    required this.segments,
    required this.status,
    required this.publishable,
    this.name,
    this.distanceMeters = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'segments': segments.map((s) => s.toMap()).toList(),
      'status': status.name,
      'publishable': publishable,
      'name': name,
      'distanceMeters': distanceMeters,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory BikePath.fromMap(Map<String, dynamic> map) {
    return BikePath(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      segments: (map['segments'] as List?)
              ?.map((s) => StreetSegment.fromMap(s))
              .toList() ??
          [],
      status: PathRateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PathRateStatus.medium,
      ),
      publishable: map['publishable'] ?? false,
      name: map['name'],
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
