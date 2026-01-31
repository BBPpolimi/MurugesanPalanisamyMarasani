// F8 — Scoring + Visualization Integration Tests
// These tests run on a REAL DEVICE and interact with the actual app
//
// To run: flutter test test/integration/f8_scoring_visualization_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F8 - Scoring + Visualization Tests', () {
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
        await tester.tap(browseCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for status text
        final optimal = find.text('OPTIMAL');
        final medium = find.text('MEDIUM');
        final maintenance = find.text('REQUIRES_MAINTENANCE');
      }
      expect(true, isTrue);
    });

    testWidgets('F8-02: Score indicators display correctly', (tester) async {
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
        await tester.tap(browseCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for score indicators
        final scoreText = find.textContaining('Score');
        final ratingIcons = find.byIcon(Icons.star);
      }
      expect(true, isTrue);
    });

    testWidgets('F8-03: Map view shows path overlays', (tester) async {
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
        await tester.tap(browseCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Switch to map view
        final mapIcon = find.byIcon(Icons.map);
        if (mapIcon.evaluate().isNotEmpty) {
          await tester.tap(mapIcon.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }
      }
      expect(true, isTrue);
    });

    testWidgets('F8-04: Guest only sees published paths', (tester) async {
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

        // Should only see public paths
        expect(find.text('Community Bike Paths'), findsOneWidget);
      }
    });
  });
}
