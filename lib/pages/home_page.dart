import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_search_page.dart';
import 'record_trip_page.dart';
import 'trip_history_page.dart';
import 'trip_details_page.dart';
import 'contribute_page.dart';
import 'my_contributions_page.dart';
import 'admin_review_page.dart';
import 'public_paths_page.dart';

import '../services/providers.dart';
import '../models/trip.dart';
import '../models/bike_path.dart';
import '../models/app_user.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  final _pages = const [
    DashboardPage(),
    RecordTripPage(),
    ContributePage(),
    RouteSearchPage(),
  ];

  void _onTabTapped(int i) {
    if (i == 1 || i == 2) {
      final user = ref.read(authStateProvider).value;
      if (user?.isGuest == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to access this feature'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bike),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location_alt),
            label: 'Contribute',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final user = ref.watch(authStateProvider).value;
    final userWithRole = ref.watch(userWithRoleProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best Bike Paths',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (user != null && user.displayName != null)
                        Text(
                          'Hi, ${user.displayName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                ),
                // Admin button (only for admins)
                userWithRole.when(
                  data: (u) => u?.isAdmin == true
                      ? IconButton(
                          icon: const Icon(Icons.admin_panel_settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminReviewPage()),
                            );
                          },
                          tooltip: 'Admin Panel',
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await authService.signOut();
                  },
                  tooltip: 'Sign Out',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ride smart. Ride safe.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            // Quick Actions - My Contributions
            if (user?.isGuest != true) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.folder_special, color: Colors.blue),
                  title: const Text('My Contributions'),
                  subtitle: const Text('View and manage your bike paths'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyContributionsPage()),
                    );
                  },
                ),
              ),
            ],
            
            // Browse Public Paths - available to all users
            const SizedBox(height: 8),
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.explore, color: Colors.green),
                title: const Text('Browse Community Paths'),
                subtitle: const Text('Explore bike paths shared by the community'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PublicPathsPage()),
                  );
                },
              ),
            ),
            
            if (user?.isGuest == true) ...[
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'You are using the app as a guest. Some features are disabled.')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Statistics are not available for guests.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),

              // Use the stream provider for reactive updates
              Consumer(
                builder: (context, ref, child) {
                  final tripsAsync = ref.watch(tripsStreamProvider);

                  return tripsAsync.when(
                    data: (trips) {
                      final totalDistanceKm = trips.isEmpty
                          ? 0.0
                          : trips.fold<double>(0, (sum, t) {
                                if (t is Trip) return sum + t.distanceMeters;
                                if (t is BikePath)
                                  return sum + t.distanceMeters;
                                return sum;
                              }) /
                              1000;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatCard(
                                label: 'Total Activities',
                                value: trips.length.toString(),
                                icon: Icons.directions_bike,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TripHistoryPage(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'Distance',
                                value:
                                    '${totalDistanceKm.toStringAsFixed(1)} km',
                                icon: Icons.map,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Activities',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TripHistoryPage(), // Or separate history
                                    ),
                                  );
                                },
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (trips.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child:
                                  Text('No trips recorded yet. Start riding!'),
                            )
                          else
                            ...trips.take(3).map((item) {
                              String title = '';
                              String subtitle = '';
                              String id = '';
                              bool isTrip = false;

                              if (item is Trip) {
                                title = item.name ??
                                    item.startTime.toString().split('.')[0];
                                subtitle =
                                    '${(item.distanceMeters / 1000).toStringAsFixed(2)} km - ${item.duration.inMinutes} min';
                                id = item.id;
                                isTrip = true;
                              } else if (item is BikePath) {
                                title = item.name ?? 'Manual Path';
                                subtitle =
                                    '${(item.distanceMeters / 1000).toStringAsFixed(2)} km';
                                id = item.id;
                                isTrip = false;
                              } else {
                                title = 'Unknown Activity';
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        isTrip ? Colors.green : Colors.blue,
                                    child: Icon(
                                        isTrip
                                            ? Icons.directions_bike
                                            : Icons.edit_road,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                  title: Text(title),
                                  subtitle: Text(subtitle),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showRenameDialog(
                                            context, ref, item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () => _confirmDelete(
                                            context, ref, id, isTrip),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () {
                                    if (isTrip && item is Trip) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TripDetailsPage(trip: item),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Manual Path details not implemented yet.')));
                                    }
                                  },
                                ),
                              );
                            }),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Could not load stats'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, dynamic item) async {
    // Check type
    String currentName = '';
    if (item is Trip) currentName = item.name ?? '';
    if (item is BikePath) currentName = item.name ?? '';

    final nameController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Activity'),
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
        await ref
            .read(contributeServiceProvider)
            .renameBikePath(item.id, newName);
        ref.refresh(myBikePathsFutureProvider);
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, bool isTrip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text(
            'Are you sure you want to delete this activity? This action cannot be undone.'),
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
        // Force refresh of the combined provider by refreshing the bike paths future
        ref.refresh(myBikePathsFutureProvider);
      }
    }
  }
} // End of DashboardPage

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 32, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
