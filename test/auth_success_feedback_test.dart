import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/auth/application/auth_service.dart';
import 'package:myapp/features/auth/presentation/auth_dashboard.dart';
import 'package:myapp/guest_access.dart';
import 'package:myapp/news_feed.dart';
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
              'user': {
                'email': 'player@example.com',
                'role': 'customer',
                'onboardingCompleted': true,
              },
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
    expect(find.byType(SpotGoLogo), findsOneWidget);
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

  testWidgets(
    'new customer can enter hobbies and is sent to Home automatically',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final sessions = _TestAuthSessionStore();
      Map<String, dynamic>? onboardingAnswers;
      final service = AuthService(
        api: AuthApi(
          client: MockClient((request) async {
            if (request.url.path == '/api/social/feed') {
              return http.Response(jsonEncode({'posts': []}), 200);
            }
            if (request.url.path == '/api/auth/login') {
              return http.Response(
                jsonEncode({
                  'token': 'new-customer-token',
                  'user': {
                    'email': 'new-player@example.com',
                    'firstName': 'Sam',
                    'role': 'customer',
                    'onboardingCompleted': false,
                  },
                }),
                200,
              );
            }
            expect(request.url.path, '/api/auth/onboarding');
            onboardingAnswers =
                jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'user': {'role': 'customer', 'onboardingCompleted': true},
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
                onPressed: () async {
                  await openCustomerLogin(context, authService: service);
                },
                child: const Text('Open sign in'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'new-player@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'password123');
      final signInButton = find.byKey(const ValueKey('auth-primary-button'));
      await tester.ensureVisible(signInButton);
      await tester.pumpAndSettle();
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(find.text('How should we identify you?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('customer-onboarding-next-0')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose an option to continue.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-choice-male')));
      await tester.tap(
        find.byKey(const ValueKey('customer-onboarding-next-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('customer-onboarding-skip-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-hobby-Basketball')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-hobby-input')),
        'Rock climbing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('customer-onboarding-next-2')),
      );
      await tester.pump();
      expect(find.text('Getting your profile ready…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(onboardingAnswers, {
        'gender': 'male',
        'playerType': null,
        'hobby': 'Basketball, Rock climbing',
      });
      expect(find.text('Welcome, Sam!'), findsOneWidget);
      expect(find.text('Rock climbing'), findsOneWidget);
      expect(find.text('Taking you to your Home feed…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomePage), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-home-add')), findsOneWidget);
      expect(find.text('Add experience'), findsNothing);
    },
  );
}
