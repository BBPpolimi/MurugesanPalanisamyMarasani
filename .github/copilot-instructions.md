# Copilot instructions for BBP (Best Bike Paths)

This file gives succinct, actionable guidance for AI coding agents working in this Flutter repo.

- Project snapshot: Flutter app "Best Bike Paths" at repository root. Entry point: `lib/main.dart` (wraps app in `ProviderScope`). State: `flutter_riverpod`.
- Structure: UI in `lib/pages/`, domain models in `lib/models/`, app services in `lib/services/`. Platform folders: `android/`, `ios/`, `macos/`, `web/`, `linux/`, `windows/`.

- Key dependencies (see `pubspec.yaml`): `flutter_riverpod`, `geolocator`, `sensors_plus`, `dio`, `uuid`, `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`.

- Architecture & patterns to preserve
  - Use Riverpod for app-level state. `main.dart` provides the `ProviderScope`; follow existing provider patterns in `lib/pages/*` and `lib/services/*`.
  - Keep UI code in `lib/pages/*`. Business logic and side effects belong in `lib/services/*` (example: `lib/services/trip_repository.dart` is a simple in-memory repo — replace with persistence carefully).
  - Models are simple data holders in `lib/models/*` (immutable value-style classes preferred).

- Integration points and cautions
  - Firebase: Android config present at `android/app/google-services.json`. iOS config must be checked in `ios/Runner/` (use Xcode workspace `ios/Runner.xcworkspace`).
  - Location & sensors: `geolocator` and `sensors_plus` are used for motion/location features — prefer platform permission checks before calls.
  - Networking: `dio` is the HTTP client in `pubspec.yaml` — follow existing error/timeout patterns if present.

- Developer workflows (commands you can run)
  - Restore deps: `flutter pub get`
  - Run app (debug): `flutter run` (or use IDE Flutter run/debug). For Android gradle tasks use `./android/gradlew assembleDebug`.
  - Build APK: `flutter build apk`; iOS: open `ios/Runner.xcworkspace` and build via Xcode (CocoaPods required). If pods are missing run `pod install` in `ios/`.
  - Tests: `flutter test` (unit/widget tests in `test/`).
  - Lint/format: `flutter analyze` and `flutter format .` (project uses `flutter_lints`).

- Project-specific conventions
  - File naming: snake_case for files, classes in CamelCase matching file responsibility.
  - Services return plain synchronous collections where appropriate (see `TripRepository`), so be mindful when introducing async or persistence to preserve API compatibility.
  - Generated and build artifacts live under `build/` — do not edit.

- When modifying integrations
  - If you add/modify Firebase usage, update platform config (`google-services.json`, iOS plist) and document required secrets. Do not commit private keys.
  - For location or sensor changes, add runtime permission handling and test on device/emulator.

- Good-first edits (examples)
  - Persist `TripRepository` to local storage: update `lib/services/trip_repository.dart`, add chosen package (e.g., `shared_preferences` or `hive`), and add tests under `test/`.
  - Add networked API: create a new service in `lib/services/` using `dio` and register providers via Riverpod.

- References (examples to open)
  - App entry & state: `lib/main.dart`
  - Example service: `lib/services/trip_repository.dart`
  - Pages: `lib/pages/home_page.dart` (UI pattern examples)
  - Dependencies: `pubspec.yaml`

If anything above is unclear or you want more examples (provider usage, sample tests, or a migration plan for `TripRepository`), say which area to expand and I will update this file.
