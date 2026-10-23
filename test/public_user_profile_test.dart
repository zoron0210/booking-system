import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/public_user_profile.dart';

void main() {
  testWidgets('public profile modal shows user info and can follow', (
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
                'followersCount': 3,
                'followingCount': 5,
                'isFollowing': false,
              },
              'posts': [],
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
              onPressed: () => showPublicUserProfileDialog(
                context: context,
                api: api,
                token: 'test-token',
                userId: 42,
                onViewProfile: () async {},
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
    expect(find.text('Follow'), findsOneWidget);
    final followButton = tester.getRect(
      find.byKey(const ValueKey('public-user-follow-button')),
    );
    final viewProfileButton = tester.getRect(
      find.byKey(const ValueKey('public-user-view-profile-button')),
    );
    expect(followButton.top, viewProfileButton.top);
    expect(followButton.right, lessThan(viewProfileButton.left));
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

  testWidgets('connection list opens a selected user profile', (tester) async {
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/social/users/42/following');
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
      }),
    );
    int? openedProfileId;
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
                onOpenProfile: (userId) async => openedProfileId = userId,
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
    await tester.tap(find.text('Morgan User'));
    await tester.pumpAndSettle();

    expect(openedProfileId, 17);
  });
}
