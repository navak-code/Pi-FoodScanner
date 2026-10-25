/// Represents an historical inference evaluation record.
class ScanRecord {
  final String id;
  final DateTime timestamp;
  final List<String> detectedIngredients;
  final List<String> matchedRedTriggers;
  final List<String> matchedYellowTriggers;
  final String overallRating; // 'SAFE', 'CAUTION', 'HIGH RISK'

  const ScanRecord({
    required this.id,
    required this.timestamp,
    required this.detectedIngredients,
    required this.matchedRedTriggers,
    required this.matchedYellowTriggers,
    required this.overallRating,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'detectedIngredients': detectedIngredients,
    'matchedRedTriggers': matchedRedTriggers,
    'matchedYellowTriggers': matchedYellowTriggers,
    'overallRating': overallRating,
  };

  factory ScanRecord.fromMap(Map<dynamic, dynamic> map) => ScanRecord(
    id: map['id'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    detectedIngredients: List<String>.from(map['detectedIngredients'] ?? []),
    matchedRedTriggers: List<String>.from(map['matchedRedTriggers'] ?? []),
    matchedYellowTriggers: List<String>.from(map['matchedYellowTriggers'] ?? []),
    overallRating: map['overallRating'] as String,
  );
}
