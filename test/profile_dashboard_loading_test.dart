import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/profile/data/profile_session_provider.dart';
import 'package:myapp/features/profile/presentation/profile_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('waits for guest session and keeps section names scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sessionResult = Completer<ProfileSession>();
    final page = ProfileDashboardPage(
      sessionProvider: _TestProfileSessionProvider(() => sessionResult.future),
      api: AuthApi(client: MockClient((_) async => http.Response('{}', 404))),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile-initial-loading')),
      findsOneWidget,
    );
    expect(find.textContaining('Guest #'), findsNothing);
    expect(find.textContaining('No completed bookings'), findsNothing);

    sessionResult.complete(_TestProfileSession(guestIdValue: 'VISITOR1234'));
    await tester.pumpAndSettle();

    expect(find.text('Guest #VISITOR1234'), findsOneWidget);
    final sectionNavigation = find.byKey(
      const ValueKey('profile-section-navigation'),
    );
    expect(sectionNavigation, findsOneWidget);
    expect(tester.getSize(sectionNavigation).width, lessThanOrEqualTo(288));

    final historyTab = find.byKey(
      const ValueKey('profile-history-tab-court-match-history'),
    );
    await tester.ensureVisible(historyTab);
    await tester.pumpAndSettle();
    await tester.tap(historyTab);
    await tester.pumpAndSettle();

    final historySemantics = tester.widget<Semantics>(
      find.byKey(
        const ValueKey('profile-section-semantics-court-match-history'),
      ),
    );
    expect(historySemantics.properties.button, isTrue);
    expect(historySemantics.properties.selected, isTrue);
    expect(historySemantics.properties.label, 'Court match history');
    expect(find.text('Court match history'), findsOneWidget);
    expect(find.text('COURT MATCH HISTORY'), findsOneWidget);
  });

  testWidgets('keeps section labels for each supported business type', (
    tester,
  ) async {
    final variants = [
      (
        type: 'Sports',
        upcoming: 'Upcoming match',
        history: 'Court match history',
      ),
      (
        type: 'Fitness & Wellness',
        upcoming: 'Booking session',
        history: 'Fitness booking history',
      ),
      (
        type: 'Event',
        upcoming: 'Upcoming event',
        history: 'Event booking history',
      ),
    ];
    for (final variant in variants) {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDashboardPage(
            key: ValueKey(variant.type),
            businessType: variant.type,
            sessionProvider: _guestSessionProvider(),
            api: AuthApi(
              client: MockClient((_) async => http.Response('{}', 404)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(variant.upcoming), findsOneWidget);
      expect(find.text(variant.history), findsOneWidget);
    }
  });

  testWidgets('a newer profile load wins over a stale in-flight response', (
    tester,
  ) async {
    final staleProfileResponse = Completer<http.Response>();
    var profileRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          profileRequests++;
          if (profileRequests == 1) return staleProfileResponse.future;
          return _profileResponse('Current');
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDashboardPage(
          sessionProvider: _signedInSessionProvider(),
          api: api,
        ),
      ),
    );
    await tester.pump();
    expect(profileRequests, 1);
    expect(
      find.byKey(const ValueKey('profile-initial-loading')),
      findsOneWidget,
    );
    expect(find.textContaining('Guest #'), findsNothing);
    expect(find.text('No approved bookings yet.'), findsNothing);

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(find.text('Current Player'), findsOneWidget);

    staleProfileResponse.complete(_profileResponse('Stale'));
    await tester.pumpAndSettle();

    expect(find.text('Current Player'), findsOneWidget);
    expect(find.text('Stale Player'), findsNothing);
  });

  testWidgets('initial errors retry inline and refresh errors retain content', (
    tester,
  ) async {
    var bookingRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return _profileResponse('Alex');
        }
        if (request.url.path == '/api/bookings') {
          bookingRequests++;
          if (bookingRequests == 1 || bookingRequests == 3) {
            return http.Response(jsonEncode({'message': 'Unavailable'}), 503);
          }
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDashboardPage(
          sessionProvider: _signedInSessionProvider(),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-initial-error')), findsOneWidget);
    expect(find.text('Your profile could not be loaded'), findsOneWidget);
    expect(find.text('Alex Player'), findsNothing);
    expect(find.textContaining('Guest #'), findsNothing);
    expect(find.text('No approved bookings yet.'), findsNothing);
    expect(find.textContaining('No completed bookings'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-load-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Alex Player'), findsOneWidget);
    expect(find.text('No approved bookings yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-initial-error')), findsNothing);

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;

    expect(find.text('Alex Player'), findsOneWidget);
    expect(find.text('No approved bookings yet.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(bookingRequests, 3);
  });
}

class _TestProfileSessionProvider implements ProfileSessionProvider {
  const _TestProfileSessionProvider(this.loadSession);

  final Future<ProfileSession> Function() loadSession;

  @override
  Future<ProfileSession> load() => loadSession();
}

class _TestProfileSession implements ProfileSession {
  const _TestProfileSession({this.apiToken, this.guestIdValue = 'GUEST1234'});

  @override
  final String? apiToken;

  @override
  String? get role => 'customer';

  @override
  String? get accountEmail => 'player@example.test';

  @override
  bool get matchNotificationsEnabled => false;

  final String guestIdValue;

  @override
  Future<String> guestId() async => guestIdValue;

  @override
  Future<void> setApiToken(String token) async {}

  @override
  Future<void> setRole(String role) async {}

  @override
  Future<void> setMatchNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> clear() async {}
}

_TestProfileSessionProvider _signedInSessionProvider() =>
    _TestProfileSessionProvider(
      () async => const _TestProfileSession(apiToken: 'profile-token'),
    );

_TestProfileSessionProvider _guestSessionProvider() =>
    _TestProfileSessionProvider(() async => const _TestProfileSession());

http.Response _profileResponse(String firstName) => http.Response(
  jsonEncode({
    'user': {
      'id': 'not-a-number',
      'role': 'customer',
      'firstName': firstName,
      'lastName': 'Player',
      'email': 'player@example.test',
    },
  }),
  200,
);
