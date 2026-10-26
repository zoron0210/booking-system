import 'package:flutter/material.dart';

import 'app_text.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({
    super.key,
    required this.settingsBuilder,
    required this.onOpenSystemSettings,
  });

  final Widget Function(BuildContext context, StateSetter setState)
  settingsBuilder;
  final VoidCallback onOpenSystemSettings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Notification settings', localize: true),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatefulBuilder(
            builder: (context, setState) => settingsBuilder(context, setState),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('notification-settings-device'),
            leading: const Icon(Icons.settings_outlined),
            title: const AppText('Device notification settings', localize: true),
            subtitle: const AppText(
              'Manage SpotGo permissions on this device.',
              localize: true,
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: onOpenSystemSettings,
          ),
        ],
      ),
    ),
  );
}
