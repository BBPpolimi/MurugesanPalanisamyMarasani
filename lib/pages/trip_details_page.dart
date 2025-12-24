import 'package:flutter/material.dart';
import '../models/trip.dart';

class TripDetailsPage extends StatelessWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start: ${trip.startTime}'),
            Text('End: ${trip.endTime}'),
            const SizedBox(height: 12),
            Text('Distance: ${(trip.distanceMeters / 1000).toStringAsFixed(2)} km'),
            Text('Duration: ${trip.duration.inMinutes} minutes'),
            Text('Avg speed: ${trip.averageSpeed.toStringAsFixed(2)} m/s'),
            const SizedBox(height: 12),
            Text('Points recorded: ${trip.points.length}'),
          ],
        ),
      ),
    );
  }
}
