import 'package:flutter/material.dart';
import '../../models/scan_record.dart';
import '../../services/storage_service.dart';
import '../../services/pi_api_service.dart';

class CoreDashboardTab extends StatefulWidget {
  const CoreDashboardTab({Key? key}) : super(key: key);

  @override
  State<CoreDashboardTab> createState() => _CoreDashboardTabState();
}

class _CoreDashboardTabState extends State<CoreDashboardTab> {
  bool _isProcessing = false;
  String _statusMessage = 'Device online. Standby for capture trigger.';
  String _currentLedState = 'OFF';
  List<String> _lastIngredients = [];

  Future<void> _executeEdgeScan() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Connecting to Raspberry Pi 5 & firing camera...';
    });

    try {
      // 1. Request camera capture & Ollama JSON inference from Raspberry Pi
      final ingredients = await PiApiService.triggerCaptureAndInference();
      
      setState(() {
        _statusMessage = 'Evaluating ${ingredients.length} items against custom triggers...';
        _lastIngredients = ingredients;
      });

      // 2. Evaluate against cached local triggers
      final activeTriggers = StorageService.getAllTriggers();
      final List<String> redHits = [];
      final List<String> yellowHits = [];

      for (var ing in ingredients) {
        final match = activeTriggers.firstWhere(
          (t) => t.name.toLowerCase() == ing.toLowerCase(),
          orElse: () => const TriggerItem(name: '', severity: 0),
        );
        if (match.severity == 2) {
          redHits.add(ing);
        } else if (match.severity == 1) {
          yellowHits.add(ing);
        }
      }

      // 3. Determine safety rating & update Pi GPIO
      String assignedRating;
      String gpioSignal;

      if (redHits.isNotEmpty) {
        assignedRating = 'HIGH RISK';
        gpioSignal = 'RED';
      } else if (yellowHits.isNotEmpty) {
        assignedRating = 'CAUTION';
        gpioSignal = 'YELLOW';
      } else {
        assignedRating = 'SAFE';
        gpioSignal = 'GREEN';
      }

      await PiApiService.pushLedState(gpioSignal);

      // 4. Save to scan history
      final record = ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        detectedIngredients: ingredients,
        matchedRedTriggers: redHits,
        matchedYellowTriggers: yellowHits,
        overallRating: assignedRating,
      );
      await StorageService.addScanRecord(record);

      setState(() {
        _currentLedState = gpioSignal;
        _statusMessage = 'Scan completed: $assignedRating';
        _isProcessing = false;
      });
    } catch (e) {
      await PiApiService.pushLedState('ERROR');
      setState(() {
        _currentLedState = 'ERROR';
        _statusMessage = 'Pipeline failed: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    if (_currentLedState == 'GREEN') statusColor = Colors.green;
    if (_currentLedState == 'YELLOW') statusColor = Colors.amber.shade800;
    if (_currentLedState == 'RED') statusColor = Colors.red;
    if (_currentLedState == 'ERROR') statusColor = Colors.purple;

    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Dashboard'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('HARDWARE LED STATUS', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _currentLedState,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeEdgeScan,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(_isProcessing ? 'Processing...' : 'Capture & Analyze Sample', style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            if (_lastIngredients.isNotEmpty) ...[
              const Text('Recognized Ingredients:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _lastIngredients.length,
                  itemBuilder: (context, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, size: 18),
                    title: Text(_lastIngredients[i]),
                  ),
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
