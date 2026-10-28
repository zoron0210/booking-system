import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/public_user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('public profile dashboard shows public info and follow/message', (
    tester,
  ) async {
    var followed = false;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/social/users/42');
          return http.Response(
            jsonEncode({
              'profile': {
                'displayName': 'Taylor Player',
                'avatarUrl': null,
                'hobby': 'Tennis, hiking',
                'followersCount': 3,
                'followingCount': 5,
                'postsCount': 2,
                'isFollowing': false,
              },
              'posts': [
                {
                  'id': 7,
                  'caption': 'A public experience',
                  'images': [],
                  'likeCount': 4,
                  'commentCount': 1,
                },
              ],
              'businesses': [],
            }),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/social/follows/42');
        followed = true;
        return http.Response(jsonEncode({'isFollowing': true}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPublicUserProfile(
                context: context,
                api: api,
                token: 'test-token',
                userId: 42,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Taylor Player'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('Tennis, hiking'), findsOneWidget);
    expect(find.text('A public experience'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Taylor Player')).dx,
      closeTo(
        tester
            .getCenter(find.byKey(const ValueKey('public-profile-header')))
            .dx,
        1,
      ),
    );
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('History'), findsNothing);
    expect(
      find.byKey(const ValueKey('public-user-profile-page')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('public-user-follow-button')));
    await tester.pumpAndSettle();

    expect(followed, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('public-user-follow-button')),
        matching: find.text('Following'),
      ),
      findsOneWidget,
    );
  });

  test('social connection API selects the requested list', () async {
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/social/users/42/followers');
        return http.Response(
          jsonEncode({
            'users': [
              {
                'id': 17,
                'displayName': 'Morgan User',
                'followersCount': 0,
                'isFollowing': false,
              },
            ],
          }),
          200,
        );
      }),
    );

    final users = await api.socialUserConnections(
      token: 'test-token',
      userId: 42,
      type: 'followers',
    );
    expect(users.single['displayName'], 'Morgan User');
  });

  testWidgets('connection list opens the selected public profile', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/users/42/following') {
          return http.Response(
            jsonEncode({
              'users': [
                {
                  'id': 17,
                  'displayName': 'Morgan User',
                  'avatarUrl': null,
                  'followersCount': 0,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/users/17') {
          return http.Response(
            jsonEncode({
              'profile': {
                'id': 17,
                'displayName': 'Morgan User',
                'followersCount': 8,
                'followingCount': 2,
                'postsCount': 1,
              },
              'posts': [],
              'businesses': [],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUserConnections(
                context: context,
                api: api,
                token: 'test-token',
                userId: 42,
                type: 'following',
              ),
              child: const Text('Open following'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open following'));
    await tester.pumpAndSettle();
    expect(find.text('Morgan User'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-connection-17')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('public-user-profile-page')),
      findsOneWidget,
    );
    expect(find.text('Morgan User'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('public profile message targets the displayed profile ID', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    Map<String, dynamic>? messageRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/users/42') {
          return http.Response(
            jsonEncode({
              'profile': {
                'id': 17,
                'displayName': 'Morgan User',
                'followersCount': 0,
                'followingCount': 0,
                'postsCount': 0,
              },
              'posts': [],
              'businesses': [],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/messages/conversations') {
          messageRequest = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'conversationId': 77}), 201);
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        if (request.url.path == '/api/messages/contacts') {
          return http.Response(jsonEncode({'contacts': []}), 200);
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 1},
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations/77') {
          return http.Response(jsonEncode({'messages': []}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfilePage(api: api, token: 'test-token', userId: 42),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('public-user-message-button')));
    await tester.pumpAndSettle();

    expect(messageRequest?['participantIds'], [17]);
    expect(messageRequest?['type'], 'direct');
  });
}
