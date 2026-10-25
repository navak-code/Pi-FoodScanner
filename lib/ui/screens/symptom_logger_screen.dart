import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

class SymptomLoggerScreen extends StatefulWidget {
  const SymptomLoggerScreen({Key? key}) : super(key: key);

  @override
  State<SymptomLoggerScreen> createState() => _SymptomLoggerScreenState();
}

class _SymptomLoggerScreenState extends State<SymptomLoggerScreen> {
  final List<String> _symptomCatalog = [
    'Flushing / Urticaria (Hives)',
    'Tachycardia / Heart Palpitations',
    'Brain Fog / Cognitive Fatigue',
    'Shortness of Breath / Wheezing',
    'Gastrointestinal Cramping',
    'Sudden Migraine / Headache',
    'Joint Pain / Neuropathy',
    'Dizziness / Postural Drop',
  ];

  final Set<String> _selectedSymptoms = {};
  int _severity = 3; // 1 to 5 scale
  final TextEditingController _notesCtrl = TextEditingController();

  void _saveSymptomLog() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one symptom.')),
      );
      return;
    }

    final box = StorageService.settingsBox;
    final List logs = box.get('symptom_logs', defaultValue: []);
    
    final newEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'symptoms': _selectedSymptoms.toList(),
      'severity': _severity,
      'notes': _notesCtrl.text.trim(),
    };

    logs.add(newEntry);
    await box.put('symptom_logs', logs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flare-up logged. Analyzing recent scans...')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentScans = StorageService.getAllScanRecords().take(3).toList();
    final double recentPressure = StorageService.settingsBox.get('baseline_pressure', defaultValue: 1013.25);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Flare-Up / Reaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recent environmental snapshot
            Card(
              color: Colors.blueGrey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ENVIRONMENTAL CONTEXT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    Text('Current Barometric Pressure: ${recentPressure.toStringAsFixed(1)} hPa'),
                    Text('Recent Meal Scans: ${recentScans.length} logged in last session'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Active Symptoms:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _symptomCatalog.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red.shade900,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Severity Level: $_severity / 5', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _severity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: Colors.red.shade700,
              onChanged: (val) => setState(() => _severity = val.toInt()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Additional Context / Suspected Foods',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSymptomLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Flare Log & Correlate', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
