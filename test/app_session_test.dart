import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/app_session.dart';
import 'package:myapp/features/session/application/session_service.dart';
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

  test('access and refresh tokens are kept in secure storage', () async {
    final session = await AppSession.load();

    await session.setTokens(
      apiToken: 'secure-session-token',
      refreshToken: 'secure-refresh-token',
    );

    final reloaded = await AppSession.load();
    expect(reloaded.apiToken, 'secure-session-token');
    expect(reloaded.refreshToken, 'secure-refresh-token');
    expect(
      (await SharedPreferences.getInstance()).getString(
        'session_refresh_token',
      ),
      isNull,
    );
  });

  test(
    'session changes notify the shared application session service',
    () async {
      final service = AppSessionService.instance;
      final session = await service.load();
      var notifications = 0;
      void listener() => notifications++;
      service.addListener(listener);

      await session.setApiToken('reactive-session-token');

      expect(service.currentSession, same(session));
      expect(notifications, greaterThan(0));
      service.removeListener(listener);
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
