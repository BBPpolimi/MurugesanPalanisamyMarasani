import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_details_page.dart';
import '../services/providers.dart';

class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripService = ref.watch(tripServiceProvider);
    final trips = tripService.trips;

    if (trips.isEmpty) {
      return const Center(
        child: Text('No trips recorded yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.route),
            title: Text(
              '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${trip.duration.inMinutes} min · '
              '${trip.startTime.toLocal().toString().split(".").first}',
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
  }
}
