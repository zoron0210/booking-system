import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/features/notifications/data/booking_notifications.dart';
import 'package:myapp/core/app_session.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

class BookingPushNotifications {
  BookingPushNotifications._();

  static final BookingPushNotifications instance = BookingPushNotifications._();

  static const defaultSound = 'tinker_bell';
  static const availableSounds = {'system', 'tinker_bell'};
  static const _enabledPrefix = 'booking_push_enabled_';
  static const _matchDiscoveryEnabledPrefix = 'match_discovery_push_enabled_';
  static const _soundPrefix = 'booking_push_sound_';

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  AuthApi? _api;
  AppSession? _session;
  String? _matchDiscoveryApiToken;
  String? _matchDiscoveryAccountEmail;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize(AppSession session) async {
    if (!isSupported || !session.isAuthenticated) return;
    _api = AuthApi();
    _session = session;
    _listenForOpenedMessages();
    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _publishNotificationTap(initialMessage);
      }
      final preferences = await SharedPreferences.getInstance();
      final bookingEnabled = _isEnabled(preferences, session.accountEmail);
      final matchDiscoveryEnabled = _isMatchDiscoveryEnabled(
        preferences,
        session.accountEmail,
      );
      _matchDiscoveryApiToken = matchDiscoveryEnabled ? session.apiToken : null;
      _matchDiscoveryAccountEmail = matchDiscoveryEnabled
          ? session.accountEmail
          : null;
      if (!bookingEnabled && !matchDiscoveryEnabled) return;
      if (bookingEnabled) {
        try {
          await _registerCurrentDevice(session, _api!);
        } on Exception catch (error) {
          debugPrint(
            'Could not synchronize booking push notifications: $error',
          );
        }
      }
      if (matchDiscoveryEnabled) {
        try {
          await _registerMatchDiscoveryDevice(
            apiToken: session.apiToken,
            accountEmail: session.accountEmail,
            api: _api!,
          );
        } on Exception catch (error) {
          debugPrint('Could not synchronize public match alerts: $error');
        }
      }
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

  Future<bool> enablePublicMatchAlerts({
    required String? apiToken,
    required String? accountEmail,
    required AuthApi api,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Public match alerts require Android or iOS.');
    }

    _api = api;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await _registerMatchDiscoveryDevice(
      apiToken: apiToken,
      accountEmail: accountEmail,
      api: api,
    );
    await _setMatchDiscoveryEnabled(accountEmail, true);
    _matchDiscoveryApiToken = apiToken;
    _matchDiscoveryAccountEmail = accountEmail;
    _listenForTokenRefresh();
    _listenForForegroundMessages();
    return true;
  }

