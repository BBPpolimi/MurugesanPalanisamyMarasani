import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trip_service.dart';

final tripServiceProvider =
    ChangeNotifierProvider<TripService>((ref) => TripService());
