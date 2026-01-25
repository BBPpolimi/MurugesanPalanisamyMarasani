
import 'package:cloud_firestore/cloud_firestore.dart';

enum CandidateStatus {
  pending,
  confirmed,
  rejected
}

class CandidateIssue {
  final String id;
  final String userId;
  final double lat;
  final double lng;
  final List<double> sensorSnapshot; // Array of accelerometer magnitudes around the event
  final double confidenceScore;
  final DateTime timestamp;
  final CandidateStatus status;

  CandidateIssue({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.sensorSnapshot,
    required this.confidenceScore,
    required this.timestamp,
    this.status = CandidateStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'sensorSnapshot': sensorSnapshot,
      'confidenceScore': confidenceScore,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
    };
  }

  factory CandidateIssue.fromMap(Map<String, dynamic> map) {
    return CandidateIssue(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      sensorSnapshot: List<double>.from(map['sensorSnapshot'] ?? []),
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: CandidateStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CandidateStatus.pending,
      ),
    );
  }
}
