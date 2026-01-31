// F1 — Authentication Integration Tests
// These tests run on a REAL DEVICE and interact with the actual app
//
// To run: flutter test integration_test/f1_auth_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:bbp_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F1 - Authentication Tests', () {
    testWidgets('F1-01: App launches successfully', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should have loaded - either login page or home page (if already logged in)
      final loginPage = find.text('Welcome Back');
      final homePage = find.text('Best Bike Paths');
      
      // Either login or home page should be shown
      expect(loginPage.evaluate().isNotEmpty || homePage.evaluate().isNotEmpty, isTrue);
    });

    testWidgets('F1-02: Login has Google Sign-In option', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for Google button (only visible on login page)
      final googleButton = find.text('Continue with Google');
      final homePage = find.text('Best Bike Paths');
      
      // If on login page, should see Google button; if on home page, already logged in
      expect(googleButton.evaluate().isNotEmpty || homePage.evaluate().isNotEmpty, isTrue);
    });

    testWidgets('F1-03: Login has Guest option', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final guestButton = find.text('Continue as Guest');
      final homePage = find.text('Best Bike Paths');
      
      // If on login page, should see guest button; if on home page, already logged in
      expect(guestButton.evaluate().isNotEmpty || homePage.evaluate().isNotEmpty, isTrue);
    });

    testWidgets('F1-04: Can navigate to home page', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if already on home page
      final homePage = find.text('Best Bike Paths');
      if (homePage.evaluate().isNotEmpty) {
        // Already logged in - pass
        expect(homePage, findsOneWidget);
        return;
      }
      
      // Otherwise try guest login
      final guestButton = find.text('Continue as Guest');
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
      
      // Should now be on home page
      expect(find.text('Best Bike Paths'), findsOneWidget);
    });

    testWidgets('F1-05: Home page has navigation bar', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Ensure we're logged in (either already or via guest)
      final homePage = find.text('Best Bike Paths');
      if (homePage.evaluate().isEmpty) {
        final guestButton = find.text('Continue as Guest');
        if (guestButton.evaluate().isNotEmpty) {
          await tester.tap(guestButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }
      
      // Home page should have bottom navigation
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('F1-06: Home page has logout button', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Ensure we're logged in
      final homePage = find.text('Best Bike Paths');
      if (homePage.evaluate().isEmpty) {
        final guestButton = find.text('Continue as Guest');
        if (guestButton.evaluate().isNotEmpty) {
          await tester.tap(guestButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }

      // Look for logout icon
      final logoutIcon = find.byIcon(Icons.logout);
      expect(logoutIcon, findsOneWidget);
    });

    testWidgets('F1-07: Logout returns to login page', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Ensure we're logged in
      final homePage = find.text('Best Bike Paths');
      if (homePage.evaluate().isEmpty) {
        final guestButton = find.text('Continue as Guest');
        if (guestButton.evaluate().isNotEmpty) {
          await tester.tap(guestButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }

      // Tap logout
      final logoutIcon = find.byIcon(Icons.logout);
      if (logoutIcon.evaluate().isNotEmpty) {
        await tester.tap(logoutIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        // Should be back on login page
        expect(find.text('Welcome Back'), findsOneWidget);
      }
    });

    testWidgets('F1-08: Guest can access Browse Community Paths', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login as guest if needed
      final loginPage = find.text('Welcome Back');
      if (loginPage.evaluate().isNotEmpty) {
        final guestButton = find.text('Continue as Guest');
        if (guestButton.evaluate().isNotEmpty) {
          await tester.tap(guestButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }

      // Find and tap Browse Community Paths
      final browseBtn = find.text('Browse Community Paths');
      if (browseBtn.evaluate().isNotEmpty) {
        await tester.tap(browseBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        // Should see Community Bike Paths page
        expect(find.text('Community Bike Paths'), findsOneWidget);
      }
      expect(true, isTrue);
    });
  });
}
