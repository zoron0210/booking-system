// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/event_dashboard.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('overview supports native pull-to-refresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.text('Your sport.\nYour event.\nYour place.'), findsOneWidget);
  });

  testWidgets('overview header login opens the real sign-in screen', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final brand = find.byKey(const ValueKey('overview-brand'));
    final login = find.byKey(const ValueKey('overview-login'));
    expect(login, findsOneWidget);
    expect(
      tester.getRect(brand).center.dy,
      closeTo(tester.getRect(login).center.dy, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(login);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('app opens the last selected booking feed on launch', (
    WidgetTester tester,
  ) async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await tester.pumpWidget(MyApp(session: session));
    await tester.pump();

    expect(find.byType(EventDashboardPage), findsOneWidget);
    expect(find.text('Your sport.\nYour event.\nYour place.'), findsNothing);
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
    expect(find.byType(OverviewPage), findsNothing);
    expect(find.text('Choose your booking type'), findsOneWidget);
    expect((await AppSession.load()).lastBookingType, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Marketplace overview renders the booking experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Your sport.\nYour event.\nYour place.'), findsOneWidget);
    final heroCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-hero-card')),
    );
    expect(
      (heroCard.decoration! as BoxDecoration).color,
      const Color(0xFF192B50),
    );
    expect(
      find.byKey(const ValueKey('assets/book-type/sports.jpg')),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Everything in one place'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Everything in one place'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Explore bookings'),
      -100,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.text('Explore bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore bookings'));
    await tester.pumpAndSettle();
    expect(find.byType(ReserveDashboardPage), findsOneWidget);
    expect(find.text('Reserve experience'), findsOneWidget);
    expect(find.text('Choose type'), findsOneWidget);
    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);

    await tester.tap(find.text('Sports').first);
    await tester.pumpAndSettle();
    expect(find.text('Continue to Sports'), findsOneWidget);
  });

  testWidgets('Marketplace dashboard content remains readable in dark mode', (
    tester,
  ) async {
    await AppPreferences.instance.update(darkMode: true);
    addTearDown(() => AppPreferences.instance.update(darkMode: false));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Made for the way you play'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('Made for the way you play')).style!.color,
      AppColors.darkInk,
    );

    final featureCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-feature-card-Easy discovery')),
    );
    expect(
      (featureCard.decoration! as BoxDecoration).color,
      AppColors.darkSurface,
    );

    await tester.scrollUntilVisible(
      find.text('Ready to make a plan?'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('Ready to make a plan?')).style!.color,
      AppColors.darkInk,
    );
  });
}
