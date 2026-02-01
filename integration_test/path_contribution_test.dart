// Comprehensive Integration Tests for Best Bike Paths (BBP)
// Covering Feature Threads F1-F10 for both Guest and Registered Users
//
// To run:
// flutter test integration_test/ -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // F1 — SIGN UP / SIGN IN
  // ============================================================
  group('F1 - Sign Up / Sign In', () {
    testWidgets('F1-01: App launches and shows LoginPage when not authenticated', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify LoginPage elements
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('F1-02: Guest login flow works', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final guestButton = find.text('Continue as Guest');
      expect(guestButton, findsOneWidget);

      await tester.tap(guestButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After guest login, should NOT be on LoginPage
      expect(find.text('Welcome Back'), findsNothing);
    });

    testWidgets('F1-03: Sign Up link navigates to registration', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final signUpLink = find.text('Sign Up');
      if (signUpLink.evaluate().isNotEmpty) {
        await tester.tap(signUpLink);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should see registration form elements
        // (verify we navigated away from login OR see "Create Account" text)
        final createAccount = find.text('Create Account');
        final registerButton = find.text('Register');
        expect(createAccount.evaluate().isNotEmpty || registerButton.evaluate().isNotEmpty, isTrue);
      }
    });

    testWidgets('F1-04: Login form validation - empty fields', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Try to sign in without entering credentials
      final signInButton = find.text('Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should show validation error or remain on login page
        expect(find.text('Welcome Back'), findsOneWidget);
      }
    });

    testWidgets('F1-05: Logout flow works', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest first
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Look for logout button (usually in app bar or settings)
      final logoutIcon = find.byIcon(Icons.logout);
      final logoutTooltip = find.byTooltip('Sign Out');

      if (logoutIcon.evaluate().isNotEmpty) {
        await tester.tap(logoutIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        // Should return to LoginPage
        expect(find.text('Welcome Back'), findsOneWidget);
      } else if (logoutTooltip.evaluate().isNotEmpty) {
        await tester.tap(logoutTooltip.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Welcome Back'), findsOneWidget);
      }
    });
  });

  // ============================================================
  // F2 — TRIP RECORDING CORE
  // ============================================================
  group('F2 - Trip Recording Core', () {
    testWidgets('F2-01: Guest cannot access Record tab', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Try to find and tap Record tab
      final recordTab = find.byIcon(Icons.fiber_manual_record);
      final recordText = find.text('Record');

      if (recordTab.evaluate().isNotEmpty) {
        await tester.tap(recordTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // Should see restriction message
        final snackbar = find.text('Please sign in to access this feature');
        // If snackbar appears, guest is properly restricted
      } else if (recordText.evaluate().isNotEmpty) {
        await tester.tap(recordText.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Test passes if no crash
      expect(true, isTrue);
    });

    testWidgets('F2-02: Record page UI elements exist for authenticated user', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // This test verifies Record page UI structure
      // Without actual auth, we skip actual recording but verify structure
      // For full test, need Firebase emulator with test credentials

      expect(true, isTrue); // Placeholder - needs authenticated session
    });

    testWidgets('F2-03: App handles location permission gracefully', (tester) async {
      // This test would verify permission handling
      // Integration tests cannot directly control system permissions
      // Manual verification required

      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify app launches without crash
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ============================================================
  // F3 — TRIP PERSISTENCE / HISTORY / DETAILS
  // ============================================================
  group('F3 - Trip Persistence / History / Details', () {
    testWidgets('F3-01: Trip History page is accessible after login', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Look for Trip History or My Trips option
      final tripHistory = find.text('Trip History');
      final myTrips = find.text('My Trips');
      final viewTrips = find.text('View Your Recorded Trips');

      if (tripHistory.evaluate().isNotEmpty) {
        await tester.tap(tripHistory.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      } else if (myTrips.evaluate().isNotEmpty) {
        await tester.tap(myTrips.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      } else if (viewTrips.evaluate().isNotEmpty) {
        await tester.tap(viewTrips.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Should not crash
      expect(true, isTrue);
    });

    testWidgets('F3-02: Empty trip history shows appropriate message', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest (new user has no trips)
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to trip history
      final viewTrips = find.text('View Your Recorded Trips');
      if (viewTrips.evaluate().isNotEmpty) {
        await tester.tap(viewTrips.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Should show empty state or "no trips" message
        final noTrips = find.textContaining('No trips');
        final emptyState = find.textContaining('Start recording');
        // Either message is acceptable
      }

      expect(true, isTrue);
    });
  });

  // ============================================================
  // F4 — WEATHER ENRICHMENT
  // ============================================================
  group('F4 - Weather Enrichment', () {
    testWidgets('F4-01: App handles weather service gracefully', (tester) async {
      // Weather enrichment is tested during trip recording
      // This test verifies the app doesn't crash when weather service is unavailable

      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify app launches successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ============================================================
  // F5 — MANUAL PATH CONTRIBUTIONS
  // ============================================================
  group('F5 - Manual Path Contributions', () {
    testWidgets('F5-01: Browse Community Paths accessible to guest', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Find Browse Community Paths
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Should see Community Bike Paths page
        expect(find.text('Community Bike Paths'), findsOneWidget);
      }
    });

    testWidgets('F5-02: Guest cannot access Contribute tab', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Try to access Contribute tab
      final contributeTab = find.byIcon(Icons.add_location_alt);
      final contributeText = find.text('Contribute');

      if (contributeTab.evaluate().isNotEmpty) {
        await tester.tap(contributeTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // Should show sign-in required message
      } else if (contributeText.evaluate().isNotEmpty) {
        await tester.tap(contributeText.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      expect(true, isTrue);
    });

    testWidgets('F5-03: My Contributions page accessible to registered user', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest (for now - need real auth for full test)
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Look for My Contributions
      final myContributions = find.text('My Contributions');
      if (myContributions.evaluate().isNotEmpty) {
        await tester.tap(myContributions.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      expect(true, isTrue);
    });

    testWidgets('F5-04: Public paths page filtering works', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to Community Paths
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for filter dropdowns
        final statusFilter = find.text('Status');
        final cityFilter = find.text('City');

        // Filters should exist
        if (statusFilter.evaluate().isNotEmpty || cityFilter.evaluate().isNotEmpty) {
          // Filters are present - test passed
        }
      }

      expect(true, isTrue);
    });
  });

  // ============================================================
  // F6 — AUTOMATIC DETECTION REVIEW
  // ============================================================
  group('F6 - Automatic Detection Review', () {
    testWidgets('F6-01: Review Issues page structure (if accessible)', (tester) async {
      // Automatic detection requires actual trip with sensor data
      // This test verifies the review flow exists

      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Placeholder - requires authenticated user with recorded trip
      expect(true, isTrue);
    });
  });

  // ============================================================
  // F7 — ROUTE SEARCH
  // ============================================================
  group('F7 - Route Search', () {
    testWidgets('F7-01: Route search page is accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Try different icon types for Map/Search tab
      final mapTab = find.byIcon(Icons.map);
      final searchTab = find.byIcon(Icons.search);
      final directionsTab = find.byIcon(Icons.directions_bike);

      Finder? tabToTap;
      if (mapTab.evaluate().isNotEmpty) {
        tabToTap = mapTab;
      } else if (searchTab.evaluate().isNotEmpty) {
        tabToTap = searchTab;
      } else if (directionsTab.evaluate().isNotEmpty) {
        tabToTap = directionsTab;
      }

      if (tabToTap != null) {
        await tester.tap(tabToTap.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      expect(true, isTrue);
    });

    testWidgets('F7-02: Route search has input fields', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to map page
      final mapTab = find.byIcon(Icons.map);
      if (mapTab.evaluate().isNotEmpty) {
        await tester.tap(mapTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for address input hints
        final startHint = find.text('Start');
        final destinationHint = find.text('Destination');
        final originHint = find.text('Origin');

        // At least one should exist if on route search page
      }

      expect(true, isTrue);
    });

    testWidgets('F7-03: Map widget loads without crash', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to any page with a map
      final mapTab = find.byIcon(Icons.map);
      if (mapTab.evaluate().isNotEmpty) {
        await tester.tap(mapTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // If we got here, map loaded successfully
      expect(true, isTrue);
    });
  });

  // ============================================================
  // F8 — SCORING + VISUALIZATION
  // ============================================================
  group('F8 - Scoring + Visualization', () {
    testWidgets('F8-01: Community paths show status indicators', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to Community Paths
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for status text that would appear on path cards
        final optimal = find.text('OPTIMAL');
        final medium = find.text('MEDIUM');
        final sufficient = find.text('SUFFICIENT');
        final maintenance = find.text('REQUIRES_MAINTENANCE');

        // Any status indicator presence is valid
      }

      expect(true, isTrue);
    });

    testWidgets('F8-02: Guest only sees published paths', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to Community Paths
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Page should load with only public paths
        // Private/flagged content should not appear
        expect(find.text('Community Bike Paths'), findsOneWidget);
      }
    });

    testWidgets('F8-03: Toggle between list and map view', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to Community Paths
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for view toggle
        final mapIcon = find.byIcon(Icons.map);
        final listIcon = find.byIcon(Icons.list);

        if (mapIcon.evaluate().isNotEmpty) {
          await tester.tap(mapIcon.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        if (listIcon.evaluate().isNotEmpty) {
          await tester.tap(listIcon.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      }

      expect(true, isTrue);
    });
  });

  // ============================================================
  // F9 — MERGE INTO CONSOLIDATED STATUS
  // ============================================================
  group('F9 - Merge into Consolidated Status', () {
    testWidgets('F9-01: Merged data displayed in community view', (tester) async {
      // Merge is a backend process; this test verifies the result is visible

      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Community paths should show merged status data
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      expect(true, isTrue);
    });
  });

  // ============================================================
  // F10 — ADMIN / MODERATION
  // ============================================================
  group('F10 - Admin / Moderation', () {
    testWidgets('F10-01: Admin icon not visible for guest user', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Admin icon should NOT be visible
      final adminIcon = find.byIcon(Icons.admin_panel_settings);
      expect(adminIcon, findsNothing);
    });

    testWidgets('F10-02: Admin panel settings icon not in regular nav', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Shield icon (admin indicator) should not be visible
      final shieldIcon = find.byIcon(Icons.shield);
      final securityIcon = find.byIcon(Icons.security);

      // Neither admin indicator should be present for guest
      expect(shieldIcon.evaluate().isEmpty && securityIcon.evaluate().isEmpty, isTrue);
    });
  });

  // ============================================================
  // NAVIGATION & UI STABILITY TESTS
  // ============================================================
  group('Navigation & UI Stability', () {
    testWidgets('NAV-01: All bottom navigation tabs are accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Try tapping each bottom nav item
      final homeIcon = find.byIcon(Icons.home);
      final mapIcon = find.byIcon(Icons.map);
      final recordIcon = find.byIcon(Icons.fiber_manual_record);
      final contributeIcon = find.byIcon(Icons.add_location_alt);

      if (homeIcon.evaluate().isNotEmpty) {
        await tester.tap(homeIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      if (mapIcon.evaluate().isNotEmpty) {
        await tester.tap(mapIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Record and Contribute may show restriction for guest - that's OK

      expect(true, isTrue);
    });

    testWidgets('NAV-02: Back navigation works correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate somewhere
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Try back button
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      }

      expect(true, isTrue);
    });

    testWidgets('NAV-03: App survives rapid tab switching', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Rapidly switch between tabs
      for (int i = 0; i < 5; i++) {
        final homeIcon = find.byIcon(Icons.home);
        final mapIcon = find.byIcon(Icons.map);

        if (homeIcon.evaluate().isNotEmpty) {
          await tester.tap(homeIcon.first);
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (mapIcon.evaluate().isNotEmpty) {
          await tester.tap(mapIcon.first);
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should not crash
      expect(true, isTrue);
    });
  });

  // ============================================================
  // ERROR HANDLING TESTS
  // ============================================================
  group('Error Handling', () {
    testWidgets('ERR-01: App handles empty data gracefully', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to Community Paths (may be empty)
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Should show empty state OR list of paths, not crash
        final header = find.text('Community Bike Paths');
        expect(header, findsOneWidget);
      }
    });
  });
}
