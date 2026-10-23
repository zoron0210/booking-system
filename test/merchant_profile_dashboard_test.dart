import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_profile_dashboard.dart';
import 'package:myapp/profile_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('merchant settings provide booking deadline controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {},
          profileImage: null,
          venueCount: 0,
          onLogout: (_) async {},
          onEditProfile: () async => null,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-settings-community')),
      findsNothing,
    );

    expect(
      find.byKey(const ValueKey('merchant-settings-switch-to-customer')),
      findsOneWidget,
    );
    final settingsList = find.ancestor(
      of: find.byKey(const ValueKey('merchant-settings-switch-to-customer')),
      matching: find.byType(ListView),
    );
    final settingsScrollable = find
        .descendant(of: settingsList, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('merchant-settings-booking-deadlines')),
      120,
      scrollable: settingsScrollable,
    );
    expect(
      find.byKey(const ValueKey('merchant-settings-booking-deadlines')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('merchant-settings-venue-check-in')),
      120,
      scrollable: settingsScrollable,
    );
    expect(
      find.byKey(const ValueKey('merchant-settings-venue-check-in')),
      findsOneWidget,
    );
    final helpCenter = find
        .byKey(const ValueKey('merchant-settings-help-center'))
        .first;
    final termsOfService = find
        .byKey(const ValueKey('merchant-settings-terms-of-service'))
        .first;
    await tester.ensureVisible(helpCenter);
    await tester.pumpAndSettle();
    expect(termsOfService, findsOneWidget);
    expect(
      tester.getTopLeft(helpCenter).dy,
      tester.getTopLeft(termsOfService).dy,
    );
  });

  testWidgets('saving booking deadlines after closing the dialog succeeds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
      'session_role': 'merchant',
      'session_authenticated': true,
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    http.Request? saveRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/merchant/booking-deadlines') {
          return http.Response(
            jsonEncode({
              'approvalTimeoutMinutes': 30,
              'paymentTimeoutMinutes': 60,
            }),
            200,
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/merchant/booking-deadlines') {
          saveRequest = request;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {},
          profileImage: null,
          venueCount: 0,
          onLogout: (_) async {},
          onEditProfile: () async => null,
          api: api,
          openBookingDeadlinesOnStart: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '45');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveRequest, isNotNull);
    expect(jsonDecode(saveRequest!.body), {
      'approvalTimeoutMinutes': 45,
      'paymentTimeoutMinutes': 60,
    });
    expect(find.text('Booking deadlines saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant venue check-in QR is managed from profile settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
      'session_role': 'merchant',
      'session_authenticated': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final session = await AppSession.load();
    await session.setApiToken('merchant-token');
    await session.setRole('merchant');
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/merchant/businesses/7/check-in-code') {
          return http.Response(
            jsonEncode({
              'qrCode': '{"type":"tinkerpro.checkin","venueId":7}',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 2))
                  .millisecondsSinceEpoch,
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {},
          profileImage: null,
          venueCount: 1,
          businesses: const [
            {'id': 7, 'name': 'Sample Studio'},
          ],
          api: api,
          onLogout: (_) async {},
          onEditProfile: () async => null,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-settings-venue-check-in')),
      findsOneWidget,
    );
    final venueCheckInSetting = find.byKey(
      const ValueKey('merchant-settings-venue-check-in'),
    );
    await tester.ensureVisible(venueCheckInSetting);
    await tester.pumpAndSettle();
    await tester.tap(venueCheckInSetting);
    await tester.pumpAndSettle();
    expect(find.text('Choose venue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('merchant-checkin-venue-7')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-check-in-qr-code')),
      findsOneWidget,
    );
    expect(
      requests.map((request) => request.url.path),
      contains('/api/merchant/businesses/7/check-in-code'),
    );
  });

  testWidgets('merchant profile opens customer portal using switched token', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
      'session_role': 'merchant',
      'session_authenticated': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final session = await AppSession.load();
    await session.setApiToken('merchant-token');
    await session.setRole('merchant');
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/auth/portal-mode') {
          return http.Response(
            jsonEncode({'token': 'customer-mode-token', 'role': 'customer'}),
            200,
          );
        }
        if (request.url.path == '/api/news-feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(jsonEncode({'businesses': []}), 200);
        }
        if (request.url.path == '/api/saved-items') {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {},
          profileImage: null,
          venueCount: 0,
          api: api,
          onLogout: (_) async {},
          onEditProfile: () async => null,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('merchant-settings-switch-to-customer')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news-feed-nav-explore')), findsOneWidget);
    expect(find.text('You’re now browsing as a customer.'), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/auth/portal-mode' &&
            jsonDecode(request.body)['mode'] == 'customer',
      ),
      isTrue,
    );
    final updatedSession = await AppSession.load();
    expect(updatedSession.role, 'customer');
    expect(updatedSession.apiToken, 'customer-mode-token');
  });

  testWidgets('merchant customer mode exposes return switch in Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'customer-mode-token',
      'session_role': 'customer',
      'session_authenticated': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final session = await AppSession.load();
    await session.setApiToken('customer-mode-token');
    await session.setRole('customer');
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 88,
                'role': 'merchant',
                'firstName': 'Morgan',
                'lastName': 'Merchant',
                'email': 'merchant@example.test',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        if (request.url.path == '/api/social/users/88') {
          return http.Response(
            jsonEncode({
              'profile': {
                'id': 88,
                'role': 'merchant',
                'postsCount': 0,
                'followersCount': 0,
                'followingCount': 0,
              },
              'posts': [],
              'businesses': [],
            }),
            200,
          );
        }
        if (request.url.path == '/api/auth/portal-mode') {
          return http.Response(
            jsonEncode({'token': 'merchant-mode-token', 'role': 'merchant'}),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ProfileDashboardPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final switchPortal = find.byKey(
      const ValueKey('profile-settings-switch-to-merchant'),
    );
    expect(switchPortal, findsOneWidget);
    await tester.tap(switchPortal);
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/auth/portal-mode' &&
            jsonDecode(request.body)['mode'] == 'merchant',
      ),
      isTrue,
    );
    final updatedSession = await AppSession.load();
    expect(updatedSession.role, 'merchant');
    expect(updatedSession.apiToken, 'merchant-mode-token');
  });

  testWidgets('merchant notification controls are grouped in their own page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {},
          profileImage: null,
          venueCount: 0,
          onLogout: (_) async {},
          onEditProfile: () async => null,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();

    final notificationSettings = find.byKey(
      const ValueKey('merchant-settings-notifications'),
    );
    expect(notificationSettings, findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-match-notifications-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('booking-push-notifications-switch')),
      findsNothing,
    );

    await tester.tap(notificationSettings);
    await tester.pumpAndSettle();

    expect(find.text('Notification settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-settings-device')),
      findsOneWidget,
    );
  });

  testWidgets(
    'merchant profile filters performance and shows overview and quick tools',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      var destination = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantProfileDashboardPage(
            owner: const {
              'firstName': 'Morgan',
              'lastName': 'Merchant',
              'email': 'morgan@example.com',
              'businessName': 'Morgan Sports',
              'address': 'Manila',
            },
            profileImage: null,
            venueCount: 1,
            bookings: [
              {
                'date': _date(now),
                'status': 'approved',
                'total': 100,
                'paidAmount': 40,
                'paymentStatus': 'partial',
              },
              {
                'date': _date(now.subtract(const Duration(days: 1))),
                'status': 'approved',
                'total': 60,
                'paymentStatus': 'paid',
              },
              {
                'date': _date(now),
                'status': 'pending',
                'total': 500,
                'paymentStatus': 'unpaid',
              },
            ],
            businesses: const [
              {
                'name': 'Morgan Sports',
                'availability': 'open',
                'averageRating': 4.8,
                'imageUrl': 'https://example.com/venue.jpg',
              },
            ],
            onEditProfile: () async => null,
            onLogout: (_) async {},
            onNavigate: (index) => destination = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₱40.00'), findsOneWidget);
      expect(find.text('₱100.00'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('merchant-profile-date-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All time').last);
      await tester.pumpAndSettle();

      expect(find.text('₱100.00'), findsOneWidget);
      expect(find.text('₱160.00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Business overview'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Morgan Sports'), findsWidgets);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.textContaining('marked open or available'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Schedule'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(destination, 3);
    },
  );
}
