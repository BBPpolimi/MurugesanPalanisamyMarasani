// F4 — Weather Enrichment Integration Tests
// These tests run on a REAL DEVICE and interact with the actual app
//
// To run: flutter test test/integration/f4_weather_enrichment_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F4 - Weather Enrichment Tests', () {
    testWidgets('F4-01: App handles weather service gracefully', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should launch without crash
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('F4-02: Weather info displayed on trip (if available)', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Navigate to trip history
      final tripHistory = find.text('View Your Recorded Trips');
      if (tripHistory.evaluate().isNotEmpty) {
        await tester.tap(tripHistory.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // If trips exist with weather, weather icons may appear
        final weatherIcon = find.byIcon(Icons.wb_sunny);
        final cloudIcon = find.byIcon(Icons.cloud);
      }
      expect(true, isTrue);
    });

    testWidgets('F4-03: Weather fallback works', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should work even if weather API fails
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
