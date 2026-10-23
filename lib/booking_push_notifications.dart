import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'booking_notifications.dart';

class BookingPushNotifications {
  BookingPushNotifications._();

  static final BookingPushNotifications instance = BookingPushNotifications._();

  static const defaultSound = 'tinker_bell';
  static const availableSounds = {'system', 'tinker_bell'};
  static const _enabledPrefix = 'booking_push_enabled_';
  static const _soundPrefix = 'booking_push_sound_';

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  AuthApi? _api;
  AppSession? _session;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize(AppSession session) async {
    if (!isSupported || !session.isAuthenticated) return;
    _api = AuthApi();
    _session = session;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!_isEnabled(preferences, session.accountEmail)) return;
      await _registerCurrentDevice(session, _api!);
      _listenForTokenRefresh();
      _listenForForegroundMessages();
    } on Exception catch (error) {
      debugPrint('Could not synchronize booking push notifications: $error');
    }
  }

  Future<bool> enable(AppSession session, AuthApi api, String sound) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Booking push notifications require Android or iOS.',
      );
    }
    if (!availableSounds.contains(sound)) {
      throw ArgumentError.value(
        sound,
        'sound',
        'Unsupported notification sound.',
      );
    }

    _api = api;
    _session = session;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await _saveSound(session.accountEmail, sound);
    await BookingNotifications.instance.setSoundPreference(
      session.accountEmail ?? 'account',
      sound,
    );
    await _registerCurrentDevice(session, api);
    await _setEnabled(session.accountEmail, true);
    _listenForTokenRefresh();
    _listenForForegroundMessages();
    return true;
  }

  Future<void> setSound(AppSession session, AuthApi api, String sound) async {
    if (!availableSounds.contains(sound)) {
      throw ArgumentError.value(
        sound,
        'sound',
        'Unsupported notification sound.',
      );
    }
    _api = api;
    _session = session;
    await _saveSound(session.accountEmail, sound);
    await BookingNotifications.instance.setSoundPreference(
      session.accountEmail ?? 'account',
      sound,
    );
    final preferences = await SharedPreferences.getInstance();
    if (_isEnabled(preferences, session.accountEmail)) {
      await _registerCurrentDevice(session, api);
    }
  }

  Future<void> disable(AppSession session, AuthApi api) async {
    final token = session.apiToken;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty && fcmToken != null) {
      await api.unregisterNotificationDevice(token: token, fcmToken: fcmToken);
    }
    await _setEnabled(session.accountEmail, false);
  }

  Future<void> unregister(AppSession session) async {
    if (!isSupported) return;
    try {
      final token = session.apiToken;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty && fcmToken != null) {
        await AuthApi().unregisterNotificationDevice(
          token: token,
          fcmToken: fcmToken,
        );
      }
    } on Exception catch (error) {
      debugPrint(
        'Could not unregister this device from booking alerts: $error',
      );
    } finally {
      await _setEnabled(session.accountEmail, false);
    }
  }

  Future<({bool enabled, String sound})> preferencesFor(
    String? accountEmail,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    return (
      enabled: _isEnabled(preferences, accountEmail),
      sound: preferences.getString(_soundKey(accountEmail)) ?? defaultSound,
    );
  }

  Future<void> _registerCurrentDevice(AppSession session, AuthApi api) async {
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to enable booking notifications.');
    }
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null || fcmToken.trim().isEmpty) {
      throw StateError('Firebase did not provide a notification device token.');
    }
    final preferences = await SharedPreferences.getInstance();
    final sound =
        preferences.getString(_soundKey(session.accountEmail)) ?? defaultSound;
    await api.registerNotificationDevice(
      token: token,
      fcmToken: fcmToken,
      sound: sound,
    );
  }

  void _listenForTokenRefresh() {
    if (_tokenSubscription != null) return;
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        final session = _session;
        final api = _api;
        if (session == null || api == null || token.isEmpty) return;
        try {
          final preferences = await SharedPreferences.getInstance();
          if (!_isEnabled(preferences, session.accountEmail)) return;
          final accessToken = session.apiToken;
          if (accessToken == null || accessToken.isEmpty) return;
          final sound =
              preferences.getString(_soundKey(session.accountEmail)) ??
              defaultSound;
          await api.registerNotificationDevice(
            token: accessToken,
            fcmToken: token,
            sound: sound,
          );
        } on Exception catch (error) {
          debugPrint('Could not update the booking notification token: $error');
        }
      },
      onError: (Object error) =>
          debugPrint('Booking notification token refresh failed: $error'),
    );
  }

  void _listenForForegroundMessages() {
    if (_messageSubscription != null) return;
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      (message) async {
        try {
          await BookingNotifications.instance.showTransactionNotification(
            message,
          );
        } on Exception catch (error) {
          debugPrint('Could not display a booking notification: $error');
        }
      },
      onError: (Object error) =>
          debugPrint('Could not receive a booking notification: $error'),
    );
  }

  bool _isEnabled(SharedPreferences preferences, String? accountEmail) =>
      preferences.getBool(_enabledKey(accountEmail)) ?? false;

  Future<void> _setEnabled(String? accountEmail, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey(accountEmail), enabled);
  }

  Future<void> _saveSound(String? accountEmail, String sound) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_soundKey(accountEmail), sound);
  }

  String _enabledKey(String? email) =>
      '$_enabledPrefix${Uri.encodeComponent(email ?? 'anonymous')}';

  String _soundKey(String? email) =>
      '$_soundPrefix${Uri.encodeComponent(email ?? 'anonymous')}';
}
