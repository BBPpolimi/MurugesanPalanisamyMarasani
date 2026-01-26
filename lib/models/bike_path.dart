import 'package:cloud_firestore/cloud_firestore.dart';
import 'street_segment.dart';
import 'path_quality_report.dart'; // For PathRateStatus reuse
import 'path_obstacle.dart';
import 'path_tag.dart';

/// Visibility states for a bike path contribution
enum PathVisibility {
  private,   // Only owner can see
  published, // Visible to community
  flagged,   // Admin flagged for review
}

class BikePath {
  final String id;
  final String userId;
  final String? name;
  final List<StreetSegment> segments;
  final PathRateStatus status;
  final PathVisibility visibility;
  final List<PathObstacle> obstacles;
  final List<PathTag> tags;
  final String? city;
  final String? normalizedKey; // Hash for future merging
  final int version;
  final bool deleted; // Soft delete
  final double distanceMeters;
  final String? mapPreviewPolyline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  BikePath({
    required this.id,
    required this.userId,
    this.name,
    required this.segments,
    required this.status,
    this.visibility = PathVisibility.private,
    this.obstacles = const [],
    this.tags = const [],
    this.city,
    this.normalizedKey,
    this.version = 1,
    this.deleted = false,
    this.distanceMeters = 0.0,
    this.mapPreviewPolyline,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
  });

  /// Legacy getter for backwards compatibility
  bool get publishable => visibility == PathVisibility.published;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'segments': segments.map((s) => s.toMap()).toList(),
      'status': status.name,
      'visibility': visibility.name,
      'obstacles': obstacles.map((o) => o.toMap()).toList(),
      'tags': tags.map((t) => t.name).toList(),
      'city': city,
      'normalizedKey': normalizedKey,
      'version': version,
      'deleted': deleted,
      'distanceMeters': distanceMeters,
      'mapPreviewPolyline': mapPreviewPolyline,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      // Legacy field for backwards compatibility
      'publishable': visibility == PathVisibility.published,
    };
  }

  factory BikePath.fromMap(Map<String, dynamic> map) {
    // Handle legacy 'publishable' field
    PathVisibility visibility;
    if (map['visibility'] != null) {
      visibility = PathVisibility.values.firstWhere(
        (e) => e.name == map['visibility'],
        orElse: () => PathVisibility.private,
      );
    } else {
      // Legacy: convert boolean publishable to visibility
      visibility = (map['publishable'] == true) 
          ? PathVisibility.published 
          : PathVisibility.private;
    }

    return BikePath(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'],
      segments: (map['segments'] as List?)
              ?.map((s) => StreetSegment.fromMap(s))
              .toList() ??
          [],
      status: PathRateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PathRateStatus.medium,
      ),
      visibility: visibility,
      obstacles: (map['obstacles'] as List?)
              ?.map((o) => PathObstacle.fromMap(o))
              .toList() ??
          [],
      tags: (map['tags'] as List?)
              ?.map((t) => PathTag.values.firstWhere(
                    (e) => e.name == t,
                    orElse: () => PathTag.bikeLanePresent,
                  ))
              .toList() ??
          [],
      city: map['city'],
      normalizedKey: map['normalizedKey'],
      version: (map['version'] as num?)?.toInt() ?? 1,
      deleted: map['deleted'] ?? false,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      mapPreviewPolyline: map['mapPreviewPolyline'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  BikePath copyWith({
    String? id,
    String? userId,
    String? name,
    List<StreetSegment>? segments,
    PathRateStatus? status,
    PathVisibility? visibility,
    List<PathObstacle>? obstacles,
    List<PathTag>? tags,
    String? city,
    String? normalizedKey,
    int? version,
    bool? deleted,
    double? distanceMeters,
    String? mapPreviewPolyline,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
  }) {
    return BikePath(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      segments: segments ?? this.segments,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      obstacles: obstacles ?? this.obstacles,
      tags: tags ?? this.tags,
      city: city ?? this.city,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      mapPreviewPolyline: mapPreviewPolyline ?? this.mapPreviewPolyline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
