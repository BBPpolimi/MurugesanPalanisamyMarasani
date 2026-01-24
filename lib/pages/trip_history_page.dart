import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_details_page.dart';
import '../services/providers.dart';
import '../models/trip.dart';

class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsyncValue = ref.watch(tripsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: tripsAsyncValue.when(
        data: (trips) {
          if (trips.isEmpty) {
            return const Center(child: Text('No trips recorded yet.'));
          }
          final tripList = trips.cast<Trip>();
          return ListView.builder(
            itemCount: tripList.length,
            itemBuilder: (context, index) {
              final trip = tripList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.directions_bike, color: Colors.green),
                  title: Text(trip.startTime.toString().split('.')[0]),
                  subtitle: Text(
                    '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km - ${trip.duration.inMinutes} min',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailsPage(trip: trip),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
