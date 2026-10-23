import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/main.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logout confirms guest browsing after clearing the session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_authenticated': true,
      'session_last_booking_type': 'Event',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });

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
    expect(
      find.text('You’ve been signed out. You’re now browsing as a guest.'),
      findsOneWidget,
    );
    final session = await AppSession.load();
    expect(session.apiToken, isNull);
    expect(session.lastBookingType, isNull);
  });
}
