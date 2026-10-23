import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'match notification preference is controlled separately per account',
    () async {
      final session = await AppSession.load();

      await session.setAccountEmail('first@example.com');
      expect(session.matchNotificationsEnabled, isFalse);
      await session.setMatchNotificationsEnabled(true);
      expect(session.matchNotificationsEnabled, isTrue);

      await session.setAccountEmail('second@example.com');
      expect(session.matchNotificationsEnabled, isFalse);

      await session.setAccountEmail('first@example.com');
      expect(session.matchNotificationsEnabled, isTrue);
    },
  );

  test('match notification preference can be turned off', () async {
    final session = await AppSession.load();
    await session.setAccountEmail('player@example.com');
    await session.setMatchNotificationsEnabled(true);

    await session.setMatchNotificationsEnabled(false);

    expect(session.matchNotificationsEnabled, isFalse);
  });

  test(
    'booking deadline reminder snooze expires after 24 hours per account',
    () async {
      final session = await AppSession.load();
      final dismissedAt = DateTime(2026, 10, 16, 16);
      await session.setAccountEmail('first@example.com');
      await session.dismissBookingDeadlineReminder(now: dismissedAt);

      expect(
        session.bookingDeadlineReminderDismissed(
          now: dismissedAt.add(const Duration(hours: 23, minutes: 59)),
        ),
        isTrue,
      );
      expect(
        session.bookingDeadlineReminderDismissed(
          now: dismissedAt.add(const Duration(hours: 24)),
        ),
        isFalse,
      );

      await session.setAccountEmail('second@example.com');
      expect(
        session.bookingDeadlineReminderDismissed(
          now: dismissedAt.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    },
  );

  test(
    'api token is kept in secure storage and surfaced on the session',
    () async {
      final session = await AppSession.load();

      await session.setApiToken('secure-session-token');

      final reloaded = await AppSession.load();
      expect(reloaded.apiToken, 'secure-session-token');
    },
  );

  test(
    'remember me stores only the login email and keeps it after logout',
    () async {
      final session = await AppSession.load();
      await session.rememberLoginEmail(' Player@Example.com ');
      await session.setAccountEmail('player@example.com');
      await session.setApiToken('secure-session-token');
      await session.markAuthenticated();

      await session.clear();

      final reloaded = await AppSession.load();
      expect(reloaded.rememberedLoginEmail, 'player@example.com');
      expect(reloaded.isAuthenticated, isFalse);
      expect(reloaded.apiToken, isNull);
    },
  );

  test('remember me can forget the saved login email', () async {
    final session = await AppSession.load();
    await session.rememberLoginEmail('player@example.com');

    await session.clearRememberedLoginEmail();

    expect(session.rememberedLoginEmail, isNull);
  });

  test(
    'guest ID is generated once and persists across session loads',
    () async {
      final session = await AppSession.load();

      final guestId = await session.guestId();
      final reloadedGuestId = await (await AppSession.load()).guestId();

      expect(guestId, matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));
      expect(reloadedGuestId, guestId);
    },
  );

  test('last booking type can be cleared when logging out', () async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await session.clearLastBookingType();

    expect((await AppSession.load()).lastBookingType, isNull);
  });
}
