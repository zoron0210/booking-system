import 'package:myapp/app_session.dart';
import 'package:myapp/features/session/data/session_repositories.dart';

abstract interface class MerchantSession {
  String? get apiToken;
  String? get accountEmail;
  bool get matchNotificationsEnabled;

  Future<void> setApiToken(String token);
  Future<void> setRole(String role);
  Future<void> setMatchNotificationsEnabled(bool enabled);
  Future<void> markMerchantProfileCompleted(String email);
}

abstract interface class MerchantSessionProvider {
  Future<MerchantSession> load();
}

class AppMerchantSessionProvider implements MerchantSessionProvider {
  AppMerchantSessionProvider({Future<AppSession> Function()? loadSession})
    : _merchantProfileSessionRepository = AppMerchantProfileSessionRepository(
        loadSession: loadSession,
      ),
      _loadSession = loadSession ?? AppSession.load;

  final AppMerchantProfileSessionRepository _merchantProfileSessionRepository;
  final Future<AppSession> Function() _loadSession;

  @override
  Future<MerchantSession> load() async => _AppMerchantSession(
    await _loadSession(),
    _merchantProfileSessionRepository,
  );
}

class _AppMerchantSession implements MerchantSession {
  const _AppMerchantSession(
    this._session,
    this._merchantProfileSessionRepository,
  );

  final AppSession _session;
  final AppMerchantProfileSessionRepository _merchantProfileSessionRepository;

  @override
  String? get apiToken => _session.apiToken;

  @override
  String? get accountEmail => _session.accountEmail;

  @override
  bool get matchNotificationsEnabled => _session.matchNotificationsEnabled;

  @override
  Future<void> setApiToken(String token) => _session.setApiToken(token);

  @override
  Future<void> setRole(String role) => _session.setRole(role);

  @override
  Future<void> setMatchNotificationsEnabled(bool enabled) =>
      _session.setMatchNotificationsEnabled(enabled);

  @override
  Future<void> markMerchantProfileCompleted(String email) =>
      _merchantProfileSessionRepository.markMerchantProfileCompleted(email);
}
