import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  AppSession._(SharedPreferences preferences)
    : _preferences = preferences,
      _storage = _AppSessionStorage(preferences),
      _apiToken = null;

  static const _authenticatedKey = 'session_authenticated';
  static const _lastBookingTypeKey = 'session_last_booking_type';
  static const _apiTokenKey = 'session_api_token';
  static const _roleKey = 'session_role';
  static const _accountEmailKey = 'session_account_email';
  static const _rememberedLoginEmailKey = 'remembered_login_email';
  static const _guestIdKey = 'session_guest_id';
  static const _merchantProfileEmailKey = 'merchant_profile_email';
  static const _bookingStatusBannerDismissedPrefix =
      'booking_status_banner_dismissed_';
  static const _bookingDeadlineReminderSnoozedUntilPrefix =
      'booking_deadline_reminder_snoozed_until_v2_';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final SharedPreferences _preferences;
  final _AppSessionStorage _storage;
  String? _apiToken;

  bool get isAuthenticated => _storage.isAuthenticated;

  bool get matchNotificationsEnabled => _storage.matchNotificationsEnabled;

  String? get lastBookingType => _storage.lastBookingType;

  String? get apiToken => _apiToken;
  String? get role => _storage.role;
  String? get accountEmail => _storage.accountEmail;
  String? get rememberedLoginEmail => _storage.rememberedLoginEmail;

  Future<String> guestId() async => _storage.guestId();

  static Future<AppSession> load() async {
    final preferences = await SharedPreferences.getInstance();
    final session = AppSession._(preferences);
    session._apiToken =
        await _secureStorage.read(key: _apiTokenKey) ??
        preferences.getString(_apiTokenKey);
    if (session._apiToken != null && session._apiToken!.isNotEmpty) {
      await preferences.remove(_apiTokenKey);
    }
    return session;
  }

  Future<void> markAuthenticated() async => _storage.markAuthenticated();

  Future<void> setApiToken(String token) async {
    _apiToken = token;
    await _secureStorage.write(key: _apiTokenKey, value: token);
    await _preferences.remove(_apiTokenKey);
  }

  Future<void> setRole(String role) async => _storage.setRole(role);

  Future<void> setAccountEmail(String email) async =>
      _storage.setAccountEmail(email);

  Future<void> rememberLoginEmail(String email) async =>
      _storage.rememberLoginEmail(email);

  Future<void> clearRememberedLoginEmail() async =>
      _storage.clearRememberedLoginEmail();

  bool merchantProfileCompletedFor(String email) =>
      _storage.merchantProfileCompletedFor(email);

  Future<void> markMerchantProfileCompleted(String email) async =>
      _storage.markMerchantProfileCompleted(email);

  Future<void> setLastBookingType(String type) async =>
      _storage.setLastBookingType(type);

  Future<void> clearLastBookingType() async => _storage.clearLastBookingType();

  Future<void> setMatchNotificationsEnabled(bool enabled) async =>
      _storage.setMatchNotificationsEnabled(enabled);

  bool bookingStatusBannerDismissed(String bookingKey) =>
      _storage.bookingStatusBannerDismissed(bookingKey);

  Future<void> dismissBookingStatusBanner(String bookingKey) async =>
      _storage.dismissBookingStatusBanner(bookingKey);

  bool bookingDeadlineReminderDismissed({DateTime? now}) =>
      _storage.bookingDeadlineReminderDismissed(now: now);

  Future<void> dismissBookingDeadlineReminder({DateTime? now}) async =>
      _storage.dismissBookingDeadlineReminder(now: now);

  Future<void> clear() async {
    _apiToken = null;
    await _storage.clear();
    await _secureStorage.delete(key: _apiTokenKey);
  }
}

class _AppSessionStorage {
  const _AppSessionStorage(this._preferences);

  final SharedPreferences _preferences;

  bool get isAuthenticated =>
      _preferences.getBool(AppSession._authenticatedKey) ?? false;

  bool get matchNotificationsEnabled =>
      _preferences.getBool(_matchNotificationsEnabledKey) ?? false;

  String? get lastBookingType =>
      _preferences.getString(AppSession._lastBookingTypeKey);

  String? get role => _preferences.getString(AppSession._roleKey);
  String? get accountEmail =>
      _preferences.getString(AppSession._accountEmailKey);
  String? get rememberedLoginEmail =>
      _preferences.getString(AppSession._rememberedLoginEmailKey);

