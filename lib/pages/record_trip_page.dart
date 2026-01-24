import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/providers.dart';
import '../services/trip_service.dart';
import '../models/trip_state.dart';

class RecordTripPage extends ConsumerStatefulWidget {
  const RecordTripPage({super.key});

  @override
  ConsumerState<RecordTripPage> createState() => _RecordTripPageState();
}

class _RecordTripPageState extends ConsumerState<RecordTripPage> {
  GoogleMapController? _mapController;
  bool _shouldFollowUser = true;

  @override
  Widget build(BuildContext context) {
    final tripService = ref.watch(tripServiceProvider);
    final state = tripService.state;
    final points = tripService.points;

    // Convert points to LatLng for Polyline
    final polylineCoordinates = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Auto-follow logic
    if (_shouldFollowUser && points.isNotEmpty && _mapController != null) {
      final lastPoint = points.last;
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(lastPoint.latitude, lastPoint.longitude)),
      );
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
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMoveStarted: () {
                     // If user interacts, stop auto-following? 
                     // Simple logic: if user drags, maybe disable follow. 
                     // For MVP, simple is fine.
                  },
                ),
                Positioned(
                   bottom: 16,
                   left: 16,
                   child: FloatingActionButton(
                     mini: true,
                     backgroundColor: _shouldFollowUser ? Colors.blue : Colors.white,
                     child: Icon(Icons.navigation, color: _shouldFollowUser ? Colors.white : Colors.black),
                     onPressed: () {
                        setState(() {
                          _shouldFollowUser = !_shouldFollowUser;
                        });
                     },
                   )
                ),
                
                // Metrics Overlay
                 Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230), // approx 0.9 * 255
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Points: ${points.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Accuracy: ${tripService.currentAccuracy?.toStringAsFixed(1) ?? "--"} m'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ACTION BUTTONS CONTAINER
          Container(
             padding: const EdgeInsets.all(16),
             decoration: const BoxDecoration(
               color: Colors.white,
               boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 if (state == TripState.idle || state == TripState.error)
                    _buildStartButton(ref, context),
      
                  if (state == TripState.recording || state == TripState.paused) ...[
                     Row(
                       children: [
                         Expanded(child: _buildPauseResumeButton(ref, state)),
                         const SizedBox(width: 8),
                         Expanded(child: _buildStopButton(ref, context)),
                       ],
                     ),
                  ],
      
                   if (state == TripState.saved)
                     ElevatedButton(
                       onPressed: () => ref.read(tripServiceProvider).clear(), // Reset to idle
                       child: const Text('Start New Trip'),
                       style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
      case TripState.recording:
        icon = Icons.fiber_manual_record;
        color = Colors.red;
        title = 'Recording...';
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

  Widget _buildStartButton(WidgetRef ref, BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Trip'),
      onPressed: () async {
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
      label: const Text('Stop Trip'),
      onPressed: () async {
        await ref.read(tripServiceProvider).stopRecording();
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }
}
