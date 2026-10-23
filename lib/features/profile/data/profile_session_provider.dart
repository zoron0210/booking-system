import 'package:myapp/app_session.dart';
import 'package:myapp/features/session/data/session_repositories.dart';

abstract interface class ProfileSession {
  String? get apiToken;
  String? get role;
  String? get accountEmail;
  bool get matchNotificationsEnabled;

  Future<String> guestId();
  Future<void> setApiToken(String token);
  Future<void> setRole(String role);
  Future<void> setMatchNotificationsEnabled(bool enabled);
  Future<void> clear();
}

abstract interface class ProfileSessionProvider {
  Future<ProfileSession> load();
}

class AppProfileSessionProvider implements ProfileSessionProvider {
  AppProfileSessionProvider({Future<AppSession> Function()? loadSession})
    : _authSessionRepository = AppAuthSessionRepository(
        loadSession: loadSession,
      ),
      _loadSession = loadSession ?? AppSession.load;

  final AppAuthSessionRepository _authSessionRepository;
  final Future<AppSession> Function() _loadSession;

  @override
  Future<ProfileSession> load() async =>
      _AppProfileSession(await _loadSession(), _authSessionRepository);
}

class _AppProfileSession implements ProfileSession {
  const _AppProfileSession(this._session, this._authSessionRepository);

  final AppSession _session;
  final AppAuthSessionRepository _authSessionRepository;

  @override
  String? get apiToken => _session.apiToken;

  @override
  String? get role => _session.role;

  @override
  String? get accountEmail => _session.accountEmail;

  @override
  bool get matchNotificationsEnabled => _session.matchNotificationsEnabled;

  @override
  Future<String> guestId() => _authSessionRepository.guestId();

  @override
  Future<void> setApiToken(String token) =>
      _authSessionRepository.setApiToken(token);

  @override
  Future<void> setRole(String role) => _authSessionRepository.setRole(role);

  @override
  Future<void> setMatchNotificationsEnabled(bool enabled) =>
      _authSessionRepository.setMatchNotificationsEnabled(enabled);

  @override
  Future<void> clear() => _authSessionRepository.clear();
}
