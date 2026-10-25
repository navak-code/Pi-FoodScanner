import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

class EmergencyCardScreen extends StatelessWidget {
  const EmergencyCardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final diagnosis = StorageService.getSelectedDiagnosis();
    final redTriggers = StorageService.getAllTriggers()
        .where((t) => t.severity == 2)
        .map((t) => t.name)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        title: const Text('EMERGENCY MEDICAL ID', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SEVERE MEDICAL ALERT',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('PRIMARY DIAGNOSIS:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(diagnosis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('CRITICAL LIFE-THREATENING TRIGGERS:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: redTriggers.map((t) => Chip(
                          label: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          backgroundColor: Colors.red.shade800,
                        )).toList(),
                      ),
                      const Divider(height: 24),
                      const Text('ANAPHYLAXIS EMERGENCY PROTOCOL:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('1. Administer Epinephrine auto-injector into outer mid-thigh.', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('2. Call 911 immediately; state "Anaphylaxis exposure".'),
                      const Text('3. Keep patient lying down; elevate legs if dizzy.'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Text(
                          'Note: For mast cell activation flares, standard antihistamines (H1/H2 blockers) and corticosteroids may be prescribed alongside epinephrine.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
