// F4 — Weather Enrichment Unit Tests
// These are fast unit tests that run without a device

import 'package:flutter_test/flutter_test.dart';
import 'package:bbp_flutter/models/weather_data.dart';

void main() {
  group('F4 - Weather Enrichment Tests', () {
    test('F4.1 - WeatherData model exists', () {
      final weather = WeatherData(
        conditions: 'Clear',
        temperature: 22.0,
        windSpeed: 3.5,
        queriedAt: DateTime.now(),
      );
      
      expect(weather.conditions, 'Clear');
      expect(weather.temperature, 22.0);
    });

    test('F4.2 - WeatherData serializes to JSON', () {
      final weather = WeatherData(
        conditions: 'Rain',
        temperature: 15.0,
        windSpeed: 5.0,
        queriedAt: DateTime(2025, 1, 1, 10, 0),
      );
      
      final json = weather.toJson();
      expect(json['conditions'], 'Rain');
      expect(json['temperature'], 15.0);
    });

    test('F4.3 - WeatherData deserializes from JSON', () {
      final json = {
        'conditions': 'Clouds',
        'temperature': 18.0,
        'windSpeed': 2.0,
        'queriedAt': '2025-01-01T10:00:00.000',
      };
      
      final weather = WeatherData.fromJson(json);
      expect(weather.conditions, 'Clouds');
      expect(weather.temperature, 18.0);
    });

    test('F4.4 - Weather handles unknown conditions gracefully', () {
      final json = {
        'conditions': null,
        'temperature': null,
        'windSpeed': null,
        'queriedAt': null,
      };
      
      final weather = WeatherData.fromJson(json);
      expect(weather.conditions, 'Unknown');
      expect(weather.temperature, 0.0);
    });
  });
}
