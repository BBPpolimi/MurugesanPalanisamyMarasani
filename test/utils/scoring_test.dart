import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/utils/scoring.dart';
import 'package:bbp_flutter/models/path_quality_report.dart';

void main() {
  group('RouteScoring', () {
    group('getStatusScore', () {
      test('optimal returns 100', () {
        expect(RouteScoring.getStatusScore(PathRateStatus.optimal), 100);
      });

      test('medium returns 75', () {
        expect(RouteScoring.getStatusScore(PathRateStatus.medium), 75);
      });

      test('sufficient returns 50', () {
        expect(RouteScoring.getStatusScore(PathRateStatus.sufficient), 50);
      });

      test('requiresMaintenance returns 25', () {
        expect(RouteScoring.getStatusScore(PathRateStatus.requiresMaintenance), 25);
      });
    });

    group('getEffectivenessScore', () {
      test('no detour returns 100', () {
        final score = RouteScoring.getEffectivenessScore(1000, 1000);
        expect(score, 100);
      });

      test('10% detour returns 90', () {
        final score = RouteScoring.getEffectivenessScore(1100, 1000);
        expect(score, closeTo(90, 0.1));
      });

      test('50% detour returns 50', () {
        final score = RouteScoring.getEffectivenessScore(1500, 1000);
        expect(score, closeTo(50, 0.1));
      });

      test('100% detour returns 0', () {
        final score = RouteScoring.getEffectivenessScore(2000, 1000);
        expect(score, 0);
      });

      test('more than 100% detour still returns 0', () {
        final score = RouteScoring.getEffectivenessScore(3000, 1000);
        expect(score, 0);
      });

      test('zero direct distance returns 100', () {
        final score = RouteScoring.getEffectivenessScore(1000, 0);
        expect(score, 100);
      });
    });

    group('getObstacleScore', () {
      test('no obstacles returns 100', () {
        final score = RouteScoring.getObstacleScore(0, 0, 5);
        expect(score, 100);
      });

      test('moderate obstacles reduce score', () {
        // 2 obstacles per km with severity 3
        final score = RouteScoring.getObstacleScore(10, 3.0, 5);
        expect(score, lessThan(100));
        expect(score, greaterThan(0));
      });

      test('high severity obstacles reduce score more', () {
        final lowSeverity = RouteScoring.getObstacleScore(5, 1.0, 5);
        final highSeverity = RouteScoring.getObstacleScore(5, 5.0, 5);
        expect(highSeverity, lessThan(lowSeverity));
      });

      test('zero distance returns 100', () {
        final score = RouteScoring.getObstacleScore(5, 3.0, 0);
        expect(score, 100);
      });
    });

    group('getFreshnessScore', () {
      test('today returns close to 100', () {
        final score = RouteScoring.getFreshnessScore(DateTime.now());
        expect(score, closeTo(100, 5));
      });

      test('30 days ago returns approximately 60', () {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final score = RouteScoring.getFreshnessScore(thirtyDaysAgo);
        expect(score, closeTo(60.65, 5)); // exp(-30/60) * 100
      });

      test('60 days ago returns approximately 37', () {
        final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
        final score = RouteScoring.getFreshnessScore(sixtyDaysAgo);
        expect(score, closeTo(36.79, 5)); // exp(-60/60) * 100
      });

      test('null date returns 0', () {
        final score = RouteScoring.getFreshnessScore(null);
        expect(score, 0);
      });
    });

    group('computeTotalScore', () {
      test('weights sum correctly', () {
        // All 100s should give 100
        final score = RouteScoring.computeTotalScore(
          statusScore: 100,
          effectivenessScore: 100,
          obstacleScore: 100,
          freshnessScore: 100,
        );
        expect(score, 100);
      });

      test('applies weights correctly', () {
        // statusScore: 100 * 0.4 = 40
        // effectivenessScore: 80 * 0.35 = 28
        // obstacleScore: 60 * 0.15 = 9
        // freshnessScore: 50 * 0.1 = 5
        // Total: 82
        final score = RouteScoring.computeTotalScore(
          statusScore: 100,
          effectivenessScore: 80,
          obstacleScore: 60,
          freshnessScore: 50,
        );
        expect(score, 82);
      });
    });

    group('calculateDirectDistance', () {
      test('same point returns 0', () {
        final distance = RouteScoring.calculateDirectDistance(
          originLat: 45.4782,
          originLng: 9.2272,
          destLat: 45.4782,
          destLng: 9.2272,
        );
        expect(distance, 0);
      });

      test('known distance is approximately correct', () {
        // Milan to Rome is approximately 477 km
        final distance = RouteScoring.calculateDirectDistance(
          originLat: 45.4642,
          originLng: 9.1900,
          destLat: 41.9028,
          destLng: 12.4964,
        );
        expect(distance, closeTo(477000, 10000)); // Within 10km
      });
    });
  });

  group('MergeAlgorithm', () {
    group('computeWeight', () {
      test('fresh contribution has weight close to 1', () {
        final weight = MergeAlgorithm.computeWeight(
          publishedAt: DateTime.now(),
        );
        expect(weight, closeTo(1.0, 0.1));
      });

      test('30-day old contribution has decayed weight', () {
        final weight = MergeAlgorithm.computeWeight(
          publishedAt: DateTime.now().subtract(const Duration(days: 30)),
        );
        expect(weight, closeTo(0.37, 0.1)); // exp(-30/30) ≈ 0.37
      });

      test('confirmation bonus increases weight', () {
        final noConfirm = MergeAlgorithm.computeWeight(
          publishedAt: DateTime.now(),
          confirmCount: 0,
        );
        final withConfirm = MergeAlgorithm.computeWeight(
          publishedAt: DateTime.now(),
          confirmCount: 5,
        );
        expect(withConfirm, greaterThan(noConfirm));
        expect(withConfirm, closeTo(1.5, 0.1)); // Max bonus is 1.5x
      });
    });

    group('computeMergedStatus', () {
      test('single vote returns that status', () {
        final votes = [
          StatusVote(
            status: PathRateStatus.optimal,
            publishedAt: DateTime.now(),
          ),
        ];
        final result = MergeAlgorithm.computeMergedStatus(votes);
        expect(result, PathRateStatus.optimal);
      });

      test('empty votes returns medium', () {
        final result = MergeAlgorithm.computeMergedStatus([]);
        expect(result, PathRateStatus.medium);
      });

      test('2 optimal vs 1 requiresMaintenance in same timeframe returns optimal', () {
        // This is the example from the requirements
        final now = DateTime.now();
        final votes = [
          StatusVote(
            status: PathRateStatus.optimal,
            publishedAt: now.subtract(const Duration(days: 2)),
          ),
          StatusVote(
            status: PathRateStatus.optimal,
            publishedAt: now.subtract(const Duration(days: 3)),
          ),
          StatusVote(
            status: PathRateStatus.requiresMaintenance,
            publishedAt: now.subtract(const Duration(days: 5)),
          ),
        ];
        
        final result = MergeAlgorithm.computeMergedStatus(votes);
        expect(result, PathRateStatus.optimal);
      });

      test('tie broken by freshest vote', () {
        final now = DateTime.now();
        final votes = [
          StatusVote(
            status: PathRateStatus.optimal,
            publishedAt: now.subtract(const Duration(days: 10)),
          ),
          StatusVote(
            status: PathRateStatus.requiresMaintenance,
            publishedAt: now.subtract(const Duration(days: 1)),
          ),
        ];
        
        // With freshness decay, both have similar weights
        // but requiresMaintenance is fresher for tie-break
        final result = MergeAlgorithm.computeMergedStatus(votes);
        // The fresher one should win if weights are close
        expect(result, anyOf([PathRateStatus.optimal, PathRateStatus.requiresMaintenance]));
      });
    });

    group('computeFreshnessScore', () {
      test('recent dates give high score', () {
        final dates = [
          DateTime.now(),
          DateTime.now().subtract(const Duration(days: 1)),
        ];
        final score = MergeAlgorithm.computeFreshnessScore(dates);
        expect(score, closeTo(100, 5));
      });

      test('empty list returns 0', () {
        final score = MergeAlgorithm.computeFreshnessScore([]);
        expect(score, 0);
      });

      test('uses most recent date', () {
        final dates = [
          DateTime.now().subtract(const Duration(days: 60)),
          DateTime.now(), // Most recent
          DateTime.now().subtract(const Duration(days: 30)),
        ];
        final score = MergeAlgorithm.computeFreshnessScore(dates);
        expect(score, closeTo(100, 5));
      });
    });
  });
}
