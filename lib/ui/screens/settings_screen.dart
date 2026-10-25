import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import '../../services/storage_service.dart';
import '../../services/background_service.dart';
import 'diagnosis_selection_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int _interval = 15;

  @override
  void initState() {
    super.initState();
    _interval = StorageService.getPollingMinutes();
  }

  Future<void> _updateInterval(int minutes) async {
    await StorageService.setPollingMinutes(minutes);
    setState(() => _interval = minutes);

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition();
      await StorageService.settingsBox.put('cached_lat', pos.latitude);
      await StorageService.settingsBox.put('cached_lon', pos.longitude);

      await Workmanager().cancelAll();
      await Workmanager().registerPeriodicTask(
        environmentalTaskIdentifier,
        environmentalTaskIdentifier,
        frequency: Duration(minutes: minutes),
        constraints: Constraints(networkType: NetworkType.connected),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Environmental background polling set to $minutes minutes.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Chronic Illness Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(StorageService.getSelectedDiagnosis(), style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          const Text('Environmental & Weather Polling Frequency', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Monitors OpenWeather for abrupt barometric pressure drops and hazardous air quality index (AQI).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _interval,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            items: const [
              DropdownMenuItem(value: 15, child: Text('Every 15 Minutes')),
              DropdownMenuItem(value: 30, child: Text('Every 30 Minutes')),
              DropdownMenuItem(value: 60, child: Text('Every 1 Hour')),
            ],
            onChanged: (v) {
              if (v != null) _updateInterval(v);
            },
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () async {
              await StorageService.setOnboardingComplete(false);
              await Workmanager().cancelAll();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DiagnosisSelectionScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset Diagnostic Profile & Triggers'),
          ),
        ],
      ),
    );
  }
}
