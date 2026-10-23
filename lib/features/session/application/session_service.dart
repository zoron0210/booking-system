import 'package:myapp/app_session.dart';

class AppSessionService {
  const AppSessionService._();

  static const instance = AppSessionService._();

  Future<AppSession> load() => AppSession.load();

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
    required String role,
  }) async {
    final session = await load();
    await session.setAccountEmail(email);
    await session.setApiToken(token);
    await session.setRole(role);
    await session.markAuthenticated();
  }
}
