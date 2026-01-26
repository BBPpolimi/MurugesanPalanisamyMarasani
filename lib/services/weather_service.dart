import 'package:dio/dio.dart';
import '../models/weather_data.dart';

/// Service for fetching weather data from OpenWeatherMap API.
class WeatherService {
  static const String _apiKey = '2cdae1e892a0bd2c3078ecb2d414af62';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  final Dio _dio = Dio();

  /// Fetch current weather for given coordinates.
  /// Returns null if the request fails.
  Future<WeatherData?> getWeather(double lat, double lng) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'appid': _apiKey,
          'units': 'metric', // Celsius
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Extract weather info
        final weather = data['weather'] as List?;
        String conditions = 'Unknown';
        if (weather != null && weather.isNotEmpty) {
          conditions = weather[0]['main'] as String? ?? 'Unknown';
        }

        final main = data['main'] as Map<String, dynamic>?;
        final temperature = (main?['temp'] as num?)?.toDouble() ?? 0.0;

        final wind = data['wind'] as Map<String, dynamic>?;
        final windSpeed = (wind?['speed'] as num?)?.toDouble() ?? 0.0;

        return WeatherData(
          conditions: conditions,
          temperature: temperature,
          windSpeed: windSpeed,
          queriedAt: DateTime.now(),
        );
      }
    } catch (e) {
      // Log error but don't crash - weather is optional
      // ignore: avoid_print
      print('WeatherService error: $e');
    }

    return null;
  }
}
