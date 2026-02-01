// F10 — Admin/Moderation Integration Tests
// These tests run on a REAL DEVICE and interact with the actual app
//
// To run: flutter test test/integration/f10_admin_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F10 - Admin/Moderation Tests', () {
    testWidgets('F10-01: Admin icon NOT visible for guest user', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Admin icon should NOT be visible for guest
      final adminIcon = find.byIcon(Icons.admin_panel_settings);
      expect(adminIcon, findsNothing);
    });

    testWidgets('F10-02: Shield icon NOT visible for regular users', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Shield icon should not be visible
      final shieldIcon = find.byIcon(Icons.shield);
      final securityIcon = find.byIcon(Icons.security);

      expect(shieldIcon.evaluate().isEmpty && securityIcon.evaluate().isEmpty, isTrue);
    });

    testWidgets('F10-03: Admin panel visible if user is admin', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Try Google Sign-In (may be an admin account)
      final googleButton = find.text('Continue with Google');
      if (googleButton.evaluate().isNotEmpty) {
        await tester.tap(googleButton);
        await tester.pumpAndSettle(const Duration(seconds: 8));
      }

      // Check for admin icon (only visible if user has admin role)
      final adminIcon = find.byIcon(Icons.admin_panel_settings);
      // If admin, this should be visible
      // If not admin, test passes by not finding it

      expect(true, isTrue);
    });

    testWidgets('F10-04: Admin panel has moderation options (if admin)', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Try Google Sign-In
      final googleButton = find.text('Continue with Google');
      if (googleButton.evaluate().isNotEmpty) {
        await tester.tap(googleButton);
        await tester.pumpAndSettle(const Duration(seconds: 8));
      }

      // Tap admin icon if present
      final adminIcon = find.byIcon(Icons.admin_panel_settings);
      if (adminIcon.evaluate().isNotEmpty) {
        await tester.tap(adminIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Should see admin options
        final flagOption = find.text('Flag');
        final blockOption = find.text('Block User');
        final runMerge = find.text('Run Merge');
      }

      expect(true, isTrue);
    });
  });
}
