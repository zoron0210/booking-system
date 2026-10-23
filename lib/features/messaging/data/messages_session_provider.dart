import 'package:myapp/app_session.dart';
import 'package:myapp/features/session/data/session_repositories.dart';

class MessagesSession {
  const MessagesSession({required this.apiToken, required this.role});

  final String? apiToken;
  final String? role;
}

abstract interface class MessagesSessionProvider {
  Future<MessagesSession> load();
}

class AppMessagesSessionProvider implements MessagesSessionProvider {
  AppMessagesSessionProvider({Future<AppSession> Function()? loadSession})
    : _authSessionRepository = AppAuthSessionRepository(
        loadSession: loadSession,
      );

  final AppAuthSessionRepository _authSessionRepository;

  @override
  Future<MessagesSession> load() async {
    final session = await _authSessionRepository.load();
    return MessagesSession(apiToken: session.apiToken, role: session.role);
  }
}
