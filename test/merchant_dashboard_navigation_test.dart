import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_dashboard.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';

import 'merchant_dashboard_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('back from merchant Messages restores the dashboard', (
    tester,
  ) async {
    setMerchantDashboardSession(role: 'customer');
    var logoutRequested = false;
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
            return http.Response(jsonEncode({'bookings': []}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          case '/api/messages/conversations':
            return http.Response(jsonEncode({'conversations': []}), 200);
          case '/api/messages/contacts':
            return http.Response(jsonEncode({'contacts': []}), 200);
          case '/api/auth/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 42, 'role': 'merchant'},
              }),
              200,
            );
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
          onLogout: (_) async => logoutRequested = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Data analytics'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-first-business-onboarding')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('merchant-first-business-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Add business'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-deadline-reminder')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('booking-deadline-reminder-cancel')),
    );
    await tester.pumpAndSettle();
    await tapMerchantDestination(tester, 'dashboard');

    await tapMerchantDestination(tester, 'messages');
    expect(find.byType(MessagesDashboardPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.byKey(const ValueKey('merchant-sidebar-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('news-feed-nav-explore')), findsNothing);

    await tapMerchantSettings(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Merchant Profile'), findsNothing);
    expect(
      find.byKey(const ValueKey('merchant-settings-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-settings-appearance')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tapMerchantDestination(tester, 'dashboard');

    await tapMerchantDestination(tester, 'dashboard');
    expect(find.byType(MessagesDashboardPage), findsNothing);
    expect(find.text('Data analytics'), findsOneWidget);

    await tapMerchantDestination(tester, 'profile');
    expect(find.text('Merchant Profile'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tapMerchantDestination(tester, 'dashboard');
    expect(find.text('Merchant Profile'), findsNothing);

    await tapMerchantSettings(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Merchant Profile'), findsNothing);
    expect(
      find.byKey(const ValueKey('merchant-settings-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-settings-appearance')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tapMerchantDestination(tester, 'dashboard');

    await tapMerchantDestination(tester, 'messages');
    expect(find.byType(MessagesDashboardPage), findsOneWidget);

    await tapMerchantDestination(tester, 'dashboard');

    expect(find.byType(MessagesDashboardPage), findsNothing);
    expect(find.text('Merchant Dashboard'), findsOneWidget);
    expect(find.text('Data analytics'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('merchant-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-drawer-help-center')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-drawer-terms-of-service')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('merchant-drawer-terms-of-service')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The official Terms of Service will be available here soon.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('merchant-sidebar-toggle')));
    await tester.pumpAndSettle();
    final drawerScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('merchant-navigation-drawer')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('merchant-drawer-logout')),
      120,
      scrollable: drawerScrollable,
    );
    await tester.tap(find.byKey(const ValueKey('merchant-drawer-logout')));
    await tester.pumpAndSettle();
    expect(logoutRequested, isTrue);
  });
}