  Future<String> guestId() async {
    final existing = _preferences.getString(AppSession._guestIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final generated = List.generate(
      10,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    await _preferences.setString(AppSession._guestIdKey, generated);
    return generated;
  }

  Future<void> markAuthenticated() async {
    await _preferences.setBool(AppSession._authenticatedKey, true);
  }

  Future<void> setRole(String role) async {
    await _preferences.setString(AppSession._roleKey, role);
  }

  Future<void> setAccountEmail(String email) async {
    await _preferences.setString(
      AppSession._accountEmailKey,
      email.toLowerCase(),
    );
  }

  Future<void> rememberLoginEmail(String email) async {
    await _preferences.setString(
      AppSession._rememberedLoginEmailKey,
      email.trim().toLowerCase(),
    );
  }

  Future<void> clearRememberedLoginEmail() async {
    await _preferences.remove(AppSession._rememberedLoginEmailKey);
  }

  bool merchantProfileCompletedFor(String email) =>
      _preferences.getString(AppSession._merchantProfileEmailKey) ==
      email.toLowerCase();

  Future<void> markMerchantProfileCompleted(String email) async {
    await _preferences.setString(
      AppSession._merchantProfileEmailKey,
      email.toLowerCase(),
    );
  }

  Future<void> setLastBookingType(String type) async {
    await _preferences.setString(AppSession._lastBookingTypeKey, type);
  }

  Future<void> clearLastBookingType() async {
    await _preferences.remove(AppSession._lastBookingTypeKey);
  }

  Future<void> setMatchNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(_matchNotificationsEnabledKey, enabled);
  }

  bool bookingStatusBannerDismissed(String bookingKey) =>
      _preferences.getBool(_bookingStatusBannerDismissedKey(bookingKey)) ??
      false;

  Future<void> dismissBookingStatusBanner(String bookingKey) async {
    await _preferences.setBool(
      _bookingStatusBannerDismissedKey(bookingKey),
      true,
    );
  }

  bool bookingDeadlineReminderDismissed({DateTime? now}) {
    final snoozedUntilMillis = int.tryParse(
      _preferences.getString(_bookingDeadlineReminderSnoozedUntilKey) ?? '',
    );
    if (snoozedUntilMillis == null) return false;
    final snoozedUntil = DateTime.fromMillisecondsSinceEpoch(
      snoozedUntilMillis,
    );
    return (now ?? DateTime.now()).isBefore(snoozedUntil);
  }

  Future<void> dismissBookingDeadlineReminder({DateTime? now}) async {
    final snoozedUntil = (now ?? DateTime.now()).add(const Duration(hours: 24));
    final saved = await _preferences.setString(
      _bookingDeadlineReminderSnoozedUntilKey,
      '${snoozedUntil.millisecondsSinceEpoch}',
    );
    if (!saved) {
      throw Exception('The reminder preference could not be saved.');
    }
  }

  String _bookingStatusBannerDismissedKey(String bookingKey) {
    final account = Uri.encodeComponent(accountEmail ?? 'anonymous');
    return '${AppSession._bookingStatusBannerDismissedPrefix}${account}_$bookingKey';
  }

  String get _bookingDeadlineReminderSnoozedUntilKey {
    final account = Uri.encodeComponent(accountEmail ?? 'anonymous');
    return '${AppSession._bookingDeadlineReminderSnoozedUntilPrefix}$account';
  }

  String get _matchNotificationsEnabledKey =>
      'match_notifications_enabled_${Uri.encodeComponent(accountEmail ?? 'anonymous')}';

  Future<void> clear() async {
    final keys = _preferences.getKeys().toList();
    for (final key in keys) {
      final shouldClear =
          key == AppSession._authenticatedKey ||
          key == AppSession._lastBookingTypeKey ||
          key == AppSession._roleKey ||
          key == AppSession._accountEmailKey ||
          key == AppSession._merchantProfileEmailKey ||
          key == AppSession._apiTokenKey ||
          key.startsWith(AppSession._bookingStatusBannerDismissedPrefix) ||
          key.startsWith(
            AppSession._bookingDeadlineReminderSnoozedUntilPrefix,
          ) ||
          key.startsWith('match_notifications_enabled_');

      if (shouldClear) {
        await _preferences.remove(key);
      }
    }
  }
}
