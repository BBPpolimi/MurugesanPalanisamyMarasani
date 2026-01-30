import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_quality_report.dart'; // For PathRateStatus
import 'path_obstacle.dart';
import 'path_tag.dart';

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
/// This replaces the old BikePath model.
class Contribution {
  final String id;
  final String userId;

  /// FK to canonical Path entity
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
    required this.capturedAt,
    this.confirmedAt,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Check if contribution can be published
  bool get canPublish {
    if (state == ContributionState.published) return false;
    if (source == ContributionSource.automatic && confirmedAt == null) {
      return false; // Automatic must be confirmed first
    }
    return state == ContributionState.privateSaved;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'pathId': pathId,
      'tripId': tripId,
      'name': name,
      'source': source.name,
      'state': state.name,
      'statusRating': statusRating.name,
      'obstacles': obstacles.map((o) => o.toMap()).toList(),
      'tags': tags.map((t) => t.name).toList(),
      'capturedAt': Timestamp.fromDate(capturedAt),
      'confirmedAt':
          confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'publishedAt':
          publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
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
        (e) => e.name == map['source'],
        orElse: () => ContributionSource.manual,
      ),
      state: ContributionState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => ContributionState.draft,
      ),
      statusRating: PathRateStatus.values.firstWhere(
        (e) => e.name == map['statusRating'],
        orElse: () => PathRateStatus.medium,
      ),
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
      capturedAt:
          (map['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      capturedAt: capturedAt ?? this.capturedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
