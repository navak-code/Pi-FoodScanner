import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'storage_service.dart';
import 'weather_service.dart';
import 'pi_api_service.dart';

const String environmentalTaskIdentifier = "com.guardian.environmental_poll";

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await StorageService.initialize();

      // Retrieve GPS position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        // Fall back to cached coordinates
        double lat = StorageService.settingsBox.get('cached_lat', defaultValue: 41.5043);
        double lon = StorageService.settingsBox.get('cached_lon', defaultValue: -81.6084);
        position = Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }

      double prevPressure = StorageService.settingsBox.get('baseline_pressure', defaultValue: 1013.25);

      final result = await WeatherService.checkConditions(
        latitude: position.latitude,
        longitude: position.longitude,
        previousPressure: prevPressure,
      );

      // Update baseline with current reading
      await StorageService.settingsBox.put('baseline_pressure', result.currentPressure);
      await StorageService.settingsBox.put('cached_lat', position.latitude);
      await StorageService.settingsBox.put('cached_lon', position.longitude);

      if (result.alertTriggered) {
        // Pulse the yellow LED on the Raspberry Pi
        await PiApiService.pushLedState('ENV_ALERT');
      }

      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}
