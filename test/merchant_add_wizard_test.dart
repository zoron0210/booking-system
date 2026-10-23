import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('booking deadline reminder can be snoozed for 24 hours', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    var openedSettings = false;
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            initialBusinessType: null,
            api: api,
            businesses: const [],
            onBusinessesChanged: () async {},
            onSetBookingDeadlines: () async => openedSettings = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-deadline-reminder')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('booking-deadline-reminder-dont-show-again')),
    );
    await tester.tap(
      find.byKey(const ValueKey('booking-deadline-reminder-set-time')),
    );
    await tester.pumpAndSettle();

    final session = await AppSession.load();
    expect(session.bookingDeadlineReminderDismissed(), isTrue);
    expect(openedSettings, isTrue);
  });

  testWidgets('cancel closes the deadline reminder without opening settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    var openedSettings = false;
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            initialBusinessType: null,
            api: api,
            businesses: const [],
            onBusinessesChanged: () async {},
            onSetBookingDeadlines: () async => openedSettings = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('booking-deadline-reminder-cancel')),
    );
    await tester.pumpAndSettle();

    final session = await AppSession.load();
    expect(
      find.byKey(const ValueKey('booking-deadline-reminder')),
      findsNothing,
    );
    expect(session.bookingDeadlineReminderDismissed(), isFalse);
    expect(openedSettings, isFalse);
  });

  testWidgets('business setup form presents its current single-page fields', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

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

    expect(find.byKey(const ValueKey('business-setup-scroll')), findsOneWidget);
    expect(find.text('BUSINESS BASICS'), findsOneWidget);
    expect(find.text('Venue name (required)'), findsOneWidget);
    expect(find.text('SPORTS, SLOTS & RATES'), findsOneWidget);
    expect(find.text('Venue address (required)'), findsOneWidget);
    expect(find.text('Publish booking card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event form exposes event requirements and selectable types', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            key: pageKey,
            initialBusinessType: 'Event',
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

    expect(find.text('Venue name (required)'), findsOneWidget);
    final form = find.byKey(const ValueKey('business-setup-scroll'));
    final businessType = tester.widget<DropdownButtonFormField<String>>(
      find
          .descendant(
            of: form,
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first,
    );
    expect(businessType.initialValue, 'Event');
    expect(find.text('EVENT BOOKING DETAILS'), findsOneWidget);
    expect(
      find.text('Event types this venue can hold (required)'),
      findsOneWidget,
    );
    expect(find.text('Minimum guests (required)'), findsOneWidget);
    expect(find.text('Maximum guests (required)'), findsOneWidget);
    expect(find.text('FITNESS CATEGORIES & PRICES'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Wedding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
