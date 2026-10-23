import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fitness add form exposes category pricing and coach fields', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/merchant/news-posts') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            key: pageKey,
            initialBusinessType: 'Fitness & Wellness',
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
    expect(find.text('FITNESS CATEGORIES & PRICES'), findsOneWidget);
    expect(find.text('COACH STAFF (OPTIONAL)'), findsOneWidget);
    expect(find.text('EVENT BOOKING DETAILS'), findsNothing);
    final pilates = find.widgetWithText(CheckboxListTile, 'Pilates');
    expect(pilates, findsOneWidget);
    await tester.tap(pilates);
    await tester.pumpAndSettle();
    expect(find.text('Session price (required)'), findsOneWidget);
    expect(find.text('Monthly price (required)'), findsOneWidget);
    expect(find.text('Yearly price (required)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
