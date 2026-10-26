import 'package:flutter/material.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'booking_push_notifications.dart';
import 'features/session/application/session_service.dart';

class BookingTransactionNotificationSettings extends StatefulWidget {
  const BookingTransactionNotificationSettings({
    super.key,
    required this.api,
    required this.onMessage,
  });

  final AuthApi api;
  final ValueChanged<String> onMessage;

  @override
  State<BookingTransactionNotificationSettings> createState() =>
      _BookingTransactionNotificationSettingsState();
}

class _BookingTransactionNotificationSettingsState
    extends State<BookingTransactionNotificationSettings> {
  bool _enabled = false;
  bool _loading = true;
  String _sound = BookingPushNotifications.defaultSound;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await AppSessionService.instance.load();
      final preferences = await BookingPushNotifications.instance
          .preferencesFor(session.accountEmail);
      if (!mounted) return;
      setState(() {
        _enabled = preferences.enabled;
        _sound = preferences.sound;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onMessage('Could not load booking alerts: $error');
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final session = await AppSessionService.instance.load();
      if (value) {
        final enabled = await BookingPushNotifications.instance.enable(
          session,
          widget.api,
          _sound,
        );
        if (!enabled) {
          widget.onMessage('Allow notifications to receive booking updates.');
          return;
        }
      } else {
        await BookingPushNotifications.instance.disable(session, widget.api);
      }
      if (!mounted) return;
      setState(() => _enabled = value);
      widget.onMessage(
        value
            ? 'Booking push notifications are enabled.'
            : 'Booking push notifications are turned off.',
      );
    } on Exception catch (error) {
      if (mounted) widget.onMessage('Could not update booking alerts: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setSound(String? sound) async {
    if (sound == null || sound == _sound || _loading) return;
    setState(() => _loading = true);
    try {
      final session = await AppSessionService.instance.load();
      await BookingPushNotifications.instance.setSound(
        session,
        widget.api,
        sound,
      );
      if (!mounted) return;
      setState(() => _sound = sound);
      widget.onMessage('Booking alert sound updated.');
    } on Exception catch (error) {
      if (mounted) widget.onMessage('Could not update alert sound: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(14),
    child: Column(
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('booking-push-notifications-switch'),
          value: _enabled,
          onChanged: _loading ? null : _setEnabled,
          secondary: const Icon(Icons.notifications_outlined),
          title: const AppText('Booking notifications', localize: true),
          subtitle: const AppText(
            'Push alerts for booking requests, approvals, declines, and payments.',
            localize: true,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const AppText('Booking alert sound', localize: true),
          trailing: DropdownButton<String>(
            key: const ValueKey('booking-notification-sound'),
            value: _sound,
            onChanged: _loading ? null : _setSound,
            items: const [
              DropdownMenuItem(
                value: 'tinker_bell',
                child: AppText('SpotGo bell', localize: true),
              ),
              DropdownMenuItem(
                value: 'system',
                child: AppText('Device default', localize: true),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
