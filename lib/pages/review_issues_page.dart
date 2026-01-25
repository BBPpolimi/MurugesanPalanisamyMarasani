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
  // Local state to track which candidates have been handled in this session
  final Set<String> _handledIds = {};

  @override
  Widget build(BuildContext context) {
    final tripService = ref.read(tripServiceProvider);
    // Filter out handled ones
    final candidates = tripService.candidates
        .where((c) => !_handledIds.contains(c.id))
        .toList();

    if (candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Issues')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('All issues reviewed!'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Review Issues (${candidates.length})')),
      body: ListView.builder(
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(candidate.lat, candidate.lng),
                      zoom: 16,
                    ),
                    zoomControlsEnabled: false,
                    markers: {
                      Marker(
                        markerId: MarkerId(candidate.id),
                        position: LatLng(candidate.lat, candidate.lng),
                      )
                    },
                  ),
                ),
                ListTile(
                  title: Text('Potential Anomaly at ${candidate.timestamp.toString().split('.')[0]}'),
                  subtitle: Text('Confidence: ${(candidate.confidenceScore * 100).toInt()}%'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _handledIds.add(candidate.id);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () {
                          _confirmIssue(candidate);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmIssue(CandidateIssue candidate) {
    showDialog(
      context: context,
      builder: (context) => _ConfirmObstacleDialog(
        candidate: candidate,
        onConfirm: (obstacle) async {
          // Verify user exists
          final user = ref.read(authStateProvider).value;
          if (user == null) return;
          
          await ref.read(contributeServiceProvider).addObstacle(obstacle);
          
          if (mounted) {
            setState(() {
              _handledIds.add(candidate.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue confirmed and published!')));
          }
        },
      ),
    );
  }
}

class _ConfirmObstacleDialog extends StatefulWidget {
  final CandidateIssue candidate;
  final Function(Obstacle) onConfirm;

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
              decoration: const InputDecoration(labelText: 'Type'),
              items: ObstacleType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.label));
              }).toList(),
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ObstacleSeverity>(
              value: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: ObstacleSeverity.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(s.label));
              }).toList(),
              onChanged: (val) => setState(() => _severity = val!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Public Report'),
              subtitle: const Text('Allow others to see this report'),
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
                  if (user == null) {
                     // should handle better
                     return;
                  }

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

                  widget.onConfirm(obstacle);
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
