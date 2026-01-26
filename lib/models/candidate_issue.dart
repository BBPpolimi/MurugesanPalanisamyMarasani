import 'package:cloud_firestore/cloud_firestore.dart';
import 'obstacle.dart';

enum CandidateStatus { pending, confirmed, rejected }

class CandidateIssue {
  final String id;
  final String tripId; // Link to parent trip
  final String userId;
  final double lat;
  final double lng;
  final List<double> sensorSnapshot; // Accelerometer magnitudes
  final List<double> gyroSnapshot; // Gyroscope magnitudes
  final double confidenceScore;
  final DateTime timestamp;
  final CandidateStatus status;
  final ObstacleType? obstacleType; // User-editable type
  final ObstacleSeverity? severity; // User-editable severity

  CandidateIssue({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.sensorSnapshot,
    this.gyroSnapshot = const [],
    required this.confidenceScore,
    required this.timestamp,
    this.status = CandidateStatus.pending,
    this.obstacleType,
    this.severity,
  });

  CandidateIssue copyWith({
    String? id,
    String? tripId,
    String? userId,
    double? lat,
    double? lng,
    List<double>? sensorSnapshot,
    List<double>? gyroSnapshot,
    double? confidenceScore,
    DateTime? timestamp,
    CandidateStatus? status,
    ObstacleType? obstacleType,
    ObstacleSeverity? severity,
  }) {
    return CandidateIssue(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sensorSnapshot: sensorSnapshot ?? this.sensorSnapshot,
      gyroSnapshot: gyroSnapshot ?? this.gyroSnapshot,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      obstacleType: obstacleType ?? this.obstacleType,
      severity: severity ?? this.severity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'sensorSnapshot': sensorSnapshot,
      'gyroSnapshot': gyroSnapshot,
      'confidenceScore': confidenceScore,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      if (obstacleType != null) 'obstacleType': obstacleType!.name,
      if (severity != null) 'severity': severity!.name,
    };
  }

  factory CandidateIssue.fromMap(Map<String, dynamic> map) {
    return CandidateIssue(
      id: map['id'] ?? '',
      tripId: map['tripId'] ?? '',
      userId: map['userId'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      sensorSnapshot: List<double>.from(map['sensorSnapshot'] ?? []),
      gyroSnapshot: List<double>.from(map['gyroSnapshot'] ?? []),
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: CandidateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CandidateStatus.pending,
      ),
      obstacleType: map['obstacleType'] != null
          ? ObstacleType.values.firstWhere(
              (e) => e.name == map['obstacleType'],
              orElse: () => ObstacleType.other,
            )
          : null,
      severity: map['severity'] != null
          ? ObstacleSeverity.values.firstWhere(
              (e) => e.name == map['severity'],
              orElse: () => ObstacleSeverity.medium,
            )
          : null,
    );
  }
}
