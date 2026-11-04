import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_dashboard.dart';

import 'merchant_dashboard_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connected dashboard updates avoid recurring booking polling', (
    tester,
  ) async {
    setMerchantDashboardSession();
    var bookingRequestCount = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/merchant/profile':
            return http.Response(
              jsonEncode({
                'profile': {
                  'firstName': 'Merchant',
                  'lastName': 'Owner',
                  'email': 'merchant@example.com',
                  'businessType': 'Sports',
                },
              }),
              200,
            );
          case '/api/merchant/businesses':
            return http.Response(jsonEncode({'businesses': []}), 200);
          case '/api/merchant/bookings':
            bookingRequestCount++;
            return http.Response(jsonEncode({'bookings': []}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          default:
            return http.Response(
              jsonEncode({'error': 'Unexpected request'}),
              404,
            );
        }
      }),
    );
    final liveUpdates = ConnectedLiveUpdatesClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardPage(
          api: api,
          liveUpdatesClientFactory: () => liveUpdates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(bookingRequestCount, 1);

    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(bookingRequestCount, 1);

    liveUpdates.emit({'type': 'dashboard.updated'});
    await tester.pumpAndSettle();
    expect(bookingRequestCount, 2);
  });

  testWidgets('booking polling does not overlap a slow request', (
    tester,
  ) async {
    setMerchantDashboardSession();
    final delayedBookingResponse = Completer<http.Response>();
    var bookingRequestCount = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/merchant/profile':
            return http.Response(
              jsonEncode({
                'profile': {
                  'firstName': 'Merchant',
                  'lastName': 'Owner',
                  'email': 'merchant@example.com',
                  'businessType': 'Sports',
                },
              }),
              200,
            );
          case '/api/merchant/businesses':
            return http.Response(jsonEncode({'businesses': []}), 200);
          case '/api/merchant/bookings':
            bookingRequestCount++;
            if (bookingRequestCount == 2) return delayedBookingResponse.future;
            return http.Response(jsonEncode({'bookings': []}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          default:
            return http.Response(
              jsonEncode({'error': 'Unexpected request'}),
              404,
            );
        }
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardPage(
          api: api,
          liveUpdatesClientFactory: OfflineLiveUpdatesClient.new,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(bookingRequestCount, 1);

    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
    expect(bookingRequestCount, 2);

    await tester.pump(const Duration(seconds: 5));
    expect(bookingRequestCount, 2);

    delayedBookingResponse.complete(
      http.Response(jsonEncode({'bookings': []}), 200),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

    expect(bookingRequestCount, 2);
  });
}
