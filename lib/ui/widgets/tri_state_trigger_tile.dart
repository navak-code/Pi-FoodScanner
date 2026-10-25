import 'package:flutter/material.dart';
import '../models/trigger_item.dart';

class TriStateTriggerTile extends StatelessWidget {
  final TriggerItem item;
  final VoidCallback onTap;

  const TriStateTriggerTile({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData badgeIcon;
    String statusText;

    if (item.severity == 2) {
      badgeColor = Colors.red.shade700;
      badgeIcon = Icons.cancel;
      statusText = 'Must Avoid';
    } else if (item.severity == 1) {
      badgeColor = Colors.amber.shade800;
      badgeIcon = Icons.warning_amber_rounded;
      statusText = 'Caution';
    } else {
      badgeColor = Colors.grey.shade400;
      badgeIcon = Icons.radio_button_unchecked;
      statusText = 'Safe / Unselected';
    }

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(statusText, style: TextStyle(color: badgeColor, fontSize: 13)),
        trailing: Icon(badgeIcon, color: badgeColor, size: 26),
      ),
    );
  }
}
