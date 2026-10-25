import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherEvaluationResult {
  final double currentPressure;
  final double pressureDelta;
  final int airQualityIndex; // 1 (Good) to 5 (Very Poor)
  final bool alertTriggered;
  final String reason;

  const WeatherEvaluationResult({
    required this.currentPressure,
    required this.pressureDelta,
    required this.airQualityIndex,
    required this.alertTriggered,
    required this.reason,
  });
}

class WeatherService {
  static const String apiKey = 'YOUR_OPENWEATHER_API_KEY'; // Replace with a valid key

  static Future<WeatherEvaluationResult> checkConditions({
    required double latitude,
    required double longitude,
    required double previousPressure,
  }) async {
    // 1. Fetch Current Barometric Metrics
    final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric');
    final weatherRes = await http.get(weatherUrl).timeout(const Duration(seconds: 10));
    
    double pressure = 1013.25;
    if (weatherRes.statusCode == 200) {
      final data = json.decode(weatherRes.body);
      pressure = (data['main']['pressure'] as num).toDouble();
    }

    // 2. Fetch Air Pollution Metrics
    final aqiUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$latitude&lon=$longitude&appid=$apiKey');
    final aqiRes = await http.get(aqiUrl).timeout(const Duration(seconds: 10));
    
    int aqi = 1;
    if (aqiRes.statusCode == 200) {
      final aqiData = json.decode(aqiRes.body);
      aqi = (aqiData['list'][0]['main']['aqi'] as num).toInt();
    }

    // Pressure drops >= 4.0 hPa indicate rapid barometric shifts (common dysautonomia/migraine trigger)
    double delta = (previousPressure - pressure);
    bool pressureBreach = delta >= 4.0;
    bool aqiBreach = aqi >= 4; // Poor / Very Poor air quality

    bool alert = pressureBreach || aqiBreach;
    String reason = 'Normal conditions';
    if (pressureBreach && aqiBreach) {
      reason = 'Severe pressure drop (-${delta.toStringAsFixed(1)} hPa) & Poor AQI ($aqi)';
    } else if (pressureBreach) {
      reason = 'Barometric pressure drop (-${delta.toStringAsFixed(1)} hPa)';
    } else if (aqiBreach) {
      reason = 'Hazardous air quality index ($aqi/5)';
    }

    return WeatherEvaluationResult(
      currentPressure: pressure,
      pressureDelta: delta,
      airQualityIndex: aqi,
      alertTriggered: alert,
      reason: reason,
    );
  }
}
