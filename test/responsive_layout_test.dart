import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_bottom_navigation.dart';
import 'package:myapp/app_design_system.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/all_venues_page.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:myapp/main.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom navigation adapts across narrow phone widths', (
    tester,
  ) async {
    for (final width in [280.0, 320.0, 360.0, 430.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 640),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: AppBottomNavigation(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('news-feed-nav-explore')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('bottom navigation stays centered and compact on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = find.byType(NavigationBar);
    final navigationRect = tester.getRect(navigation);
    expect(navigationRect.width, lessThanOrEqualTo(900));
    expect(navigationRect.center.dx, closeTo(800, 1));
    expect(navigationRect.bottom, closeTo(900, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview content is centered and constrained on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OverviewPage()));
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(find.byType(CustomScrollView));
    expect(contentRect.width, closeTo(AppResponsive.contentMaxWidth, 1));
    expect(contentRect.center.dx, closeTo(800, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview fits portrait and landscape tablet viewports', (
    tester,
  ) async {
    for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(const MaterialApp(home: OverviewPage()));
      await tester.pumpAndSettle();

      final contentRect = tester.getRect(find.byType(CustomScrollView));
      expect(contentRect.width, lessThanOrEqualTo(1000));
      expect(contentRect.center.dx, closeTo(size.width / 2, 1));
      expect(tester.takeException(), isNull, reason: '$size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets(
    'booking type picker remains usable on portrait and landscape tablets',
    (tester) async {
      for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          const MaterialApp(home: ReserveDashboardPage()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Choose Booking Type'), findsOneWidget);
        expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('reserve-option-sports')))
              .width,
          lessThanOrEqualTo(1000),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('merchant business form fits on portrait and landscape tablets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final pageKey = GlobalKey<MerchantAddPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantAddPage(
              key: pageKey,
              initialBusinessType: 'Sports',
              api: api,
              businesses: const [],
              onBusinessesChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      pageKey.currentState!.openAddBusinessForm();
      await tester.pumpAndSettle();
      expect(find.text('Add business'), findsWidgets);
      expect(find.text('Venue name (required)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('sports selection stays usable across phone widths', (
    tester,
  ) async {
    for (final width in [280.0, 320.0, 360.0, 430.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 640),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: const SportsSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Choose a sport'),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Choose a sport'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('merchant setup form fits a compact screen with large text', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    await tester.pumpWidget(
      _withCompactMediaQuery(
        Scaffold(
          body: MerchantAddPage(
            key: pageKey,
            initialBusinessType: 'Sports',
            api: api,
            businesses: const [],
            onBusinessesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageKey.currentState!.openAddBusinessForm();
    await tester.pumpAndSettle();

    expect(find.text('Add business'), findsOneWidget);
    expect(find.text('Venue name (required)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking type selection fits a compact screen with large text', (
    tester,
  ) async {
    await _setCompactViewport(tester);

    await tester.pumpWidget(
      _withCompactMediaQuery(const ReserveDashboardPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Booking Type'), findsOneWidget);
    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);
    expect(find.text('Sports & Courts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'venue filters remain usable on a compact screen with large text',
    (tester) async {
      await _setCompactViewport(tester);

      await tester.pumpWidget(
        _withCompactMediaQuery(
          AllVenuesPage(
            title: 'Most popular',
            posts: const [
              {
                'businessName': 'Compact court',
                'category': 'Basketball',
                'address': 'Cebu City',
                'facilityType': 'Indoor',
                'pricePerHour': 250,
                'tags': 'Parking',
              },
            ],
            cardBuilder: (post) => SizedBox(
              height: 120,
              child: Card(child: Text('${post['businessName']}')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compact court'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('all-venues-open-filters')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('all-venues-filter-price')),
        100,
        scrollable: find.byType(Scrollable).last,
      );

      expect(
        find.byKey(const ValueKey('all-venues-filter-price')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('all-venues-filter-apply')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _withCompactMediaQuery(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(
      size: Size(320, 640),
      textScaler: TextScaler.linear(1.5),
    ),
    child: child,
  ),
);
