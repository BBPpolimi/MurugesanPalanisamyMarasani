import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/providers.dart';
import '../models/candidate_issue.dart';
import '../models/obstacle.dart';

class ReviewIssuesPage extends ConsumerStatefulWidget {
  const ReviewIssuesPage({super.key});

  @override
  ConsumerState<ReviewIssuesPage> createState() => _ReviewIssuesPageState();
}

class _ReviewIssuesPageState extends ConsumerState<ReviewIssuesPage> {
  // Local state to track handled candidates
  final Map<String, CandidateIssue> _handledCandidates = {};
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tripService = ref.read(tripServiceProvider);
    final points = tripService.points;
    
    // Get pending candidates (not yet handled)
    final allCandidates = tripService.candidates;
    final pendingCandidates = allCandidates
        .where((c) => !_handledCandidates.containsKey(c.id))
        .toList();

    // Convert points to polyline
    final polylineCoordinates = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (pendingCandidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Issues')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('All issues reviewed!', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                '${_handledCandidates.values.where((c) => c.status == CandidateStatus.confirmed).length} confirmed, '
                '${_handledCandidates.values.where((c) => c.status == CandidateStatus.rejected).length} rejected',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.done_all),
                label: const Text('Complete Review'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final candidate = pendingCandidates[_currentIndex.clamp(0, pendingCandidates.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Issues (${_currentIndex + 1}/${pendingCandidates.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: pendingCandidates.length > 1 
                ? () => setState(() => _currentIndex = (_currentIndex + 1) % pendingCandidates.length)
                : null,
            tooltip: 'Skip to next',
          ),
        ],
      ),
      body: Column(
        children: [
          // Full-screen map showing route and current obstacle
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(candidate.lat, candidate.lng),
                zoom: 17,
              ),
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: Colors.blueAccent,
                  width: 4,
                  points: polylineCoordinates,
                ),
              },
              markers: {
                // Current obstacle marker (larger, centered)
                Marker(
                  markerId: MarkerId(candidate.id),
                  position: LatLng(candidate.lat, candidate.lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: InfoWindow(
                    title: 'Potential Issue',
                    snippet: 'Confidence: ${(candidate.confidenceScore * 100).toInt()}%',
                  ),
                ),
                // Other pending obstacles as smaller markers
                ...pendingCandidates
                    .where((c) => c.id != candidate.id)
                    .map((c) => Marker(
                          markerId: MarkerId(c.id),
                          position: LatLng(c.lat, c.lng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                          alpha: 0.6,
                        )),
              },
              zoomControlsEnabled: true,
              myLocationEnabled: false,
            ),
          ),
          
          // Details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with timestamp
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Potential Road Issue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            'Detected at ${candidate.timestamp.toString().split('.')[0]}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(candidate.confidenceScore),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(candidate.confidenceScore * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Sensor data summary
                Text(
                  'Sensor: Accel ${_formatSensorData(candidate.sensorSnapshot)} | Gyro ${_formatSensorData(candidate.gyroSnapshot)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectCandidate(candidate),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Not an Issue'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmIssue(candidate),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatSensorData(List<double> data) {
    if (data.isEmpty) return 'N/A';
    return data.map((v) => v.toStringAsFixed(1)).join(', ');
  }

  void _rejectCandidate(CandidateIssue candidate) {
    final rejected = candidate.copyWith(status: CandidateStatus.rejected);
    setState(() {
      _handledCandidates[candidate.id] = rejected;
      _currentIndex = 0; // Reset to first pending
    });
    
    // Persist to Firestore
    final tripService = ref.read(tripServiceProvider);
    if (tripService.currentTripId != null) {
      tripService.updateCandidateStatus(tripService.lastSavedTrip?.id ?? '', rejected);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Issue rejected'), backgroundColor: Colors.orange),
    );
  }

  void _confirmIssue(CandidateIssue candidate) {
    showDialog(
      context: context,
      builder: (context) => _ConfirmObstacleDialog(
        candidate: candidate,
        onConfirm: (obstacle, updatedCandidate) async {
          // Update candidate with confirmed status
          setState(() {
            _handledCandidates[candidate.id] = updatedCandidate;
            _currentIndex = 0;
          });
          
          // Save obstacle to community
          final user = ref.read(authStateProvider).value;
          if (user == null) return;
          
          await ref.read(contributeServiceProvider).addObstacle(obstacle);
          
          // Persist candidate update
          final tripService = ref.read(tripServiceProvider);
          if (tripService.lastSavedTrip != null) {
            await tripService.updateCandidateStatus(tripService.lastSavedTrip!.id, updatedCandidate);
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Issue confirmed and saved!'), backgroundColor: Colors.green),
            );
          }
        },
      ),
    );
  }
}

class _ConfirmObstacleDialog extends StatefulWidget {
  final CandidateIssue candidate;
  final Function(Obstacle, CandidateIssue) onConfirm;

  const _ConfirmObstacleDialog({required this.candidate, required this.onConfirm});

  @override
  State<_ConfirmObstacleDialog> createState() => _ConfirmObstacleDialogState();
}

class _ConfirmObstacleDialogState extends State<_ConfirmObstacleDialog> {
  ObstacleType _type = ObstacleType.pothole;
  ObstacleSeverity _severity = ObstacleSeverity.medium;
  bool _publishable = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Issue'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What kind of obstacle is this?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<ObstacleType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: ObstacleType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.label));
              }).toList(),
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ObstacleSeverity>(
              value: _severity,
              decoration: const InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(),
              ),
              items: ObstacleSeverity.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(s.label));
              }).toList(),
              onChanged: (val) => setState(() => _severity = val!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Publish to Community'),
              subtitle: const Text('Others can see this report'),
              value: _publishable,
              onChanged: (val) => setState(() => _publishable = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () {
                  final user = ref.read(authStateProvider).value;
                  if (user == null) return;

                  final obstacle = Obstacle(
                    id: const Uuid().v4(),
                    userId: user.uid,
                    lat: widget.candidate.lat,
                    lng: widget.candidate.lng,
                    obstacleType: _type,
                    severity: _severity,
                    publishable: _publishable,
                    createdAt: DateTime.now(),
                  );

                  final updatedCandidate = widget.candidate.copyWith(
                    status: CandidateStatus.confirmed,
                    obstacleType: _type,
                    severity: _severity,
                  );

                  widget.onConfirm(obstacle, updatedCandidate);
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              );
            }
        ),
      ],
    );
  }
}
