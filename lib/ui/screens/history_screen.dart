import 'package:flutter/material.dart';
import '../../models/scan_record.dart';
import '../../services/storage_service.dart';

class ScanHistoryTab extends StatelessWidget {
  const ScanHistoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final records = StorageService.getAllScanRecords();

    return Scaffold(
      appBar: AppBar(title: const Text('Past Scans'), centerTitle: true),
      body: records.isEmpty
          ? const Center(child: Text('No previous evaluations recorded.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (context, i) {
                final rec = records[i];
                Color badgeColor = Colors.green;
                if (rec.overallRating == 'HIGH RISK') badgeColor = Colors.red;
                if (rec.overallRating == 'CAUTION') badgeColor = Colors.amber.shade800;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    title: Text(
                      rec.overallRating,
                      style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                    subtitle: Text(rec.timestamp.toString().substring(0, 16)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('All Ingredients: ${rec.detectedIngredients.join(", ")}'),
                            const SizedBox(height: 8),
                            if (rec.matchedRedTriggers.isNotEmpty)
                              Text(
                                'Must Avoid Triggers: ${rec.matchedRedTriggers.join(", ")}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            if (rec.matchedYellowTriggers.isNotEmpty)
                              Text(
                                'Caution Triggers: ${rec.matchedYellowTriggers.join(", ")}',
                                style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}
