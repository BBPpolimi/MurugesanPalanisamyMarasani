# BBP Flutter scaffold

This scaffold contains an opinionated starting point for the Best Bike Paths (BBP) project.

## Included
- Basic Flutter app with Riverpod
- `Record Trip` page that samples GPS and sensors
- `TripService` with start/stop recording and simple distance calculation
- Placeholders for Firebase + Map integration

## How to use
1. Create a new Flutter project (`flutter create bbp_flutter`) or copy files into your existing project.
2. Paste `pubspec.yaml` dependencies and run `flutter pub get`.
3. Replace `lib/` with provided files.
4. Run on simulator / device: `flutter run`.

## Next steps I can implement for you (pick one):
- Firebase setup (Auth + Firestore) and sample integration
- Map view with Mapbox / Google Maps + route visualization
- Automatic pothole detection heuristics and review UI
- Backend scoring + merging algorithm (Cloud Functions or FastAPI)