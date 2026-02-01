import 'package:flutter/material.dart';

/// Path tags for categorizing bike paths
enum PathTag {
  bikeLanePresent,
  lowTraffic,
  speedLimitOk,
  scenic,
  lightingGood,
  avoidAtNight,
  familyFriendly,
  steepHills;

  String get label {
    switch (this) {
      case PathTag.bikeLanePresent:
        return 'Bike Lane Present';
      case PathTag.lowTraffic:
        return 'Low Traffic';
      case PathTag.speedLimitOk:
        return 'Speed Limit OK';
      case PathTag.scenic:
        return 'Scenic';
      case PathTag.lightingGood:
        return 'Good Lighting';
      case PathTag.avoidAtNight:
        return 'Avoid at Night';
      case PathTag.familyFriendly:
        return 'Family Friendly';
      case PathTag.steepHills:
        return 'Steep Hills';
    }
  }

  IconData get icon {
    switch (this) {
      case PathTag.bikeLanePresent:
        return Icons.pedal_bike;
      case PathTag.lowTraffic:
        return Icons.traffic;
      case PathTag.speedLimitOk:
        return Icons.speed;
      case PathTag.scenic:
        return Icons.landscape;
      case PathTag.lightingGood:
        return Icons.light_mode;
      case PathTag.avoidAtNight:
        return Icons.nightlight;
      case PathTag.familyFriendly:
        return Icons.family_restroom;
      case PathTag.steepHills:
        return Icons.terrain;
    }
  }
}
