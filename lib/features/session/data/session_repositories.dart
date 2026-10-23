import 'package:myapp/app_session.dart';

abstract interface class AuthSessionRepository {
  Future<AppSession> load();
  Future<void> markAuthenticated();
  Future<void> setApiToken(String token);
  Future<void> setRole(String role);
  Future<void> setAccountEmail(String email);
  Future<void> rememberLoginEmail(String email);
  Future<void> clearRememberedLoginEmail();
  Future<void> setMatchNotificationsEnabled(bool enabled);
  Future<void> clear();
  Future<String> guestId();
}

class AppAuthSessionRepository implements AuthSessionRepository {
  AppAuthSessionRepository({Future<AppSession> Function()? loadSession})
    : _loadSession = loadSession ?? AppSession.load;

  final Future<AppSession> Function() _loadSession;

  Future<AppSession> _load() => _loadSession();

  @override
  Future<AppSession> load() => _load();

  @override
  Future<String> guestId() async => (await _load()).guestId();

  @override
  Future<void> markAuthenticated() async => (await _load()).markAuthenticated();

  @override
  Future<void> setApiToken(String token) async =>
      (await _load()).setApiToken(token);

  @override
  Future<void> setRole(String role) async => (await _load()).setRole(role);

  @override
  Future<void> setAccountEmail(String email) async =>
      (await _load()).setAccountEmail(email);

  @override
  Future<void> rememberLoginEmail(String email) async =>
      (await _load()).rememberLoginEmail(email);

  @override
  Future<void> clearRememberedLoginEmail() async =>
      (await _load()).clearRememberedLoginEmail();

  @override
  Future<void> setMatchNotificationsEnabled(bool enabled) async =>
      (await _load()).setMatchNotificationsEnabled(enabled);

  @override
  Future<void> clear() async => (await _load()).clear();
}

abstract interface class MerchantProfileSessionRepository {
  Future<void> markMerchantProfileCompleted(String email);
  Future<bool> merchantProfileCompletedFor(String email);
}

class AppMerchantProfileSessionRepository
    implements MerchantProfileSessionRepository {
  AppMerchantProfileSessionRepository({
    Future<AppSession> Function()? loadSession,
  }) : _loadSession = loadSession ?? AppSession.load;

  final Future<AppSession> Function() _loadSession;

  Future<AppSession> _load() => _loadSession();

  @override
  Future<bool> merchantProfileCompletedFor(String email) async =>
      (await _load()).merchantProfileCompletedFor(email);

  @override
  Future<void> markMerchantProfileCompleted(String email) async =>
      (await _load()).markMerchantProfileCompleted(email);
}
