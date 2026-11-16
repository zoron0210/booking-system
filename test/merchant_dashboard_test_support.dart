import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/live_updates_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineLiveUpdatesClient extends LiveUpdatesClient {
  @override
  Future<void> connect(String token) async {
    throw StateError('WebSocket unavailable in this test.');
  }
}

class ConnectedLiveUpdatesClient extends LiveUpdatesClient {
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect(String token) async {}

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> close() => _events.close();
}

void setMerchantDashboardSession({
  String role = 'merchant',
  String apiToken = 'merchant-token',
}) {
  SharedPreferences.setMockInitialValues({
    'session_api_token': apiToken,
    'session_role': role,
  });
  FlutterSecureStorage.setMockInitialValues({'session_api_token': apiToken});
}

Future<void> tapMerchantDestination(
  WidgetTester tester,
  String destination,
) async {
  const keys = {
    'dashboard': 'merchant-dashboard-nav-dashboard',
    'businesses': 'merchant-dashboard-nav-add',
    'messages': 'merchant-dashboard-nav-messages',
    'bookings': 'merchant-dashboard-nav-payouts',
    'profile': 'merchant-dashboard-nav-profile',
  };
  final key = keys[destination];
  if (key == null) throw ArgumentError.value(destination, 'destination');
  final destinationFinder = find.byKey(ValueKey(key));
  if (destinationFinder.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('merchant-sidebar-toggle')));
    await tester.pumpAndSettle();
  }
  await tester.tap(destinationFinder);
  await tester.pumpAndSettle();
}

Future<void> tapMerchantSettings(WidgetTester tester) async {
  final settingsFinder = find.byKey(
    const ValueKey('merchant-profile-settings'),
  );
  if (settingsFinder.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('merchant-sidebar-toggle')));
    await tester.pumpAndSettle();
  }
  if (settingsFinder.evaluate().isEmpty) {
    final drawerScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('merchant-navigation-drawer')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      settingsFinder,
      120,
      scrollable: drawerScrollable,
    );
  }
  await tester.tap(settingsFinder);
  await tester.pumpAndSettle();
}
