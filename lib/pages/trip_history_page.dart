import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_details_page.dart';
import '../services/providers.dart';
import '../models/trip.dart';
import '../models/bike_path.dart';

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
          // Do not cast to Trip, keep as dynamic (or Object)
          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final item = trips[index];
              
              String title = '';
              String subtitle = '';
              String id = '';
              bool isTrip = false;
              
               if (item is Trip) {
                 title = item.name ?? item.startTime.toString().split('.')[0];
                 subtitle = '${(item.distanceMeters / 1000).toStringAsFixed(2)} km - ${item.duration.inMinutes} min';
                 id = item.id;
                 isTrip = true;
               } else if (item is BikePath) {
                  title = item.name ?? 'Manual Path';
                  subtitle = '${(item.distanceMeters / 1000).toStringAsFixed(2)} km';
                  id = item.id;
                  isTrip = false;
               } else {
                  title = 'Unknown Activity';
                  id = '';
               }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isTrip ? Colors.green : Colors.blue,
                    child: Icon(isTrip ? Icons.directions_bike : Icons.edit_road, color: Colors.white, size: 20),
                  ),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(
                         icon: const Icon(Icons.edit, size: 20),
                         onPressed: () => _showRenameDialog(context, ref, item),
                       ),
                       IconButton(
                         icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                         onPressed: () => _confirmDelete(context, ref, id, isTrip),
                       ),
                       const SizedBox(width: 8),
                       const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    if (isTrip && item is Trip) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripDetailsPage(trip: item),
                        ),
                      );
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual Path details not implemented yet.')));
                    }
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
  
  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref, dynamic item) async {
    String currentName = '';
    if (item is Trip) currentName = item.name ?? '';
    if (item is BikePath) currentName = item.name ?? '';

    final nameController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Activity'),
        // No wrapping SingleChildScrollView here automatically, but TextField usually works. 
        // If needed we can add it, but Dialog usually handles it.
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
       if (item is Trip) {
          await ref.read(tripServiceProvider).renameTrip(item, newName);
       } else if (item is BikePath) {
          await ref.read(contributeServiceProvider).renameBikePath(item.id, newName);
          ref.refresh(myBikePathsFutureProvider); // Assuming this provider is available and exported or we can just invalidate contributeServiceProvider or tripsStreamProvider
          // Actually tripsStreamProvider listens to tripRepository which is fine, but for bike paths we might need to force refresh if it's not a real-time stream.
          // In providers.dart, tripsStreamProvider fetches bikePaths on every trip stream event properly? 
          // Wait, tripsStreamProvider only yields when tripsStream updates. Renaming a bike path might NOT trigger tripsStream update.
          // We should force refresh tripsStreamProvider or better myBikePathsFutureProvider if used.
          // tripsStreamProvider re-fetches bike paths on every trip stream event.
          // But if we only rename a bike path, the TRIP stream doesn't change, so tripsStreamProvider might not emit safely.
          // We need to invalidate tripsStreamProvider or make it depend on something that changes.
          ref.invalidate(tripsStreamProvider);
       }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, bool isTrip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isTrip) {
        await ref.read(tripServiceProvider).deleteTrip(id);
      } else {
        await ref.read(contributeServiceProvider).deleteBikePath(id);
        ref.invalidate(tripsStreamProvider); // Refresh the list
      }
    }
  }
}
