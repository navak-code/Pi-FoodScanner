import 'package:flutter/material.dart';
import '../../models/illness_preset.dart';
import '../../services/storage_service.dart';
import 'trigger_customization_screen.dart';

class DiagnosisSelectionScreen extends StatefulWidget {
  const DiagnosisSelectionScreen({Key? key}) : super(key: key);

  @override
  State<DiagnosisSelectionScreen> createState() => _DiagnosisSelectionScreenState();
}

class _DiagnosisSelectionScreenState extends State<DiagnosisSelectionScreen> {
  String? _selectedTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primary Diagnosis', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select your chronic condition to pre-configure your dietary triggers. Items default to Red (Must Avoid) for your safety.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: IllnessPreset.catalog.length,
                  itemBuilder: (context, index) {
                    final preset = IllnessPreset.catalog[index];
                    final isChosen = _selectedTitle == preset.title;

                    return Card(
                      color: isChosen ? const Color(0xFFE8F0FE) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isChosen ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                          width: isChosen ? 2 : 1,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          isChosen ? Icons.check_circle : Icons.circle_outlined,
                          color: isChosen ? const Color(0xFF1A73E8) : Colors.grey,
                        ),
                        title: Text(
                          preset.title,
                          style: TextStyle(
                            fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () => setState(() => _selectedTitle = preset.title),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _selectedTitle == null
                    ? null
                    : () async {
                        final chosenPreset = IllnessPreset.catalog.firstWhere(
                          (p) => p.title == _selectedTitle,
                        );
                        await StorageService.setSelectedDiagnosis(chosenPreset.title);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TriggerCustomizationScreen(preset: chosenPreset),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2540),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Configure Trigger Sensitivity', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
