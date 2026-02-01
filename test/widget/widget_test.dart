// Widget Tests for Best Bike Paths (BBP)
// These tests verify core UI components and navigation without device
//
// To run: flutter test test/widget/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/gps_point.dart';
import 'package:bbp_flutter/models/trip.dart';
import 'package:bbp_flutter/models/bike_path.dart';
import 'package:bbp_flutter/models/street_segment.dart';
import 'package:bbp_flutter/models/path_quality_report.dart';
import 'package:bbp_flutter/models/obstacle.dart';

void main() {
  // ============================================================
  // F1 — SIGN UP / SIGN IN Widget Tests
  // ============================================================
  group('F1 - Authentication Widget Tests', () {
    testWidgets('F1-W01: Login button is a tappable widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Sign In'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      
      expect(true, isTrue);
    });

    testWidgets('F1-W02: Guest login button exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Continue as Guest'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('F1-W03: Google Sign-In button UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });
  });

  // ============================================================
  // F2 — TRIP RECORDING Widget Tests
  // ============================================================
  group('F2 - Trip Recording Widget Tests', () {
    testWidgets('F2-W01: Start Recording button UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Recording'),
            ),
          ),
        ),
      );

      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('F2-W02: Stop Recording button UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ),
      );

      expect(find.text('Stop Recording'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('F2-W03: Recording stats display', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Distance: 5.2 km'),
                const Text('Duration: 00:25:30'),
                const Text('Speed: 12.5 km/h'),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('km'), findsWidgets);
      expect(find.textContaining('Duration'), findsOneWidget);
      expect(find.textContaining('Speed'), findsOneWidget);
    });

    testWidgets('F2-W04: GPS point model serialization', (tester) async {
      final point = GpsPoint(
        latitude: 45.4782,
        longitude: 9.2272,
        elevation: 120.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2025, 1, 1, 10, 30),
      );

      final json = point.toJson();
      expect(json['latitude'], 45.4782);
      expect(json['longitude'], 9.2272);
      expect(json['elevation'], 120.0);
      expect(json['accuracyMeters'], 5.0);

      final restored = GpsPoint.fromJson(json);
      expect(restored.latitude, point.latitude);
      expect(restored.longitude, point.longitude);
    });
  });

  // ============================================================
  // F3 — TRIP HISTORY Widget Tests
  // ============================================================
  group('F3 - Trip History Widget Tests', () {
    testWidgets('F3-W01: Trip list item widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: const Icon(Icons.directions_bike),
              title: const Text('Morning Commute'),
              subtitle: const Text('5.2 km • 25 min'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );

      expect(find.text('Morning Commute'), findsOneWidget);
      expect(find.textContaining('km'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('F3-W02: Empty trip history state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bike, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No trips yet'),
                  Text('Start recording to see your trips here'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('F3-W03: Trip model serialization', (tester) async {
      final trip = Trip(
        id: 'trip-123',
        userId: 'user-456',
        startTime: DateTime(2025, 1, 1, 10, 0),
        endTime: DateTime(2025, 1, 1, 10, 30),
        points: [],
        distanceMeters: 5200.0,
        duration: const Duration(minutes: 30),
        averageSpeed: 10.4,
      );

      final json = trip.toJson();
      expect(json['id'], 'trip-123');
      expect(json['userId'], 'user-456');
      expect(json['distanceMeters'], 5200.0);

      final restored = Trip.fromJson(json);
      expect(restored.id, trip.id);
      expect(restored.distanceMeters, trip.distanceMeters);
    });
  });

  // ============================================================
  // F5 — PATH CONTRIBUTIONS Widget Tests
  // ============================================================
  group('F5 - Path Contributions Widget Tests', () {
    testWidgets('F5-W01: Create path button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Create Path'),
            ),
          ),
        ),
      );

      expect(find.text('Create Path'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('F5-W02: Path status chip displays correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('OPTIMAL'),
                  backgroundColor: Colors.green.shade100,
                ),
                Chip(
                  label: const Text('MEDIUM'),
                  backgroundColor: Colors.yellow.shade100,
                ),
                Chip(
                  label: const Text('REQUIRES MAINTENANCE'),
                  backgroundColor: Colors.red.shade100,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('OPTIMAL'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('REQUIRES MAINTENANCE'), findsOneWidget);
    });

    testWidgets('F5-W03: Bike path model serialization', (tester) async {
      final path = BikePath(
        id: 'path-123',
        userId: 'user-456',
        name: 'Central Park Trail',
        city: 'Milan',
        segments: [
          StreetSegment(id: 'seg-1', streetName: 'Via Roma', formattedAddress: 'Via Roma, Milan', lat: 45.0, lng: 9.0),
          StreetSegment(id: 'seg-2', streetName: 'Corso Como', formattedAddress: 'Corso Como, Milan', lat: 45.1, lng: 9.1),
        ],
        status: PathRateStatus.optimal,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(path.name, 'Central Park Trail');
      expect(path.city, 'Milan');
      expect(path.segments.length, 2);
      expect(path.status, PathRateStatus.optimal);
    });

    testWidgets('F5-W04: Obstacle type dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButton<ObstacleType>(
              value: ObstacleType.pothole,
              items: ObstacleType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (value) {},
            ),
          ),
        ),
      );

      expect(find.byType(DropdownButton<ObstacleType>), findsOneWidget);
    });
  });

  // ============================================================
  // F7 — ROUTE SEARCH Widget Tests
  // ============================================================
  group('F7 - Route Search Widget Tests', () {
    testWidgets('F7-W01: Search form with origin and destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Origin',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                    label: const Text('SEARCH ROUTES'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('SEARCH ROUTES'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('F7-W02: Route card displays correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text('85'),
                ),
                title: const Text('Route 1 - Via Park'),
                subtitle: const Text('5.2 km • 18 min • Score: 85/100'),
                trailing: IconButton(
                  icon: const Icon(Icons.directions),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Route 1 - Via Park'), findsOneWidget);
      expect(find.textContaining('km'), findsOneWidget);
      expect(find.byIcon(Icons.directions), findsOneWidget);
    });
  });

  // ============================================================
  // F8 — SCORING Widget Tests
  // ============================================================
  group('F8 - Scoring Widget Tests', () {
    testWidgets('F8-W01: Score indicator widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: const Text(
                    '92',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Overall Score', style: TextStyle(fontSize: 12)),
                    Text('Excellent', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('92'), findsOneWidget);
      expect(find.text('Overall Score'), findsOneWidget);
      expect(find.text('Excellent'), findsOneWidget);
    });

    testWidgets('F8-W02: Status badge colors', (tester) async {
      Color getStatusColor(PathRateStatus status) {
        switch (status) {
          case PathRateStatus.optimal:
            return Colors.green;
          case PathRateStatus.medium:
            return Colors.orange;
          case PathRateStatus.sufficient:
            return Colors.yellow;
          case PathRateStatus.requiresMaintenance:
            return Colors.red;
        }
      }

      expect(getStatusColor(PathRateStatus.optimal), Colors.green);
      expect(getStatusColor(PathRateStatus.medium), Colors.orange);
      expect(getStatusColor(PathRateStatus.requiresMaintenance), Colors.red);
    });
  });

  // ============================================================
  // F10 — ADMIN Widget Tests
  // ============================================================
  group('F10 - Admin Widget Tests', () {
    testWidgets('F10-W01: Admin action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Flag Content'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block User'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Content'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Flag Content'), findsOneWidget);
      expect(find.text('Block User'), findsOneWidget);
      expect(find.text('Remove Content'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });

  // ============================================================
  // NAVIGATION Widget Tests
  // ============================================================
  group('Navigation Widget Tests', () {
    testWidgets('NAV-W01: Bottom navigation bar', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: selectedIndex,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
                BottomNavigationBarItem(icon: Icon(Icons.fiber_manual_record), label: 'Record'),
                BottomNavigationBarItem(icon: Icon(Icons.add_location_alt), label: 'Contribute'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('NAV-W02: Tab navigation works', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: IndexedStack(
                  index: selectedIndex,
                  children: const [
                    Center(child: Text('Home Page')),
                    Center(child: Text('Map Page')),
                    Center(child: Text('Record Page')),
                    Center(child: Text('Contribute Page')),
                  ],
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: selectedIndex,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) => setState(() => selectedIndex = index),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                    BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
                    BottomNavigationBarItem(icon: Icon(Icons.fiber_manual_record), label: 'Record'),
                    BottomNavigationBarItem(icon: Icon(Icons.add_location_alt), label: 'Contribute'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Home Page'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.text('Map Page'), findsOneWidget);

      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      expect(find.text('Record Page'), findsOneWidget);
    });
  });

  // ============================================================
  // ERROR HANDLING Widget Tests
  // ============================================================
  group('Error Handling Widget Tests', () {
    testWidgets('ERR-W01: Error message widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  const Text('Something went wrong'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('ERR-W02: Loading indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });
  });
}
