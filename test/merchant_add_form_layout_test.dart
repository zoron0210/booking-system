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

  testWidgets('business setup form fits a phone width with readable text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

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
    final businessName = find.text('Venue name (required)');
    expect(businessName, findsOneWidget);

    final formTheme = tester.widget<Theme>(
      find.ancestor(of: businessName, matching: find.byType(Theme)).first,
    );
    expect(formTheme.data.textTheme.bodyLarge?.color, const Color(0xFF101B33));
    expect(tester.takeException(), isNull);
  });
}
