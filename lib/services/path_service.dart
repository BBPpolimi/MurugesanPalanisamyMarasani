import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/path.dart';

/// Service for managing canonical Path entities.
/// Handles path normalization and resolution.
class PathService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Normalize a list of GPS points and resolve to a canonical path_id.
  /// Creates a new Path if no match exists, returns existing path_id if found.
  Future<String> resolvePathIdFromGeometry(
    List<LatLng> points,
    String? city,
  ) async {
    if (points.isEmpty) {
      throw Exception('Cannot resolve path_id from empty points');
    }

    // 1. Normalize the geometry
    final normalizedPolyline = _normalizeGeometry(points);

    // 2. Generate canonical path_id
    final pathId = _generatePathId(normalizedPolyline, city);

    // 3. Check if path already exists
    final existingPath = await getPath(pathId);
    if (existingPath != null) {
      return pathId;
    }

    // 4. Create new Path
    final now = DateTime.now();
    final newPath = Path(
      id: pathId,
      normalizedPolyline: normalizedPolyline,
      city: city,
      originPoint: points.first,
      destinationPoint: points.last,
      distanceMeters: _calculateDistance(points),
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('paths').doc(pathId).set(newPath.toMap());
    return pathId;
  }

  /// Get a path by its canonical ID
  Future<Path?> getPath(String pathId) async {
    final doc = await _firestore.collection('paths').doc(pathId).get();
    if (doc.exists && doc.data() != null) {
      return Path.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get all paths (for community browse, paginated)
  Future<List<Path>> getAllPaths({int limit = 100}) async {
    final snapshot = await _firestore.collection('paths').limit(limit).get();
    return snapshot.docs.map((doc) => Path.fromMap(doc.data())).toList();
  }

  /// Normalize geometry:
  /// 1. Round coordinates to 5 decimal places (~1m precision)
  /// 2. Simplify using Douglas-Peucker (tolerance ~10m)
  /// 3. Direction normalization: always store with smaller lat first
  String _normalizeGeometry(List<LatLng> points) {
    // Round coordinates
    var normalized = points.map((p) => LatLng(
          _roundTo5Decimals(p.latitude),
          _roundTo5Decimals(p.longitude),
        )).toList();

    // Simplify (Douglas-Peucker with ~10m tolerance)
    normalized = _simplifyPolyline(normalized, 0.0001); // ~10m in degrees

    // Direction normalization: if first point is "greater" than last, reverse
    if (normalized.length >= 2) {
      final first = normalized.first;
      final last = normalized.last;
      if (first.latitude > last.latitude ||
          (first.latitude == last.latitude && first.longitude > last.longitude)) {
        normalized = normalized.reversed.toList();
      }
    }

    // Encode as string (simple format: "lat1,lng1;lat2,lng2;...")
    return normalized
        .map((p) => '${p.latitude},${p.longitude}')
        .join(';');
  }

  double _roundTo5Decimals(double value) {
    return (value * 100000).round() / 100000;
  }

  /// Generate canonical path_id = SHA256(normalized_polyline + city)
  String _generatePathId(String normalizedPolyline, String? city) {
    final input = '$normalizedPolyline|${city ?? 'unknown'}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars
  }

  /// Douglas-Peucker polyline simplification
  List<LatLng> _simplifyPolyline(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;

    // Find the point with maximum distance from line segment
    double maxDist = 0;
    int index = 0;
    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDist > tolerance) {
      final left = _simplifyPolyline(points.sublist(0, index + 1), tolerance);
      final right = _simplifyPolyline(points.sublist(index), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      // Line is a point
      return _distanceBetween(point, lineStart);
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final closestPoint = LatLng(
      lineStart.latitude + t * dy,
      lineStart.longitude + t * dx,
    );

    return _distanceBetween(point, closestPoint);
  }

  double _distanceBetween(LatLng a, LatLng b) {
    final dx = a.longitude - b.longitude;
    final dy = a.latitude - b.latitude;
    return (dx * dx + dy * dy); // Squared distance is fine for comparison
  }

  double _calculateDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      // Haversine formula simplified
      total += _haversineDistance(points[i - 1], points[i]);
    }
    return total;
  }

  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final aVal = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(a.latitude)) *
            _cos(_toRadians(b.latitude)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(aVal), _sqrt(1 - aVal));
    return R * c;
  }

  double _toRadians(double deg) => deg * 3.141592653589793 / 180.0;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) {
    // Simple atan2 approximation
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (y > 0) return 1.5707963267948966;
    if (y < 0) return -1.5707963267948966;
    return 0;
  }
  double _atan(double x) {
    // Simple Taylor series approximation for small x
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    }
    return x - x * x * x / 3 + x * x * x * x * x / 5;
  }
  double _taylorSin(double x) {
    // Normalize to [-π, π]
    while (x > 3.141592653589793) x -= 6.283185307179586;
    while (x < -3.141592653589793) x += 6.283185307179586;
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }
  double _newtonSqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
