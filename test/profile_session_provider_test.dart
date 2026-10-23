import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/profile/data/profile_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'session_role': 'customer',
      'session_account_email': 'player@example.com',
      'match_notifications_enabled_player%40example.com': true,
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'profile-test-token',
    });
  });

  test('app provider exposes loaded profile session state', () async {
    final provider = AppProfileSessionProvider();
    final session = await provider.load();

    expect(session.apiToken, 'profile-test-token');
    expect(session.role, 'customer');
    expect(session.accountEmail, 'player@example.com');
    expect(session.matchNotificationsEnabled, isTrue);
  });

  test('app provider persists profile session updates', () async {
    final provider = AppProfileSessionProvider();
    final session = await provider.load();

    await session.setApiToken('updated-token');
    await session.setRole('merchant');
    await session.setMatchNotificationsEnabled(false);

    final updatedSession = await provider.load();
    expect(updatedSession.apiToken, 'updated-token');
    expect(updatedSession.role, 'merchant');
    expect(updatedSession.matchNotificationsEnabled, isFalse);
    expect(await updatedSession.guestId(), isNotEmpty);

    await updatedSession.clear();
    expect((await provider.load()).apiToken, isNull);
  });
}
