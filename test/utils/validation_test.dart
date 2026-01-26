import 'package:flutter_test/flutter_test.dart';

/// Validation helper tests for bike path contribution
void main() {
  group('Path Validation Tests', () {
    group('Street Segments Validation', () {
      test('should fail with less than 2 segments', () {
        expect(validateStreets([]), 'Add at least 2 streets');
        expect(validateStreets(['Main Street']), 'Add at least 2 streets');
      });

      test('should pass with 2 or more segments', () {
        expect(validateStreets(['Main Street', 'Oak Ave']), isNull);
        expect(validateStreets(['Aa', 'Bb', 'Cc']), isNull); // Min 2 chars
      });

      test('should fail if segment count exceeds max', () {
        final manyStreets = List.generate(35, (i) => 'Street $i');
        expect(validateStreets(manyStreets), 'Maximum 30 streets allowed');
      });

      test('should fail if street name is too short', () {
        expect(validateStreets(['A', 'Oak Avenue']), 'Street name too short: A');
      });

      test('should fail if street name is too long', () {
        final longName = 'A' * 85;
        expect(
          validateStreets(['Main Street', longName]),
          startsWith('Street name too long:'),
        );
      });
    });

    group('Obstacle Validation', () {
      test('should fail if severity is out of range', () {
        expect(validateObstacleSeverity(0), 'Severity must be between 1 and 5');
        expect(validateObstacleSeverity(6), 'Severity must be between 1 and 5');
      });

      test('should pass for valid severity', () {
        expect(validateObstacleSeverity(1), isNull);
        expect(validateObstacleSeverity(3), isNull);
        expect(validateObstacleSeverity(5), isNull);
      });

      test('should fail if too many obstacles', () {
        final manyObstacles = List.generate(55, (i) => {'id': 'obs$i'});
        expect(validateObstacleCount(manyObstacles.length), 'Maximum 50 obstacles allowed');
      });

      test('should pass for valid obstacle count', () {
        expect(validateObstacleCount(0), isNull);
        expect(validateObstacleCount(10), isNull);
        expect(validateObstacleCount(50), isNull);
      });
    });

    group('Duplicate Detection', () {
      test('should detect consecutive duplicate streets', () {
        expect(
          detectConsecutiveDuplicates(['Main St', 'Main St', 'Oak Ave']),
          'Duplicate consecutive street: Main St',
        );
      });

      test('should not flag non-consecutive duplicates', () {
        expect(
          detectConsecutiveDuplicates(['Main St', 'Oak Ave', 'Main St']),
          isNull,
        );
      });

      test('should be case-insensitive', () {
        expect(
          detectConsecutiveDuplicates(['Main St', 'MAIN ST', 'Oak Ave']),
          'Duplicate consecutive street: MAIN ST',
        );
      });
    });
  });
}

// Validation helpers - these mirror the validation logic in the app
const int minStreets = 2;
const int maxStreets = 30;
const int minStreetNameLength = 2;
const int maxStreetNameLength = 80;
const int maxObstacles = 50;

String? validateStreets(List<String> streetNames) {
  if (streetNames.length < minStreets) {
    return 'Add at least $minStreets streets';
  }
  if (streetNames.length > maxStreets) {
    return 'Maximum $maxStreets streets allowed';
  }
  for (final name in streetNames) {
    if (name.length < minStreetNameLength) {
      return 'Street name too short: $name';
    }
    if (name.length > maxStreetNameLength) {
      return 'Street name too long: ${name.substring(0, 20)}...';
    }
  }
  return null; // valid
}

String? validateObstacleSeverity(int severity) {
  if (severity < 1 || severity > 5) {
    return 'Severity must be between 1 and 5';
  }
  return null;
}

String? validateObstacleCount(int count) {
  if (count > maxObstacles) {
    return 'Maximum $maxObstacles obstacles allowed';
  }
  return null;
}

String? detectConsecutiveDuplicates(List<String> streetNames) {
  for (int i = 1; i < streetNames.length; i++) {
    if (streetNames[i].toLowerCase() == streetNames[i - 1].toLowerCase()) {
      return 'Duplicate consecutive street: ${streetNames[i]}';
    }
  }
  return null;
}
