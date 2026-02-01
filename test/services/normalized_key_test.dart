import 'package:flutter_test/flutter_test.dart';

/// Tests for the normalized key generation algorithm
/// This is used to group paths that may cover the same route
void main() {
  group('Normalized Key Generation Tests', () {
    test('should generate consistent key for same streets and city', () {
      final key1 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue', 'Park Road'],
        'Milan',
      );
      final key2 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue', 'Park Road'],
        'Milan',
      );

      expect(key1, key2);
    });

    test('should be case-insensitive', () {
      final key1 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        'Milan',
      );
      final key2 = computeNormalizedKey(
        ['MAIN STREET', 'OAK AVENUE'],
        'MILAN',
      );

      expect(key1, key2);
    });

    test('should trim whitespace', () {
      final key1 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        'Milan',
      );
      final key2 = computeNormalizedKey(
        ['  Main Street  ', '  Oak Avenue  '],
        '  Milan  ',
      );

      expect(key1, key2);
    });

    test('should produce different keys for different cities', () {
      final keyMilan = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        'Milan',
      );
      final keyRome = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        'Rome',
      );

      expect(keyMilan, isNot(keyRome));
    });

    test('should produce different keys for different street orders', () {
      final key1 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue', 'Park Road'],
        'Milan',
      );
      final key2 = computeNormalizedKey(
        ['Oak Avenue', 'Main Street', 'Park Road'],
        'Milan',
      );

      expect(key1, isNot(key2));
    });

    test('should handle null city as unknown', () {
      final key1 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        null,
      );
      final key2 = computeNormalizedKey(
        ['Main Street', 'Oak Avenue'],
        'unknown',
      );

      expect(key1, key2);
    });

    test('should handle empty streets list', () {
      final key = computeNormalizedKey([], 'Milan');
      expect(key, isNotEmpty);
    });
  });
}

/// Compute a normalized key from street names for grouping similar paths
/// This mirrors the implementation in ContributeService
String computeNormalizedKey(List<String> streetNames, String? city) {
  final normalizedStreets = streetNames
      .map((s) => s.toLowerCase().trim())
      .join('|');
  final cityPart = (city ?? 'unknown').toLowerCase().trim();
  return '$cityPart:$normalizedStreets'.hashCode.toString();
}
