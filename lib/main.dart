import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/storage_service.dart';
import 'services/background_service.dart';
import 'ui/screens/diagnosis_selection_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive persistence engine
  await StorageService.initialize();

  // Initialize Workmanager for environmental background polling
  Workmanager().initialize(
    backgroundTaskDispatcher,
    isInDebugMode: false,
  );

  runApp(const DietaryGuardianApp());
}

class DietaryGuardianApp extends StatelessWidget {
  const DietaryGuardianApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isReady = StorageService.isOnboardingComplete();

    return MaterialApp(
      title: 'Dietary Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2540),
          primary: const Color(0xFF0A2540),
        ),
      ),
      home: isReady ? const AppNavigationRoot() : const DiagnosisSelectionScreen(),
    );
  }
}

class AppNavigationRoot extends StatefulWidget {
  const AppNavigationRoot({Key? key}) : super(key: key);

  @override
  State<AppNavigationRoot> createState() => _AppNavigationRootState();
}

class _AppNavigationRootState extends State<AppNavigationRoot> {
  int _tab = 0;
  final _screens = const [
    CoreDashboardTab(),
    ScanHistoryTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Guardian'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Past Scans'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
