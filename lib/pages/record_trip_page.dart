import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_state.dart';
import '../services/providers.dart';
import '../services/trip_service.dart';

class RecordTripPage extends ConsumerWidget {
  const RecordTripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripService = ref.watch(tripServiceProvider);
    final state = tripService.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// STATUS CARD
            _buildStatusCard(context, tripService),

            const SizedBox(height: 16),

            /// ACTION BUTTONS
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
               ),

            const SizedBox(height: 24),

            /// POINTS LIST / METRICS
            if (state == TripState.recording || state == TripState.paused)
               Padding(
                 padding: const EdgeInsets.only(bottom: 8.0),
                 child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'GPS Accuracy: ${tripService.currentAccuracy?.toStringAsFixed(1) ?? "--"} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                 ),
               ),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recorded Points',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: tripService.points.length,
                  itemBuilder: (context, index) {
                    final p = tripService.points[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, size: 16),
                      title: Text(
                        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                          p.timestamp.toLocal().toString().split('.').first,
                          style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
        title = 'Recording in progress';
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
               Icon(icon, size: 40, color: color),
               const SizedBox(height: 8),
               Text(title, style: Theme.of(context).textTheme.headlineSmall),
               const SizedBox(height: 4),
               Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
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
