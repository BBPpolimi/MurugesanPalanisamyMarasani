import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/providers.dart';
import '../services/trip_service.dart';
import '../models/trip_state.dart';
import '../models/path_quality_report.dart';
import '../models/candidate_issue.dart';
import '../models/obstacle.dart';

class RecordTripPage extends ConsumerStatefulWidget {
  const RecordTripPage({super.key});

  @override
  ConsumerState<RecordTripPage> createState() => _RecordTripPageState();
}

class _RecordTripPageState extends ConsumerState<RecordTripPage> {
  GoogleMapController? _mapController;
  bool _shouldFollowUser = true;
  
  // Review mode state
  final TextEditingController _nameController = TextEditingController();
  bool _isPublic = false;
  PathRateStatus _pathRating = PathRateStatus.medium;
  Set<String> _dismissedObstacles = {};
  Map<String, CandidateIssue> _editedObstacles = {}; // Track edited type/severity
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripService = ref.watch(tripServiceProvider);
    final state = tripService.state;
    final points = tripService.points;
    final candidates = tripService.candidates;

    // Convert points to LatLng for Polyline
    final polylineCoordinates =
        points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Auto-follow logic - only when NOT in review mode
    if (state != TripState.reviewing && 
        _shouldFollowUser && points.isNotEmpty && _mapController != null) {
      final lastPoint = points.last;
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(lastPoint.latitude, lastPoint.longitude)),
      );
    }
    
    // Nullify controller when entering review to prevent disposed controller access
    if (state == TripState.reviewing) {
      _mapController = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Record Trip')),
      body: Column(
        children: [
          /// STATUS CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildStatusCard(context, tripService),
          ),

          // Auto-detection Toggle (visible when idle or autoMonitoring)
          if (state == TripState.idle || state == TripState.autoMonitoring)
            SwitchListTile(
              title: const Text('Auto-detect Biking'),
              subtitle: Text(state == TripState.autoMonitoring
                  ? 'Monitoring speed... (${(tripService.currentSpeed * 3.6).toStringAsFixed(1)} km/h)'
                  : 'Auto-starts recording when biking detected'),
              value: tripService.isAutoDetectionEnabled,
              onChanged: (val) => tripService.toggleAutoDetection(val),
              activeColor: Colors.green,
            ),

          // Monitoring status indicator
          if (state == TripState.autoMonitoring)
            Container(
              color: Colors.blue.shade100,
              padding: const EdgeInsets.all(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Waiting for biking to start...'),
                ],
              ),
            ),

          // Recording indicator with Auto badge
          if (state == TripState.recording && tripService.isAutoDetectedTrip)
            Container(
              color: Colors.green.shade100,
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Auto-detected ride in progress'),
                ],
              ),
            ),

          if (state == TripState.recording)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('${candidates.length} potential issues detected'),
                ],
              ),
            ),

          // REVIEW MODE: Show review UI instead of map
          if (state == TripState.reviewing)
            Expanded(child: _buildReviewUI(tripService))
          // NORMAL MODE: Show map
          else
          /// MAP AREA (replaces the list)
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(45.4782, 9.2272), // Default
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      color: Colors.blueAccent,
                      width: 5,
                      points: polylineCoordinates,
                    ),
                  },
                  markers: candidates
                      .map((c) => Marker(
                            markerId: MarkerId(c.id),
                            position: LatLng(c.lat, c.lng),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueOrange),
                            infoWindow:
                                const InfoWindow(title: 'Potential Issue'),
                          ))
                      .toSet(),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMoveStarted: () {
                    // Optionally disable auto follow
                  },
                ),
                Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor:
                          _shouldFollowUser ? Colors.blue : Colors.white,
                      child: Icon(Icons.navigation,
                          color:
                              _shouldFollowUser ? Colors.white : Colors.black),
                      onPressed: () {
                        setState(() {
                          _shouldFollowUser = !_shouldFollowUser;
                        });
                      },
                    )),

                // Metrics Overlay
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230), // approx 0.9 * 255
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Points: ${points.length}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'Accuracy: ${tripService.currentAccuracy?.toStringAsFixed(1) ?? "--"} m'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ACTION BUTTONS CONTAINER
          // Hide bottom controls when in review mode (review UI has its own buttons)
          if (state != TripState.reviewing)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((state == TripState.idle ||
                        state == TripState.error ||
                        state == TripState.autoMonitoring) &&
                    !tripService.isAutoDetectionEnabled)
                  _buildStartButton(ref, context, tripService),
                if (state == TripState.recording ||
                    state == TripState.paused) ...[
                  Row(
                    children: [
                      Expanded(child: _buildPauseResumeButton(ref, state)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStopButton(ref, context)),
                    ],
                  ),
                ],
                if (state == TripState.saved)
                  // Just show Start New Trip - issues already reviewed in review form
                  ElevatedButton(
                    onPressed: () => ref
                        .read(tripServiceProvider)
                        .clear(), // Reset to idle
                    child: const Text('Start New Trip'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, TripService tripService) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (tripService.state) {
      case TripState.idle:
        icon = Icons.directions_bike;
        color = Colors.green;
        title = 'Ready to start';
        subtitle = 'Press start when you begin cycling';
        break;
      case TripState.autoMonitoring:
        icon = Icons.radar;
        color = Colors.blue;
        title = 'Auto-detection Active';
        subtitle = 'Will start recording when biking is detected';
        break;
      case TripState.recording:
        icon = Icons.fiber_manual_record;
        color = Colors.red;
        title = tripService.isAutoDetectedTrip
            ? 'Recording (Auto)'
            : 'Recording...';
        subtitle = 'GPS is tracking your ride';
        break;
      case TripState.paused:
        icon = Icons.pause_circle;
        color = Colors.orange;
        title = 'Trip Paused';
        subtitle = 'Tracking suspended';
        break;
      case TripState.processing:
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        title = 'Processing...';
        subtitle = 'Saving your trip';
        break;
      case TripState.saved:
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'Trip Saved!';
        subtitle = tripService.lastSummary != null
            ? '${(tripService.lastSummary!.distanceMeters / 1000).toStringAsFixed(2)} km in ${tripService.lastSummary!.duration.inMinutes} min'
            : 'Ride stats saved';
        break;
      case TripState.error:
        icon = Icons.error;
        color = Colors.red;
        title = 'Error';
        subtitle = tripService.errorMessage ?? 'Unknown error';
        break;
      case TripState.reviewing:
        icon = Icons.rate_review;
        color = Colors.purple;
        title = 'Review Your Trip';
        subtitle = 'Confirm and save your ride';
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(
      WidgetRef ref, BuildContext context, TripService tripService) {
    return ElevatedButton.icon(
      icon: tripService.isInitializing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.play_arrow),
      label: Text(tripService.isInitializing ? 'Starting...' : 'Start Trip'),
      onPressed: tripService.isInitializing
          ? null
          : () async {
              await ref.read(tripServiceProvider).startRecording();
            },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPauseResumeButton(WidgetRef ref, TripState state) {
    bool isPaused = state == TripState.paused;
    return ElevatedButton.icon(
      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
      label: Text(isPaused ? 'Resume' : 'Pause'),
      onPressed: () {
        if (isPaused) {
          ref.read(tripServiceProvider).resumeRecording();
        } else {
          ref.read(tripServiceProvider).pauseRecording();
        }
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
      ),
    );
  }

  Widget _buildStopButton(WidgetRef ref, BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.stop),
      label: const Text('Stop & Review'),
      onPressed: () async {
        // Enter review mode instead of immediately saving
        await ref.read(tripServiceProvider).enterReviewMode();
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Build the post-trip review UI
  Widget _buildReviewUI(TripService tripService) {
    final reviewData = tripService.reviewData;
    if (reviewData == null) {
      return const Center(child: Text('No review data available'));
    }

    // Get points for map display
    final polylineCoordinates = reviewData.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Filter out dismissed obstacles
    final activeObstacles = reviewData.candidates
        .where((c) => !_dismissedObstacles.contains(c.id))
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Trip Recorded! Review and save:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Map Preview
          SizedBox(
            height: 200,
            child: GoogleMap(
              key: const ValueKey('review_map'), // Prevent recreation on setState
              initialCameraPosition: CameraPosition(
                target: polylineCoordinates.isNotEmpty
                    ? polylineCoordinates.first
                    : const LatLng(45.4642, 9.1900),
                zoom: 14,
              ),
              polylines: {
                if (polylineCoordinates.length >= 2)
                  Polyline(
                    polylineId: const PolylineId('trip_path'),
                    points: polylineCoordinates,
                    color: Colors.blue,
                    width: 4,
                  ),
              },
              markers: {
                // Start marker
                if (polylineCoordinates.isNotEmpty)
                  Marker(
                    markerId: const MarkerId('start'),
                    position: polylineCoordinates.first,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Start'),
                  ),
                // End marker
                if (polylineCoordinates.length > 1)
                  Marker(
                    markerId: const MarkerId('end'),
                    position: polylineCoordinates.last,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'End'),
                  ),
                // Obstacle markers
                ...activeObstacles.map((obstacle) => Marker(
                  markerId: MarkerId('obstacle_${obstacle.id}'),
                  position: LatLng(obstacle.lat, obstacle.lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(
                    title: obstacle.obstacleType?.name ?? 'Issue',
                    snippet: 'Severity: ${obstacle.severity?.name ?? "Unknown"}',
                  ),
                )),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true, // Use lite mode to prevent controller issues
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.straighten, 
                    '${(reviewData.distanceMeters / 1000).toStringAsFixed(2)} km', 'Distance'),
                _buildStatItem(Icons.timer, 
                    _formatDuration(reviewData.duration), 'Duration'),
                _buildStatItem(Icons.speed, 
                    '${(reviewData.averageSpeed * 3.6).toStringAsFixed(1)} km/h', 'Avg Speed'),
              ],
            ),
          ),

          const Divider(),

          // Name Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name (Optional)',
                hintText: 'e.g., Morning Commute',
                prefixIcon: Icon(Icons.edit),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Path Rating
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Path Quality Rating:', 
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PathRateStatus.values.map((status) {
                    final isSelected = _pathRating == status;
                    return ChoiceChip(
                      label: Text(status.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _pathRating = status);
                      },
                      selectedColor: _getStatusColor(status).withOpacity(0.3),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Public Toggle
          SwitchListTile(
            title: const Text('Make Public'),
            subtitle: const Text('Share this path with the community'),
            value: _isPublic,
            onChanged: (val) => setState(() => _isPublic = val),
            secondary: Icon(
              _isPublic ? Icons.public : Icons.lock,
              color: _isPublic ? Colors.green : Colors.grey,
            ),
          ),

          // Obstacles Section
          if (reviewData.candidates.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Detected Issues (${activeObstacles.length} of ${reviewData.candidates.length})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            ...reviewData.candidates.map((originalObstacle) {
              // Use edited version if available, otherwise original
              final obstacle = _editedObstacles[originalObstacle.id] ?? originalObstacle;
              final isDismissed = _dismissedObstacles.contains(obstacle.id);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  leading: Icon(
                    isDismissed ? Icons.check_circle_outline : _getObstacleIcon(obstacle.obstacleType),
                    color: isDismissed ? Colors.grey : Colors.orange,
                  ),
                  title: Text(
                    obstacle.obstacleType?.label ?? 'Unknown Issue',
                    style: TextStyle(
                      decoration: isDismissed ? TextDecoration.lineThrough : null,
                      color: isDismissed ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    'Severity: ${obstacle.severity?.label ?? "Unknown"}',
                    style: TextStyle(color: isDismissed ? Colors.grey : null),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        if (isDismissed) {
                          _dismissedObstacles.remove(obstacle.id);
                        } else {
                          _dismissedObstacles.add(obstacle.id);
                        }
                      });
                    },
                    child: Text(isDismissed ? 'Restore' : 'Dismiss'),
                  ),
                  children: [
                    if (!isDismissed)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type Selector
                            const Text('Issue Type:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ObstacleType.values.map((type) {
                                final isSelected = obstacle.obstacleType == type;
                                return ChoiceChip(
                                  avatar: Icon(_getObstacleIcon(type), size: 18),
                                  label: Text(type.label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _editedObstacles[obstacle.id] = obstacle.copyWith(
                                          obstacleType: type,
                                        );
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            // Severity Selector
                            const Text('Severity:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: ObstacleSeverity.values.map((sev) {
                                final isSelected = obstacle.severity == sev;
                                return ChoiceChip(
                                  label: Text(sev.label),
                                  selected: isSelected,
                                  selectedColor: _getSeverityColor(sev).withOpacity(0.3),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _editedObstacles[obstacle.id] = obstacle.copyWith(
                                          severity: sev,
                                        );
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: Icon(_isPublic ? Icons.publish : Icons.save),
                  label: Text(_isPublic ? 'Save & Publish' : 'Save as Draft'),
                  onPressed: () => _saveTrip(tripService),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: _isPublic ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    // Confirm discard
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Discard Trip?'),
                        content: const Text('This will permanently delete the recorded trip.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(tripServiceProvider).cancelReview();
                              _resetReviewState();
                            },
                            child: const Text('Discard', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Discard Trip'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Color _getStatusColor(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return Colors.green;
      case PathRateStatus.medium:
        return Colors.blue;
      case PathRateStatus.sufficient:
        return Colors.orange;
      case PathRateStatus.requiresMaintenance:
        return Colors.red;
    }
  }

  Future<void> _saveTrip(TripService tripService) async {
    final name = _nameController.text.trim().isEmpty 
        ? null 
        : _nameController.text.trim();

    // Get confirmed obstacles (not dismissed)
    final reviewData = tripService.reviewData;
    final confirmedObstacles = reviewData?.candidates
        .where((c) => !_dismissedObstacles.contains(c.id))
        .toList();

    // Apply edits to confirmed obstacles
    final editedConfirmedObstacles = confirmedObstacles?.map((original) {
      return _editedObstacles[original.id] ?? original;
    }).toList();

    // Save the isPublic state before resetting
    final wasPublic = _isPublic;

    await tripService.saveReviewedTrip(
      name: name,
      isPublic: _isPublic,
      confirmedObstacles: editedConfirmedObstacles,
      statusRating: _pathRating,
    );

    _resetReviewState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasPublic 
              ? 'Trip saved and published!' 
              : 'Trip saved as draft!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  void _resetReviewState() {
    _nameController.clear();
    _isPublic = false;
    _pathRating = PathRateStatus.medium;
    _dismissedObstacles.clear();
    _editedObstacles.clear();
  }

  IconData _getObstacleIcon(ObstacleType? type) {
    switch (type) {
      case ObstacleType.pothole:
        return Icons.warning_rounded;
      case ObstacleType.construction:
        return Icons.construction;
      case ObstacleType.closure:
        return Icons.block;
      case ObstacleType.debris:
        return Icons.delete_sweep;
      case ObstacleType.other:
      default:
        return Icons.report_problem;
    }
  }

  Color _getSeverityColor(ObstacleSeverity severity) {
    switch (severity) {
      case ObstacleSeverity.low:
        return Colors.green;
      case ObstacleSeverity.medium:
        return Colors.orange;
      case ObstacleSeverity.high:
        return Colors.red;
    }
  }
}
