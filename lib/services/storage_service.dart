import 'package:hive_flutter/hive_flutter.dart';
import '../models/trigger_item.dart';
import '../models/scan_record.dart';

class StorageService {
  static const String settingsBoxName = 'settings_box';
  static const String triggersBoxName = 'triggers_box';
  static const String historyBoxName = 'history_box';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(triggersBoxName);
    await Hive.openBox(historyBoxName);
  }

  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get triggersBox => Hive.box(triggersBoxName);
  static Box get historyBox => Hive.box(historyBoxName);

  // Trigger Operations
  static List<TriggerItem> getAllTriggers() {
    return triggersBox.values
        .map((e) => TriggerItem.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveTriggers(List<TriggerItem> items) async {
    await triggersBox.clear();
    for (var item in items) {
      await triggersBox.put(item.name.toLowerCase(), item.toMap());
    }
  }

  // Scan History Operations
  static List<ScanRecord> getAllScanRecords() {
    return historyBox.values
        .map((e) => ScanRecord.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> addScanRecord(ScanRecord record) async {
    await historyBox.put(record.id, record.toMap());
  }

  // Settings
  static bool isOnboardingComplete() =>
      settingsBox.get('onboarding_complete', defaultValue: false);

  static Future<void> setOnboardingComplete(bool val) =>
      settingsBox.put('onboarding_complete', val);

  static String getSelectedDiagnosis() =>
      settingsBox.get('selected_diagnosis', defaultValue: 'None');

  static Future<void> setSelectedDiagnosis(String diag) =>
      settingsBox.put('selected_diagnosis', diag);

  static int getPollingMinutes() =>
      settingsBox.get('polling_minutes', defaultValue: 15);

  static Future<void> setPollingMinutes(int mins) =>
      settingsBox.put('polling_minutes', mins);
}
