import 'dart:async';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveryService {
  /// Locates the Raspberry Pi service over mDNS, returning host and port.
  static Future<Map<String, dynamic>> discoverPi() async {
    String resolvedHost = 'raspberrypi.local';
    int resolvedPort = 5000;

    try {
      final discovery = await nsd.startDiscovery('_http._tcp.local.');
      final completer = Completer<void>();

      void listener() {
        for (var service in discovery.services) {
          if (service.name != null &&
              service.name!.toLowerCase().contains('guardian')) {
            if (service.host != null) resolvedHost = service.host!;
            if (service.port != null) resolvedPort = service.port!;
            if (!completer.isCompleted) completer.complete();
            break;
          }
        }
      }

      discovery.addListener(listener);

      // Await resolution or time out after 2.5 seconds
      await Future.any([
        completer.future,
        Future.delayed(const Duration(milliseconds: 2500)),
      ]);

      await nsd.stopDiscovery(discovery);
    } catch (_) {
      // Fall back to default hostname if discovery times out
    }

    return {'host': resolvedHost, 'port': resolvedPort};
  }
}
