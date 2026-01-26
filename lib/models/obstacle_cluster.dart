import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_obstacle.dart';

/// Represents a cluster of similar obstacles from multiple contributions
/// Obstacles are clustered spatially to avoid duplicates in the merged view
class ObstacleCluster {
  final String id;
  final PathObstacleType type;
  final double lat;
  final double lng;
  final String geohash;
  final double severityAvg;
  final int confirmations;
  final DateTime lastSeenAt;
  final bool decayed;
  final String? note;

  ObstacleCluster({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    required this.geohash,
    required this.severityAvg,
    this.confirmations = 1,
    DateTime? lastSeenAt,
    this.decayed = false,
    this.note,
  }) : lastSeenAt = lastSeenAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'lat': lat,
      'lng': lng,
      'geohash': geohash,
      'severityAvg': severityAvg,
      'confirmations': confirmations,
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'decayed': decayed,
      'note': note,
    };
  }

  factory ObstacleCluster.fromMap(Map<String, dynamic> map) {
    return ObstacleCluster(
      id: map['id'] ?? '',
      type: PathObstacleType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PathObstacleType.other,
      ),
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      geohash: map['geohash'] ?? '',
      severityAvg: (map['severityAvg'] ?? 1).toDouble(),
      confirmations: map['confirmations'] ?? 1,
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      decayed: map['decayed'] ?? false,
      note: map['note'],
    );
  }

  ObstacleCluster copyWith({
    String? id,
    PathObstacleType? type,
    double? lat,
    double? lng,
    String? geohash,
    double? severityAvg,
    int? confirmations,
    DateTime? lastSeenAt,
    bool? decayed,
    String? note,
  }) {
    return ObstacleCluster(
      id: id ?? this.id,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      geohash: geohash ?? this.geohash,
      severityAvg: severityAvg ?? this.severityAvg,
      confirmations: confirmations ?? this.confirmations,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      decayed: decayed ?? this.decayed,
      note: note ?? this.note,
    );
  }

  /// Get severity as integer (1-5)
  int get severityInt => severityAvg.round().clamp(1, 5);

  /// Get severity label
  String get severityLabel {
    switch (severityInt) {
      case 1:
        return 'Minor';
      case 2:
        return 'Low';
      case 3:
        return 'Moderate';
      case 4:
        return 'High';
      case 5:
        return 'Severe';
      default:
        return 'Unknown';
    }
  }

  /// Get formatted description
  String get description {
    final typeLabel = type.label;
    return '$severityLabel $typeLabel${confirmations > 1 ? ' (${confirmations}x confirmed)' : ''}';
  }

  /// Check if this cluster is still fresh (within decay window)
  bool isFresh({int decayDays = 30}) {
    final daysSinceLastSeen = DateTime.now().difference(lastSeenAt).inDays;
    return daysSinceLastSeen <= decayDays;
  }

  /// Convert to PathObstacle for compatibility
  PathObstacle toPathObstacle() {
    return PathObstacle(
      id: id,
      type: type,
      severity: severityInt,
      lat: lat,
      lng: lng,
      note: note,
      createdAt: lastSeenAt,
    );
  }
}

/// Utility class for obstacle clustering operations
class ObstacleClusterUtils {
  /// Cluster radius in meters
  static const double clusterRadiusMeters = 50;

  /// Geohash precision for clustering (7 = ~76m x 76m cells)
  static const int geohashPrecision = 7;

  /// Calculate distance between two points in meters (Haversine formula)
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
        _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => _sinTable(x);
  static double _cos(double x) => _sinTable(x + 1.5707963267948966);
  static double _sqrt(double x) => x <= 0 ? 0 : _sqrtNewton(x);
  static double _atan2(double y, double x) => _atan2Impl(y, x);

  // Simplified implementations for distance calculation
  static double _sinTable(double x) {
    // Normalize to [-π, π]
    while (x > 3.141592653589793) x -= 6.283185307179586;
    while (x < -3.141592653589793) x += 6.283185307179586;
    // Taylor series approximation
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  static double _sqrtNewton(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2Impl(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atan(double x) {
    // Taylor series approximation for small x
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    }
    final x2 = x * x;
    return x * (1 - x2 / 3 + x2 * x2 / 5 - x2 * x2 * x2 / 7);
  }

  /// Simple geohash encoder
  static String encodeGeohash(double lat, double lng, {int precision = 7}) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    final buffer = StringBuffer();
    bool isLng = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isLng) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          ch |= (1 << (4 - bit));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLng = !isLng;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return buffer.toString();
  }
}
