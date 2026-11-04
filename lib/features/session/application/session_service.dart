import 'package:flutter/foundation.dart';
import 'package:myapp/core/app_session.dart';

class AppSessionService extends ChangeNotifier {
  AppSessionService._();

  static final instance = AppSessionService._();

  AppSession? _currentSession;

  AppSession? get currentSession => _currentSession;

  Future<AppSession> load() async {
    final loadedSession = await AppSession.load();
    final currentSession = _currentSession;
    if (currentSession != null &&
        currentSession.sharesStorageWith(loadedSession)) {
      currentSession.refreshTokenFrom(loadedSession);
      return currentSession;
    }

    currentSession?.removeListener(_onSessionChanged);
    _currentSession = loadedSession..addListener(_onSessionChanged);
    notifyListeners();
    return loadedSession;
  }

  void _onSessionChanged() => notifyListeners();

  Future<bool> hasAuthenticatedApiSession() async {
    final session = await load();
    return session.isAuthenticated && session.apiToken?.isNotEmpty == true;
  }

  Future<void> clearCurrentSession() async {
    final session = await load();
    await session.clear();
  }

  Future<void> saveAuthenticatedSession({
    required String email,
    required String token,
    required String refreshToken,
    required String role,
  }) async {
    final session = await load();
    await session.setAccountEmail(email);
    await session.setTokens(apiToken: token, refreshToken: refreshToken);
    await session.setRole(role);
    await session.markAuthenticated();
  }

  Future<void> updateSessionTokens({
    required String token,
    required String refreshToken,
  }) async {
    final session = await load();
    await session.setTokens(apiToken: token, refreshToken: refreshToken);
  }
}
