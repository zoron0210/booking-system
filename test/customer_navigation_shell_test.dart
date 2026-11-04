import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/app_shell/presentation/customer_navigation_shell.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

void main() {
  testWidgets('customer tabs preserve page state when switching destinations', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        final body = request.url.path == '/api/businesses'
            ? '{"businesses":[]}'
            : '{}';
        return http.Response(body, 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: CustomerNavigationShell(api: api)),
    );

    await tester.tap(find.text('Venue').first);
    await _pumpFrames(tester);
    final venueState = tester.state<State>(
      find.byKey(const ValueKey('customer-navigation-tab-0')),
    );

    await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
    await _pumpFrames(tester);
    await tester.tap(find.text('Venue').first);
    await _pumpFrames(tester);

    expect(
      tester.state<State>(
        find.byKey(const ValueKey('customer-navigation-tab-0')),
      ),
      same(venueState),
    );
    expect(find.byType(IndexedStack), findsOneWidget);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
