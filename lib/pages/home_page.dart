import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_search_page.dart';
import 'record_trip_page.dart';
import 'trip_history_page.dart';
import 'trip_details_page.dart';

import '../services/providers.dart';
import '../models/trip.dart';

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
    Center(child: Text('Contribute (stub)')),
    MapSearchPage(),
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

    return Padding(
      padding: const EdgeInsets.all(16),
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
                   Expanded(child: Text('You are using the app as a guest. Some features are disabled.')),
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
                     final tripList = trips.cast<Trip>();
                     final totalDistanceKm = tripList.isEmpty
                         ? 0.0
                         : tripList.fold<double>(
                                 0, (sum, t) => sum + t.distanceMeters) /
                             1000;
                             
                     return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             _StatCard(
                               label: 'Trips',
                               value: tripList.length.toString(),
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
                               value: '${totalDistanceKm.toStringAsFixed(1)} km',
                               icon: Icons.map,
                             ),
                           ],
                         ),
                         const SizedBox(height: 24),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               'Recent Trips',
                               style: Theme.of(context).textTheme.titleLarge,
                             ),
                             TextButton(
                               onPressed: () {
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(
                                     builder: (_) => const TripHistoryPage(),
                                   ),
                                 );
                               },
                               child: const Text('View All'),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         if (tripList.isEmpty)
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 16.0),
                             child: Text('No trips recorded yet. Start riding!'),
                           )
                         else
                           ...tripList.take(3).map((trip) {
                             return Card(
                               margin: const EdgeInsets.symmetric(vertical: 4),
                               child: ListTile(
                                 leading: const CircleAvatar(
                                   backgroundColor: Colors.green,
                                   child: Icon(Icons.directions_bike, color: Colors.white, size: 20),
                                 ),
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
                           }),
                       ],
                     );
                   },
                   loading: () => const Center(child: CircularProgressIndicator()),
                   error: (_, __) => const Text('Could not load stats'),
                 );
               },
             ),
          ],
        ],
      ),
    );
  }
}

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
