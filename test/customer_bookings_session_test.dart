import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/customer_bookings_page.dart';
import 'package:myapp/features/bookings/data/customer_bookings_session_provider.dart';

class _FakeCustomerBookingsSession implements CustomerBookingsSession {
  _FakeCustomerBookingsSession({this.apiToken});

  @override
  final String? apiToken;
  final Set<String> dismissedBanners = {};

  @override
  bool bookingStatusBannerDismissed(String bookingKey) =>
      dismissedBanners.contains(bookingKey);

  @override
  Future<void> dismissBookingStatusBanner(String bookingKey) async {
    dismissedBanners.add(bookingKey);
  }
}

class _FakeCustomerBookingsSessionProvider
    implements CustomerBookingsSessionProvider {
  _FakeCustomerBookingsSessionProvider(this.session);

  final CustomerBookingsSession session;

  @override
  Future<CustomerBookingsSession> load() async => session;
}

void main() {
  testWidgets('loads booking data with the injected session token', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(
          api: api,
          sessionProvider: _FakeCustomerBookingsSessionProvider(
            _FakeCustomerBookingsSession(apiToken: 'injected-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.url.path), [
      '/api/bookings',
      '/api/messages/conversations',
    ]);
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer injected-token',
      ),
      isTrue,
    );
    expect(find.text('No pending bookings.'), findsOneWidget);
  });

  testWidgets('does not request bookings without a session token', (
    tester,
  ) async {
    var requestCount = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(
          api: api,
          sessionProvider: _FakeCustomerBookingsSessionProvider(
            _FakeCustomerBookingsSession(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 0);
    expect(find.text('No pending bookings.'), findsOneWidget);
  });
}
