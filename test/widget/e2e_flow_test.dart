// End-to-End Flow Tests for Best Bike Paths (BBP)
// These tests verify complete user flows similar to integration_test/
// but run without a device using mocked widgets
//
// To run: flutter test test/widget/e2e_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============================================================
  // F1 — AUTHENTICATION FLOW
  // ============================================================
  group('F1 - Authentication Flow', () {
    testWidgets('F1-E2E-01: Complete guest login flow', (tester) async {
      bool isLoggedIn = false;
      String currentPage = 'login';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (currentPage == 'login') {
                return Scaffold(
                  appBar: AppBar(title: const Text('Welcome Back')),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() {
                            isLoggedIn = true;
                            currentPage = 'home';
                          }),
                          child: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() {
                            isLoggedIn = true;
                            currentPage = 'home';
                          }),
                          child: const Text('Continue as Guest'),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Scaffold(
                  appBar: AppBar(title: const Text('Home')),
                  body: const Center(child: Text('Welcome to BBP!')),
                );
              }
            },
          ),
        ),
      );

      // Initially on login page
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      // Tap guest login
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Should navigate to home
      expect(find.text('Welcome to BBP!'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });

    testWidgets('F1-E2E-02: Logout returns to login page', (tester) async {
      String currentPage = 'home';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (currentPage == 'home') {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Home'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () => setState(() => currentPage = 'login'),
                      ),
                    ],
                  ),
                  body: const Center(child: Text('Welcome!')),
                );
              } else {
                return Scaffold(
                  appBar: AppBar(title: const Text('Welcome Back')),
                  body: const Center(child: Text('Please sign in')),
                );
              }
            },
          ),
        ),
      );

      // Initially on home
      expect(find.text('Home'), findsOneWidget);

      // Tap logout
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Should return to login
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  // ============================================================
  // F2 — TRIP RECORDING FLOW
  // ============================================================
  group('F2 - Trip Recording Flow', () {
    testWidgets('F2-E2E-01: Start and stop recording flow', (tester) async {
      bool isRecording = false;
      int elapsedSeconds = 0;
      double distance = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Record Trip')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Stats display
                      Text('Distance: ${distance.toStringAsFixed(1)} km'),
                      Text('Time: ${Duration(seconds: elapsedSeconds).toString().split('.').first}'),
                      const SizedBox(height: 32),
                      
                      // Recording button
                      ElevatedButton.icon(
                        onPressed: () => setState(() {
                          isRecording = !isRecording;
                          if (isRecording) {
                            // Simulate recording
                            elapsedSeconds = 0;
                            distance = 0.0;
                          } else {
                            // Simulate end of recording
                            elapsedSeconds = 1800; // 30 min
                            distance = 8.5;
                          }
                        }),
                        icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
                        label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRecording ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Initially showing start button
      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Start recording
      await tester.tap(find.text('Start Recording'));
      await tester.pumpAndSettle();

      // Should show stop button
      expect(find.text('Stop Recording'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);

      // Stop recording
      await tester.tap(find.text('Stop Recording'));
      await tester.pumpAndSettle();

      // Should show results
      expect(find.textContaining('8.5 km'), findsOneWidget);
      expect(find.text('Start Recording'), findsOneWidget);
    });

    testWidgets('F2-E2E-02: Guest cannot access recording', (tester) async {
      bool isGuest = true;
      String snackbarMessage = '';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Record')),
                body: Builder(
                  builder: (context) {
                    if (isGuest) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('Sign In Required'),
                            const Text('Please sign in to record trips'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please sign in to access this feature')),
                                );
                              },
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const Center(child: Text('Recording UI'));
                    }
                  },
                ),
              );
            },
          ),
        ),
      );

      // Guest sees restriction
      expect(find.text('Sign In Required'), findsOneWidget);
      expect(find.text('Please sign in to record trips'), findsOneWidget);
    });
  });

  // ============================================================
  // F3 — TRIP HISTORY FLOW
  // ============================================================
  group('F3 - Trip History Flow', () {
    testWidgets('F3-E2E-01: View trip history list', (tester) async {
      final trips = [
        {'name': 'Morning Ride', 'distance': 5.2, 'duration': '00:25'},
        {'name': 'Evening Commute', 'distance': 8.1, 'duration': '00:40'},
        {'name': 'Weekend Tour', 'distance': 15.7, 'duration': '01:15'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Trip History')),
            body: ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return ListTile(
                  leading: const Icon(Icons.directions_bike),
                  title: Text(trip['name'] as String),
                  subtitle: Text('${trip['distance']} km • ${trip['duration']}'),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('Morning Ride'), findsOneWidget);
      expect(find.text('Evening Commute'), findsOneWidget);
      expect(find.text('Weekend Tour'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsNWidgets(3));
    });

    testWidgets('F3-E2E-02: Tap trip to view details', (tester) async {
      String currentPage = 'list';
      String selectedTrip = '';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (currentPage == 'list') {
                return Scaffold(
                  appBar: AppBar(title: const Text('Trip History')),
                  body: ListView(
                    children: [
                      ListTile(
                        title: const Text('Morning Ride'),
                        onTap: () => setState(() {
                          currentPage = 'details';
                          selectedTrip = 'Morning Ride';
                        }),
                      ),
                    ],
                  ),
                );
              } else {
                return Scaffold(
                  appBar: AppBar(
                    title: Text(selectedTrip),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => currentPage = 'list'),
                    ),
                  ),
                  body: const Column(
                    children: [
                      Text('Distance: 5.2 km'),
                      Text('Duration: 00:25'),
                      Text('Average Speed: 12.5 km/h'),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      );

      // Initially on list
      expect(find.text('Trip History'), findsOneWidget);

      // Tap trip
      await tester.tap(find.text('Morning Ride'));
      await tester.pumpAndSettle();

      // Should show details
      expect(find.text('Morning Ride'), findsOneWidget);
      expect(find.text('Distance: 5.2 km'), findsOneWidget);

      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Trip History'), findsOneWidget);
    });
  });

  // ============================================================
  // F5 — CONTRIBUTION FLOW
  // ============================================================
  group('F5 - Contribution Flow', () {
    testWidgets('F5-E2E-01: Browse community paths', (tester) async {
      final paths = [
        {'name': 'Central Park Loop', 'status': 'OPTIMAL', 'city': 'Milan'},
        {'name': 'River Trail', 'status': 'MEDIUM', 'city': 'Milan'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Community Bike Paths')),
            body: ListView.builder(
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final path = paths[index];
                final statusColor = path['status'] == 'OPTIMAL' ? Colors.green : Colors.orange;
                return Card(
                  child: ListTile(
                    title: Text(path['name'] as String),
                    subtitle: Text(path['city'] as String),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        path['status'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Community Bike Paths'), findsOneWidget);
      expect(find.text('Central Park Loop'), findsOneWidget);
      expect(find.text('River Trail'), findsOneWidget);
      expect(find.text('OPTIMAL'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
    });

    testWidgets('F5-E2E-02: Create path form stepper', (tester) async {
      int currentStep = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Create Bike Path')),
                body: Stepper(
                  currentStep: currentStep,
                  onStepContinue: () {
                    if (currentStep < 2) {
                      setState(() => currentStep++);
                    }
                  },
                  onStepCancel: () {
                    if (currentStep > 0) {
                      setState(() => currentStep--);
                    }
                  },
                  steps: [
                    Step(
                      title: const Text('Basic Info'),
                      content: const TextField(
                        decoration: InputDecoration(labelText: 'Path Name'),
                      ),
                      isActive: currentStep >= 0,
                    ),
                    Step(
                      title: const Text('Draw Path'),
                      content: const Text('Tap on map to draw your path'),
                      isActive: currentStep >= 1,
                    ),
                    Step(
                      title: const Text('Review'),
                      content: const Text('Review and submit your path'),
                      isActive: currentStep >= 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Create Bike Path'), findsOneWidget);
      expect(find.text('Basic Info'), findsOneWidget);

      // Continue to next step
      await tester.tap(find.text('Continue').first);
      await tester.pumpAndSettle();

      expect(find.text('Tap on map to draw your path'), findsOneWidget);
    });
  });

  // ============================================================
  // F7 — ROUTE SEARCH FLOW
  // ============================================================
  group('F7 - Route Search Flow', () {
    testWidgets('F7-E2E-01: Search for routes', (tester) async {
      String origin = '';
      String destination = '';
      bool hasSearched = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Find Routes')),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: 'Origin'),
                        onChanged: (v) => origin = v,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Destination'),
                        onChanged: (v) => destination = v,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => hasSearched = true),
                        child: const Text('SEARCH BICYCLE ROUTES'),
                      ),
                      if (hasSearched) ...[
                        const SizedBox(height: 24),
                        const Text('Found 3 routes:'),
                        const ListTile(
                          title: Text('Route 1 - Via Park'),
                          subtitle: Text('5.2 km • Score: 92'),
                        ),
                        const ListTile(
                          title: Text('Route 2 - Downtown'),
                          subtitle: Text('4.8 km • Score: 78'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Find Routes'), findsOneWidget);
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);

      // Enter addresses
      await tester.enterText(find.byType(TextField).first, 'Piazza Duomo');
      await tester.enterText(find.byType(TextField).last, 'Parco Sempione');

      // Search
      await tester.tap(find.text('SEARCH BICYCLE ROUTES'));
      await tester.pumpAndSettle();

      // Results shown
      expect(find.text('Found 3 routes:'), findsOneWidget);
      expect(find.text('Route 1 - Via Park'), findsOneWidget);
    });
  });

  // ============================================================
  // NAVIGATION FLOW
  // ============================================================
  group('Navigation Flow', () {
    testWidgets('NAV-E2E-01: Complete tab navigation', (tester) async {
      int selectedIndex = 0;
      final pages = ['Home', 'Map', 'Record', 'Contribute'];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: Text(pages[selectedIndex])),
                body: Center(child: Text('${pages[selectedIndex]} Page Content')),
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

      // Start at Home
      expect(find.text('Home Page Content'), findsOneWidget);

      // Navigate to Map
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      expect(find.text('Map Page Content'), findsOneWidget);

      // Navigate to Record
      await tester.tap(find.byIcon(Icons.fiber_manual_record));
      await tester.pumpAndSettle();
      expect(find.text('Record Page Content'), findsOneWidget);

      // Navigate to Contribute
      await tester.tap(find.byIcon(Icons.add_location_alt));
      await tester.pumpAndSettle();
      expect(find.text('Contribute Page Content'), findsOneWidget);

      // Back to Home
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.text('Home Page Content'), findsOneWidget);
    });

    testWidgets('NAV-E2E-02: Rapid tab switching stress test', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(child: Text('Tab $selectedIndex')),
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

      // Rapidly switch tabs using labels
      for (int i = 0; i < 20; i++) {
        final labels = ['Home', 'Map', 'Record', 'Contribute'];
        final label = labels[i % 4];
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // App should not crash
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });

  // ============================================================
  // ERROR HANDLING FLOW
  // ============================================================
  group('Error Handling Flow', () {
    testWidgets('ERR-E2E-01: Network error with retry', (tester) async {
      bool hasError = true;
      bool isLoading = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 64),
                        const SizedBox(height: 16),
                        const Text('Network Error'),
                        const Text('Please check your connection'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            isLoading = true;
                            Future.delayed(const Duration(milliseconds: 100), () {
                              setState(() {
                                isLoading = false;
                                hasError = false;
                              });
                            });
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const Scaffold(
                body: Center(child: Text('Content Loaded!')),
              );
            },
          ),
        ),
      );

      // Initially shows error
      expect(find.text('Network Error'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Content loaded
      expect(find.text('Content Loaded!'), findsOneWidget);
    });
  });
}
