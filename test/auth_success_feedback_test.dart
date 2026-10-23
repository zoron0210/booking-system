import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/auth/application/auth_service.dart';
import 'package:myapp/features/auth/presentation/auth_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthSessionStore implements AuthSessionStore {
  String? token;

  @override
  Future<bool> hasAuthenticatedApiSession() async => token != null;

  @override
  Future<void> save({
    required String email,
    required String token,
    required String role,
  }) async {
    this.token = token;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('successful login confirms sign-in after returning to caller', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final sessions = _TestAuthSessionStore();
    final service = AuthService(
      api: AuthApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/login');
          return http.Response(
            jsonEncode({
              'token': 'login-token',
              'user': {'email': 'player@example.com', 'role': 'customer'},
            }),
            200,
          );
        }),
      ),
      sessions: sessions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AuthDashboardPage(authService: service),
                ),
              ),
              child: const Text('Open sign in'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'player@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    final signInButton = find.byKey(const ValueKey('auth-primary-button'));
    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(sessions.token, 'login-token');
    expect(find.text('Open sign in'), findsOneWidget);
    expect(find.text('You’re signed in successfully.'), findsOneWidget);
  });
}
