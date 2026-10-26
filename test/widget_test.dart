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

    expect(find.text('Make today\nyours.'), findsOneWidget);
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

  testWidgets(
    'overview branding and category cards open SpotGo booking flows',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      expect(app.title, 'SpotGo');
      expect(find.text('SpotGo'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-brand-logo')), findsOneWidget);

      final eventCategory = find.byKey(
        const ValueKey('overview-category-Events'),
      );
      final sportsCategory = find.byKey(
        const ValueKey('overview-category-Sports'),
      );
      final fitnessCategory = find.byKey(
        const ValueKey('overview-category-Fitness & Wellness'),
      );
      expect(
        tester.getSize(sportsCategory).width,
        tester.getSize(eventCategory).width,
      );
      expect(
        tester.getSize(sportsCategory).width,
        tester.getSize(fitnessCategory).width,
      );
      expect(
        tester.getSize(sportsCategory).height,
        tester.getSize(eventCategory).height,
      );
      expect(
        tester.getSize(sportsCategory).height,
        tester.getSize(fitnessCategory).height,
      );
      final eventImage = tester.widget<Image>(
        find.descendant(of: eventCategory, matching: find.byType(Image)),
      );
      expect(
        (eventImage.image as AssetImage).assetName,
        'assets/overview/events.png',
      );
      await tester.scrollUntilVisible(
        eventCategory,
        180,
        scrollable: find.byType(Scrollable),
      );
      await tester.ensureVisible(eventCategory);
      await tester.pumpAndSettle();
      await tester.tap(eventCategory);
      await tester.pumpAndSettle();

      expect(find.byType(EventDashboardPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all-experiences CTA opens the type picker for returning users', (
    WidgetTester tester,
  ) async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final exploreAll = find.byKey(const ValueKey('overview-bottom-explore'));
    await tester.scrollUntilVisible(
      exploreAll,
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(exploreAll);
    await tester.pumpAndSettle();
    await tester.tap(exploreAll);
    await tester.pumpAndSettle();

    expect(find.byType(ReserveDashboardPage), findsOneWidget);
    expect(find.byType(EventDashboardPage), findsNothing);
  });

  testWidgets('app opens the last selected booking feed on launch', (
    WidgetTester tester,
  ) async {
    final session = await AppSession.load();
    await session.setLastBookingType('Event');

    await tester.pumpWidget(MyApp(session: session));
    await tester.pump();

    expect(find.byType(EventDashboardPage), findsOneWidget);
    expect(find.text('Make today\nyours.'), findsNothing);
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

    expect(find.text('Make today\nyours.'), findsOneWidget);
    final heroCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-hero-card')),
    );
    expect((heroCard.decoration! as BoxDecoration).color, AppColors.surface);
    expect(
      find.byKey(const ValueKey('overview-category-Sports')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('HOW SPOTGO WORKS'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('HOW SPOTGO WORKS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Find your next place'),
      -100,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.text('Find your next place'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find your next place'));
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
      find.text('HOW SPOTGO WORKS'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('HOW SPOTGO WORKS')).style!.color,
      AppColors.accentForeground,
    );

    final stepsCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-how-it-works')),
    );
    expect(
      (stepsCard.decoration! as BoxDecoration).color,
      AppColors.darkSoftSurface,
    );

    await tester.scrollUntilVisible(
      find.text('Your next plan starts here'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('Your next plan starts here')).style!.color,
      Colors.white,
    );
  });
}
