import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'storage_service.dart';
import 'discovery_service.dart';
import 'pi_api_service.dart';
import '../models/scan_record.dart';
import '../models/trigger_item.dart';

class LiveSyncService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static bool _isConnected = false;

  /// Call this when the app launches to maintain a real-time link with the Pi
  static Future<void> connectToEdgeFeed({Function(ScanRecord)? onNewScan}) async {
    if (_isConnected) return;

    try {
      final piInfo = await DiscoveryService.discoverPi();
      final uri = Uri.parse('ws://${piInfo['host']}:${piInfo['port']}/ws/feed');

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (data) {
          final payload = json.decode(data);
          if (payload['event'] == 'SCAN_COMPLETE') {
            final List<String> ingredients = List<String>.from(payload['ingredients'] ?? []);
            _evaluateAndRespond(ingredients, onNewScan);
          }
        },
        onError: (err) {
          _isConnected = false;
          _reconnectLater(onNewScan);
        },
        onDone: () {
          _isConnected = false;
          _reconnectLater(onNewScan);
        },
      );
    } catch (_) {
      _isConnected = false;
      _reconnectLater(onNewScan);
    }
  }

  static void _reconnectLater(Function(ScanRecord)? onNewScan) {
    Timer(const Duration(seconds: 5), () => connectToEdgeFeed(onNewScan: onNewScan));
  }

  static void _evaluateAndRespond(List<String> ingredients, Function(ScanRecord)? callback) async {
    final triggers = StorageService.getAllTriggers();
    final List<String> redHits = [];
    final List<String> yellowHits = [];

    for (var ing in ingredients) {
      final match = triggers.firstWhere(
        (t) => t.name.toLowerCase() == ing.toLowerCase(),
        orElse: () => const TriggerItem(name: '', severity: 0),
      );
      if (match.severity == 2) {
        redHits.add(ing);
      } else if (match.severity == 1) {
        yellowHits.add(ing);
      }
    }

    String rating = 'SAFE';
    String ledState = 'GREEN';

    if (redHits.isNotEmpty) {
      rating = 'HIGH RISK';
      ledState = 'RED';
      // Distinct tactile alerts
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    } else if (yellowHits.isNotEmpty) {
      rating = 'CAUTION';
      ledState = 'YELLOW';
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Send the evaluated state back to the Pi hardware LEDs
    await PiApiService.pushLedState(ledState);

    // Save scan to database
    final record = ScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      detectedIngredients: ingredients,
      matchedRedTriggers: redHits,
      matchedYellowTriggers: yellowHits,
      overallRating: rating,
    );
    await StorageService.addScanRecord(record);

    if (callback != null) {
      callback(record);
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}
