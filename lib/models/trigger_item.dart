/// Represents a dietary trigger item and its warning level.
/// Tri-state: 0 = Unselected (Safe), 1 = Yellow (Caution), 2 = Red (Must Avoid).
class TriggerItem {
  final String name;
  final int severity; // 0, 1, or 2

  const TriggerItem({
    required this.name,
    required this.severity,
  });

  TriggerItem copyWith({int? severity}) {
    return TriggerItem(
      name: name,
      severity: severity ?? this.severity,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'severity': severity,
  };

  factory TriggerItem.fromMap(Map<dynamic, dynamic> map) => TriggerItem(
    name: map['name'] as String,
    severity: (map['severity'] as num).toInt(),
  );
}
