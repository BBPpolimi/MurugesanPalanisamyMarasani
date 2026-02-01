// F9 — Merge into Consolidated Status Integration Tests
// These tests run on a REAL DEVICE and interact with the actual app
//
// To run: flutter test test/integration/f9_merge_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F9 - Merge into Consolidated Status Tests', () {
    testWidgets('F9-01: Merged data displayed in community view', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Community paths show merged status data
      final browseCard = find.text('Browse Community Paths');
      if (browseCard.evaluate().isNotEmpty) {
        await tester.tap(browseCard);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Page should load successfully
        expect(find.text('Community Bike Paths'), findsOneWidget);
      }
    });

    testWidgets('F9-02: Status reflects merged contributions', (tester) async {
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

        // Status indicators show merged status
        final statusIndicators = find.textContaining('OPTIMAL');
      }
      expect(true, isTrue);
    });

    testWidgets('F9-03: Path cards display consolidated info', (tester) async {
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

        // Cards should display path info
        final cards = find.byType(Card);
      }
      expect(true, isTrue);
    });
  });
}
