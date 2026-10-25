import 'dart:convert';
import 'package:http/http.dart' as http;
import 'discovery_service.dart';

class PiApiService {
  static Future<List<String>> triggerCaptureAndInference() async {
    final target = await DiscoveryService.discoverPi();
    final url = Uri.parse('http://${target['host']}:${target['port']}/api/v1/capture-and-analyze');

    final response = await http.post(url).timeout(const Duration(seconds: 65));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['ingredients'] ?? []);
    } else {
      throw Exception('Server returned HTTP ${response.statusCode}: ${response.body}');
    }
  }

  static Future<void> pushLedState(String state) async {
    final target = await DiscoveryService.discoverPi();
    final url = Uri.parse('http://${target['host']}:${target['port']}/api/v1/gpio/state');

    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'state': state}),
    ).timeout(const Duration(seconds: 4));
  }
}

