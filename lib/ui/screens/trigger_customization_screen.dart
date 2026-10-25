import 'package:flutter/material.dart';
import '../../models/illness_preset.dart';
import '../../models/trigger_item.dart';
import '../../services/storage_service.dart';
import '../widgets/color_legend_header.dart';
import '../widgets/tri_state_trigger_tile.dart';
import 'dashboard_screen.dart';

class TriggerCustomizationScreen extends StatefulWidget {
  final IllnessPreset preset;

  const TriggerCustomizationScreen({Key? key, required this.preset}) : super(key: key);

  @override
  State<TriggerCustomizationScreen> createState() => _TriggerCustomizationScreenState();
}

class _TriggerCustomizationScreenState extends State<TriggerCustomizationScreen> {
  late List<TriggerItem> _items;
  String _filter = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate triggers: specific diagnosis items default to Red (2); Custom starts blank (0)
    final bool isCustom = widget.preset.title.contains('Custom');
    _items = widget.preset.defaultTriggers.map((name) {
      return TriggerItem(name: name, severity: isCustom ? 0 : 2);
    }).toList();
  }

  void _cycleTriggerState(int index) {
    setState(() {
      final current = _items[index].severity;
      // Cycle: Red (2) -> Yellow (1) -> Removed/Safe (0) -> Red (2)
      int next;
      if (current == 2) {
        next = 1;
      } else if (current == 1) {
        next = 0;
      } else {
        next = 2;
      }
      _items[index] = _items[index].copyWith(severity: next);
    });
  }

  void _addNewCustomTrigger(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _items.insert(0, TriggerItem(name: name.trim(), severity: 2));
      _searchCtrl.clear();
      _filter = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where((item) => item.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trigger Customization'),
      ),
      body: Column(
        children: [
          // Top-pinned search input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Search or add ingredients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () => _addNewCustomTrigger(_filter),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
          // Fixed color-code legend header
          const ColorLegendHeader(),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text('Add "$_filter" as custom trigger'),
                      onPressed: () => _addNewCustomTrigger(_filter),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final originalIndex = _items.indexOf(item);
                      return TriStateTriggerTile(
                        item: item,
                        onTap: () => _cycleTriggerState(originalIndex),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                await StorageService.saveTriggers(_items);
                await StorageService.setOnboardingComplete(true);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AppNavigationRoot()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save & Initialize Guardian', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
