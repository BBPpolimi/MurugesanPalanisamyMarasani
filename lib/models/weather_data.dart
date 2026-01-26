class WeatherData {
  final String conditions; // e.g., "Clear", "Rain", "Clouds"
  final double temperature; // Celsius
  final double windSpeed; // m/s
  final DateTime queriedAt;

  WeatherData({
    required this.conditions,
    required this.temperature,
    required this.windSpeed,
    required this.queriedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'conditions': conditions,
      'temperature': temperature,
      'windSpeed': windSpeed,
      'queriedAt': queriedAt.toIso8601String(),
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      conditions: json['conditions'] as String? ?? 'Unknown',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      queriedAt: json['queriedAt'] != null
          ? DateTime.parse(json['queriedAt'] as String)
          : DateTime.now(),
    );
  }
}
