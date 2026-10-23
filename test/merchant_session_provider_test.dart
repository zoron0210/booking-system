import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/merchant_management/data/merchant_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'session_role': 'merchant',
      'session_account_email': 'merchant@example.com',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-test-token',
    });
  });

  test('merchant provider loads session details', () async {
    final session = await AppMerchantSessionProvider().load();

    expect(session.apiToken, 'merchant-test-token');
    expect(session.accountEmail, 'merchant@example.com');
    expect(session.matchNotificationsEnabled, isFalse);
  });

  test('merchant provider persists portal and profile settings', () async {
    final provider = AppMerchantSessionProvider();
    final session = await provider.load();

    await session.setApiToken('customer-mode-token');
    await session.setRole('customer');
    await session.setMatchNotificationsEnabled(true);
    await session.markMerchantProfileCompleted('merchant@example.com');

    final updated = await provider.load();
    expect(updated.apiToken, 'customer-mode-token');
    expect(updated.accountEmail, 'merchant@example.com');
    expect(updated.matchNotificationsEnabled, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('session_role'), 'customer');
    expect(
      preferences.getString('merchant_profile_email'),
      'merchant@example.com',
    );
  });
}
