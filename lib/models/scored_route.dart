import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bike_path.dart';
import 'obstacle.dart';
import 'path_quality_report.dart';
import 'route_candidate.dart';

class ScoredRoute {
  final RouteCandidate route;
  final double totalScore; // 0.0 to 1.0
  final double qualityScore; // Average quality (0.0 to 1.0)
  final double obstaclePenalty; // Total penalty
  final List<String> explanations; // ["Fewer obstacles", "Better surface"]
  final List<Obstacle> nearbyObstacles;
  final List<PathQualityReport> nearbyReports;
  final bool hasDbData; // false = neutral score applied

  const ScoredRoute({
    required this.route,
    required this.totalScore,
    required this.qualityScore,
    required this.obstaclePenalty,
    required this.explanations,
    required this.nearbyObstacles,
    required this.nearbyReports,
    required this.hasDbData,
  });
}
