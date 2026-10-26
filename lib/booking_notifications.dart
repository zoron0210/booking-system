import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingNotifications {
  BookingNotifications._();

  static final BookingNotifications instance = BookingNotifications._();

  static const _systemChannelId = 'booking_alerts_system';
  static const _bellChannelId = 'booking_alerts_tinker_bell';
  static const _scheduledIdsKeyPrefix = 'scheduled_match_reminders_';
  static const _soundKeyPrefix = 'booking_push_sound_';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Match notifications are supported on Android and iOS.',
      );
    }
    final initialization = _initialization ??= _initializePlugin();
    try {
      await initialization;
    } on Exception {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final location = timezone.getLocation(localTimezone.identifier);
    timezone.setLocalLocation(location);

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (initialized != true) {
      throw Exception('The notification service could not be initialized.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _systemChannelId,
          'Booking alerts',
          description: 'Booking transaction and match reminders.',
          importance: Importance.max,
          playSound: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _bellChannelId,
          'Booking alerts - SpotGo bell',
          description: 'Booking updates with the SpotGo bell sound.',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('tinker_bell'),
        ),
      );
    }
  }

  Future<void> prepareTransactionAlerts() => _initialize();

  Future<void> setSoundPreference(String accountKey, String sound) async {
    if (!['system', 'tinker_bell'].contains(sound)) {
      throw ArgumentError.value(sound, 'sound', 'Unsupported notification sound.');
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '$_soundKeyPrefix${Uri.encodeComponent(accountKey)}',
      sound,
    );
    if (!saved) throw Exception('The notification sound preference could not be saved.');
  }

  Future<void> showTransactionNotification(RemoteMessage message) async {
    if (!isSupported) return;
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null || body == null) return;
    await _initialize();
    final sound = message.data['sound']?.toString() ?? 'tinker_bell';
    await _plugin.show(
      id: _notificationId(
        'push:${message.data['bookingId'] ?? message.messageId ?? title}:'
        '${message.data['event'] ?? ''}',
      ),
      title: title,
      body: body,
      notificationDetails: _notificationDetails(sound),
      payload: 'booking:${message.data['bookingId'] ?? ''}',
    );
  }

  Future<bool> requestPermissions() async {
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.requestNotificationsPermission() ?? false;
      if (!notificationsAllowed) return false;
      return await android?.requestExactAlarmsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  Future<bool> notificationsAllowed() async {
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.areNotificationsEnabled() ?? false;
      if (!notificationsAllowed) return false;
      return await android?.canScheduleExactNotifications() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final permissions = await ios?.checkPermissions();
    return permissions?.isEnabled == true ||
        permissions?.isProvisionalEnabled == true;
  }

  Future<bool?> openSystemNotificationSettings() async {
    await _initialize();
    return _plugin.openAppNotificationSettings();
  }

  Future<void> disableForAccount(String accountKey) async {
    await _initialize();
    final preferences = await SharedPreferences.getInstance();
    final storageKey = _storageKey(accountKey);
    final scheduled = _readScheduledNotifications(
      preferences.getString(storageKey),
    );
    for (final notification in scheduled) {
      await _plugin.cancel(id: notification.id);
    }
    await preferences.remove(storageKey);
  }

  Future<void> synchronizeApprovedBookings({
    required String accountKey,
    required List<Map<String, dynamic>> bookings,
  }) async {
    await _initialize();
    final preferences = await SharedPreferences.getInstance();
    final previous = _readScheduledNotifications(
      preferences.getString(_storageKey(accountKey)),
    );
    final notifications = <_ScheduledBookingNotification>[];
    final now = DateTime.now();

    for (final booking in bookings) {
      if ('${booking['status'] ?? ''}'.toLowerCase() != 'approved') continue;
      final start = _bookingStart(booking);
      if (start == null) {
        throw FormatException(
          'An approved booking has an invalid date or start time.',
        );
      }
      final durationHours = _durationHours(booking['durationHours']);
      if (durationHours <= 0) {
        throw FormatException(
          'An approved booking has an invalid match duration.',
        );
      }

      final venue = '${booking['venueName'] ?? 'your venue'}';
      final bookingKey =
          '${booking['id'] ?? booking['venueId'] ?? venue}_${booking['date']}_${booking['startTime']}';
      final end = start.add(
        Duration(seconds: (durationHours * Duration.secondsPerHour).round()),
      );
      if (start.isAfter(now)) {
        notifications.add(
          _ScheduledBookingNotification(
            id: _notificationId('$accountKey:$bookingKey:start'),
            date: start,
            title: 'Your match is starting',
            body: 'Your booking at $venue starts now.',
          ),
        );
      }
      if (end.isAfter(now)) {
        notifications.add(
          _ScheduledBookingNotification(
            id: _notificationId('$accountKey:$bookingKey:end'),
            date: end,
            title: 'Your match has ended',
            body: 'Your booking at $venue has ended.',
          ),
        );
      }
    }

    final nextIds = notifications
        .map((notification) => notification.id)
        .toSet();
    for (final old in previous) {
      if (!nextIds.contains(old.id) && old.date.isAfter(now)) {
        await _plugin.cancel(id: old.id);
      }
    }

    final sound = preferences.getString(
          '$_soundKeyPrefix${Uri.encodeComponent(accountKey)}',
        ) ??
        'tinker_bell';
    final details = _notificationDetails(sound);
    final location = timezone.local;
    for (final notification in notifications) {
      final date = notification.date;
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: timezone.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          date.hour,
          date.minute,
          date.second,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'booking:${notification.id}',
      );
    }

    await preferences.setString(
      _storageKey(accountKey),
      jsonEncode(
        notifications
            .map(
              (notification) => {
                'id': notification.id,
                'date': notification.date.millisecondsSinceEpoch,
              },
            )
            .toList(),
      ),
    );
  }

  NotificationDetails _notificationDetails(String sound) {
    final usesBell = sound == 'tinker_bell';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        usesBell ? _bellChannelId : _systemChannelId,
        usesBell ? 'Booking alerts - SpotGo bell' : 'Booking alerts',
        channelDescription: 'Booking transaction and match reminders.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: usesBell ? 'tinker_bell.wav' : null,
      ),
    );
  }

  DateTime? _bookingStart(Map<String, dynamic> booking) {
    return parseBookingReminderStart(booking['date'], booking['startTime']);
  }

  double _durationHours(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  List<_ScheduledBookingNotification> _readScheduledNotifications(
    String? value,
  ) {
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Invalid saved match notification data.');
    }
    return decoded.map((entry) {
      if (entry is! Map || entry['id'] is! num || entry['date'] is! num) {
        throw const FormatException('Invalid saved match notification entry.');
      }
      return _ScheduledBookingNotification(
        id: (entry['id'] as num).toInt(),
        date: DateTime.fromMillisecondsSinceEpoch(
          (entry['date'] as num).toInt(),
        ),
        title: '',
        body: '',
      );
    }).toList();
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  String _storageKey(String accountKey) =>
      '$_scheduledIdsKeyPrefix${Uri.encodeComponent(accountKey)}';
}

class _ScheduledBookingNotification {
  const _ScheduledBookingNotification({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime date;
  final String title;
  final String body;
}

DateTime? parseBookingReminderStart(Object? dateValue, Object? timeValue) {
  final date = '${dateValue ?? ''}'.trim();
  final time = '${timeValue ?? ''}'.trim();
  final dateMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:$|T)',
  ).firstMatch(date);
  final timeMatch = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?:\.\d+)?$',
  ).firstMatch(time);
  if (dateMatch == null || timeMatch == null) return null;

  final year = int.parse(dateMatch.group(1)!);
  final month = int.parse(dateMatch.group(2)!);
  final day = int.parse(dateMatch.group(3)!);
  final hour = int.parse(timeMatch.group(1)!);
  final minute = int.parse(timeMatch.group(2)!);
  final second = int.parse(timeMatch.group(3) ?? '0');
  final start = DateTime(year, month, day, hour, minute, second);
  if (start.year != year || start.month != month || start.day != day) {
    return null;
  }
  return start;
}