  Future<void> disablePublicMatchAlerts({
    required String? apiToken,
    required String? accountEmail,
    required AuthApi api,
  }) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (apiToken != null && apiToken.isNotEmpty && fcmToken != null) {
      await api.unregisterMatchDiscoveryDevice(
        token: apiToken,
        fcmToken: fcmToken,
      );
    }
    await _setMatchDiscoveryEnabled(accountEmail, false);
    _matchDiscoveryApiToken = null;
    _matchDiscoveryAccountEmail = null;
  }

  Future<void> unregister(AppSession session) async {
    if (!isSupported) return;
    try {
      final token = session.apiToken;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty && fcmToken != null) {
        final api = AuthApi();
        try {
          await api.unregisterNotificationDevice(
            token: token,
            fcmToken: fcmToken,
          );
        } on Exception catch (error) {
          debugPrint(
            'Could not unregister this device from booking alerts: $error',
          );
        }
        try {
          await api.unregisterMatchDiscoveryDevice(
            token: token,
            fcmToken: fcmToken,
          );
        } on Exception catch (error) {
          debugPrint(
            'Could not unregister this device from public match alerts: $error',
          );
        }
      }
    } on Exception catch (error) {
      debugPrint('Could not load this device token for unregistration: $error');
    } finally {
      await _setEnabled(session.accountEmail, false);
      await _setMatchDiscoveryEnabled(session.accountEmail, false);
      _matchDiscoveryApiToken = null;
      _matchDiscoveryAccountEmail = null;
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

  Future<bool> publicMatchAlertsEnabledFor(String? accountEmail) async {
    final preferences = await SharedPreferences.getInstance();
    return _isMatchDiscoveryEnabled(preferences, accountEmail);
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

  Future<void> _registerMatchDiscoveryDevice({
    required String? apiToken,
    required String? accountEmail,
    required AuthApi api,
  }) async {
    if (apiToken == null || apiToken.isEmpty) {
      throw StateError('Sign in again to enable public match alerts.');
    }
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null || fcmToken.trim().isEmpty) {
      throw StateError('Firebase did not provide a notification device token.');
    }
    final preferences = await SharedPreferences.getInstance();
    final sound =
        preferences.getString(_soundKey(accountEmail)) ?? defaultSound;
    await api.registerMatchDiscoveryDevice(
      token: apiToken,
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
        if (api == null || token.isEmpty) return;
        try {
          final preferences = await SharedPreferences.getInstance();
          final accessToken = session?.apiToken;
          final matchAccessToken = _matchDiscoveryApiToken ?? accessToken;
          final accountEmail =
              _matchDiscoveryAccountEmail ?? session?.accountEmail;
          final sound =
              preferences.getString(_soundKey(accountEmail)) ?? defaultSound;
          if (session != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              _isEnabled(preferences, session.accountEmail)) {
            try {
              await api.registerNotificationDevice(
                token: accessToken,
                fcmToken: token,
                sound: sound,
              );
            } on Exception catch (error) {
              debugPrint(
                'Could not update the booking notification token: $error',
              );
            }
          }
          if (matchAccessToken != null &&
              matchAccessToken.isNotEmpty &&
              _isMatchDiscoveryEnabled(preferences, accountEmail)) {
            _matchDiscoveryApiToken = matchAccessToken;
            try {
              await api.registerMatchDiscoveryDevice(
                token: matchAccessToken,
                fcmToken: token,
                sound: sound,
              );
            } on Exception catch (error) {
              debugPrint(
                'Could not update the public match alert token: $error',
              );
            }
          }
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

  void _listenForOpenedMessages() {
    if (_openedMessageSubscription != null) return;
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _publishNotificationTap,
      onError: (Object error) =>
          debugPrint('Could not open a booking notification: $error'),
    );
  }

  void _publishNotificationTap(RemoteMessage message) {
    BookingNotifications.instance.publishNotificationTapPayload(
      jsonEncode(message.data),
    );
  }

  bool _isEnabled(SharedPreferences preferences, String? accountEmail) =>
      preferences.getBool(_enabledKey(accountEmail)) ?? false;

  bool _isMatchDiscoveryEnabled(
    SharedPreferences preferences,
    String? accountEmail,
  ) => preferences.getBool(_matchDiscoveryEnabledKey(accountEmail)) ?? false;

  Future<void> _setEnabled(String? accountEmail, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey(accountEmail), enabled);
  }

  Future<void> _setMatchDiscoveryEnabled(
    String? accountEmail,
    bool enabled,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_matchDiscoveryEnabledKey(accountEmail), enabled);
  }

  Future<void> _saveSound(String? accountEmail, String sound) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_soundKey(accountEmail), sound);
  }

  String _enabledKey(String? email) =>
      '$_enabledPrefix${Uri.encodeComponent(email ?? 'anonymous')}';

  String _matchDiscoveryEnabledKey(String? email) =>
      '$_matchDiscoveryEnabledPrefix${Uri.encodeComponent(email ?? 'anonymous')}';

  String _soundKey(String? email) =>
      '$_soundPrefix${Uri.encodeComponent(email ?? 'anonymous')}';
}
