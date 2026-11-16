import 'package:flutter/material.dart';

import 'package:myapp/core/app_text.dart';

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
          const AppText(
            'Choose which alerts you want for matches and booking activity.',
            localize: true,
          ),
          const SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setState) => settingsBuilder(context, setState),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('notification-settings-device'),
            leading: const Icon(Icons.settings_outlined),
            title: const AppText(
              'Device notification settings',
              localize: true,
            ),
            subtitle: const AppText(
              'Review SpotGo permissions and system alerts for this device.',
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
