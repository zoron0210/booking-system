// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/core/app_session.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/app_shell/presentation/event_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/first_launch_onboarding.dart';
import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/app_shell/presentation/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/main.dart';

AuthApi _emptySocialApi() => AuthApi(
  client: MockClient(
    (_) async => http.Response(jsonEncode({'posts': []}), 200),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('first launch onboarding leads into the customer Home feed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(homeApi: _emptySocialApi()));
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchOnboardingPage), findsOneWidget);
    expect(
      find.text('Find Your Perfect Court, Anytime, Anywhere'),
      findsOneWidget,
    );
    expect(find.text('Make today\nyours.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip-0')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomePage), findsOneWidget);
    expect(find.text('SpotGO'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('customer-home-player-rail')),
      findsOneWidget,
    );
    expect(
      find.text('Share your session, drop an invite, or post a highlight'),
      findsOneWidget,
    );
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Nearby Venues'), findsNothing);
    expect(find.text('Looking for'), findsNothing);
    expect(find.text('+2 Needed'), findsNothing);
    expect(find.byKey(const ValueKey('customer-nav-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(FirstLaunchOnboardingGate.completionKey),
      isTrue,
    );
  });

  testWidgets('app opens the last selected booking feed on launch', (
    WidgetTester tester,
  ) async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await tester.pumpWidget(MyApp(session: session));
    await tester.pump();

    expect(find.byType(EventDashboardPage), findsOneWidget);
  });

  testWidgets('logout opens booking type picker instead of Overview', (
    WidgetTester tester,
  ) async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('test-logout'),
              onPressed: () => logoutToBookingPicker(context),
              child: const Text('Log out'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('test-logout')));
    await tester.pumpAndSettle();

    expect(find.byType(ReserveDashboardPage), findsOneWidget);
    expect(find.text('Choose Booking Type'), findsOneWidget);
    expect((await AppSession.load()).lastBookingType, isNull);
    expect(tester.takeException(), isNull);
  });
}
