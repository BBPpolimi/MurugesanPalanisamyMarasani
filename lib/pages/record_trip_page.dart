import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class RecordTripPage extends ConsumerWidget {
  const RecordTripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripService = ref.watch(tripServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Record Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// STATUS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      tripService.recording
                          ? Icons.fiber_manual_record
                          : Icons.pause_circle,
                      size: 40,
                      color:
                          tripService.recording ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tripService.recording
                          ? 'Recording in progress'
                          : 'Ready to start',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tripService.recording
                          ? 'GPS is tracking your ride'
                          : 'Press start when you begin cycling',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ACTION BUTTONS
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
              onPressed: tripService.recording
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(tripServiceProvider)
                            .startRecording();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop Trip'),
              onPressed: tripService.recording
                  ? () async {
                      await ref
                          .read(tripServiceProvider)
                          .stopRecording();

                      final summary =
                          ref.read(tripServiceProvider).lastSummary;
                      if (summary != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Trip saved: '
                              '${(summary.distanceMeters / 1000).toStringAsFixed(2)} km · '
                              '${summary.duration.inMinutes} min',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(50),
              ),
            ),

            const SizedBox(height: 24),

            /// POINTS LIST
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
                      leading: const Icon(Icons.location_on),
                      title: Text(
                        '${p.latitude.toStringAsFixed(5)}, '
                        '${p.longitude.toStringAsFixed(5)}',
                      ),
                      subtitle:
                          Text(p.timestamp.toLocal().toIso8601String()),
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
}
