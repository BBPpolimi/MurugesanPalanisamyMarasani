import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_quality_report.dart'; // For PathRateStatus
import 'path_obstacle.dart';
import 'path_tag.dart';
import 'street_segment.dart';

/// Source of a contribution
enum ContributionSource {
  manual,    // User manually typed streets/status
  automatic, // Generated from GPS/sensors during biking
}

/// State machine for contribution lifecycle
enum ContributionState {
  draft,               // Manual: started, not saved yet
  pendingConfirmation, // Automatic: awaiting user confirm/correct
  privateSaved,        // Saved but not published
  published,           // Community-visible, eligible for merge
  archived,            // Soft-deleted
}

/// User's observation/contribution about a path.
/// This replaces the old BikePath model and unifies manual + automatic paths.
class Contribution {
  final String id;
  final String userId;

  /// FK to canonical Path entity (for merging)
  final String pathId;

  /// FK to Trip (non-null for automatic contributions)
  final String? tripId;

  /// Optional user-defined name
  final String? name;

  /// Whether created manually or from automatic recording
  final ContributionSource source;

  /// Current lifecycle state
  final ContributionState state;

  /// User's rating of path quality
  final PathRateStatus statusRating;

  /// Detected or manually added obstacles
  final List<PathObstacle> obstacles;

  /// Tags describing path features
  final List<PathTag> tags;

  // ============ Fields from BikePath ============

  /// Street segments (for manual paths)
  final List<StreetSegment> segments;

  /// Raw GPS polyline from trip recording (for automatic paths)
  final String? gpsPolyline;

  /// Road-snapped polyline for map display
  final String? mapPreviewPolyline;

  /// Total path distance in meters
  final double distanceMeters;

  /// City/area name
  final String? city;

  /// Soft delete flag
  final bool deleted;

  /// Computed path score (0-100)
  final double? pathScore;

  // ============ Timestamps ============

  /// When the observation was captured (trip end time or manual entry time)
  final DateTime capturedAt;

  /// When user confirmed/corrected (required for automatic before publish)
  final DateTime? confirmedAt;

  /// When made community-visible
  final DateTime? publishedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Version for optimistic locking
  final int version;

  Contribution({
    required this.id,
    required this.userId,
    required this.pathId,
    this.tripId,
    this.name,
    required this.source,
    required this.state,
    required this.statusRating,
    this.obstacles = const [],
    this.tags = const [],
    this.segments = const [],
    this.gpsPolyline,
    this.mapPreviewPolyline,
    this.distanceMeters = 0.0,
    this.city,
    this.deleted = false,
    this.pathScore,
    required this.capturedAt,
    this.confirmedAt,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Human-readable source label
  String get sourceLabel => switch (source) {
    ContributionSource.manual => 'Manual Path',
    ContributionSource.automatic => 'Auto-Recorded Trip',
  };

  /// Short source label for badges
  String get sourceShortLabel => switch (source) {
    ContributionSource.manual => 'Manual',
    ContributionSource.automatic => 'Auto',
  };

  /// Check if contribution can be published
  bool get canPublish {
    if (state == ContributionState.published) return false;
    if (source == ContributionSource.automatic && confirmedAt == null) {
      return false; // Automatic must be confirmed first
    }
    return state == ContributionState.privateSaved;
  }

  /// Check if this is a published contribution
  bool get isPublished => state == ContributionState.published;

  /// Check if this is a draft/private contribution
  bool get isDraft => state == ContributionState.draft || 
                      state == ContributionState.privateSaved ||
                      state == ContributionState.pendingConfirmation;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'pathId': pathId,
      'tripId': tripId,
      'name': name,
      'source': source.toString().split('.').last,
      'state': state.toString().split('.').last,
      'statusRating': statusRating.toString().split('.').last,
      'obstacles': obstacles.map((o) => o.toMap()).toList(),
      'tags': tags.map((t) => t.toString().split('.').last).toList(),
      'segments': segments.map((s) => s.toMap()).toList(),
      'gpsPolyline': gpsPolyline,
      'mapPreviewPolyline': mapPreviewPolyline,
      'distanceMeters': distanceMeters,
      'city': city,
      'deleted': deleted,
      'pathScore': pathScore,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'version': version,
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      pathId: map['pathId'] ?? '',
      tripId: map['tripId'],
      name: map['name'],
      source: ContributionSource.values.firstWhere(
        (e) => e.toString().split('.').last == map['source'],
        orElse: () => ContributionSource.manual,
      ),
      state: ContributionState.values.firstWhere(
        (e) => e.toString().split('.').last == map['state'],
        orElse: () => ContributionState.draft,
      ),
      statusRating: PathRateStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['statusRating'],
        orElse: () => PathRateStatus.medium,
      ),
      obstacles: (map['obstacles'] as List?)
              ?.map((o) => PathObstacle.fromMap(o))
              .toList() ??
          [],
      tags: (map['tags'] as List?)
              ?.map((t) => PathTag.values.firstWhere(
                    (e) => e.toString().split('.').last == t,
                    orElse: () => PathTag.bikeLanePresent,
                  ))
              .toList() ??
          [],
      segments: (map['segments'] as List?)
              ?.map((s) => StreetSegment.fromMap(s))
              .toList() ??
          [],
      gpsPolyline: map['gpsPolyline'],
      mapPreviewPolyline: map['mapPreviewPolyline'],
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      city: map['city'],
      deleted: map['deleted'] ?? false,
      pathScore: (map['pathScore'] as num?)?.toDouble(),
      capturedAt: (map['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }

  Contribution copyWith({
    String? id,
    String? userId,
    String? pathId,
    String? tripId,
    String? name,
    ContributionSource? source,
    ContributionState? state,
    PathRateStatus? statusRating,
    List<PathObstacle>? obstacles,
    List<PathTag>? tags,
    List<StreetSegment>? segments,
    String? gpsPolyline,
    String? mapPreviewPolyline,
    double? distanceMeters,
    String? city,
    bool? deleted,
    double? pathScore,
    DateTime? capturedAt,
    DateTime? confirmedAt,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Contribution(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pathId: pathId ?? this.pathId,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      source: source ?? this.source,
      state: state ?? this.state,
      statusRating: statusRating ?? this.statusRating,
      obstacles: obstacles ?? this.obstacles,
      tags: tags ?? this.tags,
      segments: segments ?? this.segments,
      gpsPolyline: gpsPolyline ?? this.gpsPolyline,
      mapPreviewPolyline: mapPreviewPolyline ?? this.mapPreviewPolyline,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      city: city ?? this.city,
      deleted: deleted ?? this.deleted,
      pathScore: pathScore ?? this.pathScore,
      capturedAt: capturedAt ?? this.capturedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

