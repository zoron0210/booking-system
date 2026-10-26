import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/social_community_page.dart';
import 'package:myapp/social_profile_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'social-test-token',
    });
  });

  testWidgets('users can find, follow, and share experiences', (tester) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/social/users') {
          return http.Response(
            jsonEncode({
              'users': [
                {
                  'id': 42,
                  'displayName': 'Alex Player',
                  'avatarUrl': null,
                  'role': 'customer',
                  'followersCount': 3,
                  'isFollowing': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/follows/42') {
          return http.Response(jsonEncode({'isFollowing': true}), 200);
        }
        if (request.url.path == '/api/social/posts') {
          return http.Response(
            jsonEncode({'id': 5, 'message': 'Experience shared.'}),
            201,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Your community feed is quiet.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('social-community-create-post')),
      findsOneWidget,
    );

    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Player'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/follows/42',
      ),
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('social-community-create-post')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-post-caption')),
      'Great day on court!',
    );
    await tester.tap(find.byKey(const ValueKey('social-post-submit')));
    await tester.pumpAndSettle();

    final postRequest = requests.singleWhere(
      (request) => request.url.path == '/api/social/posts',
    );
    expect(postRequest.method, 'POST');
    expect(jsonDecode(postRequest.body), {
      'caption': 'Great day on court!',
      'images': [],
    });
    expect(find.text('Your experience has been shared.'), findsOneWidget);
  });

  testWidgets(
    'guests can browse public posts and profiles but not follow or post',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final requests = <http.Request>[];
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/social/feed') {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'id': 19,
                    'userId': 42,
                    'displayName': 'Alex Player',
                    'caption': 'Public match',
                    'images': [],
                    'createdAt': '2026-05-01T12:00:00.000Z',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/social/users') {
            return http.Response(
              jsonEncode({
                'users': [
                  {
                    'id': 42,
                    'displayName': 'Alex Player',
                    'followersCount': 3,
                    'isFollowing': false,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/social/users/42') {
            return http.Response(
              jsonEncode({
                'profile': {
                  'displayName': 'Alex Player',
                  'followersCount': 3,
                  'followingCount': 1,
                  'isFollowing': false,
                },
                'posts': [
                  {
                    'id': 19,
                    'caption': 'Public match',
                    'images': [],
                    'createdAt': '2026-05-01T12:00:00.000Z',
                  },
                ],
                'businesses': [],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Public match'), findsOneWidget);
      await tester.tap(find.text('Alex Player').first);
      await tester.pumpAndSettle();
      expect(find.text('Experiences'), findsOneWidget);
      expect(
        requests.map((request) => request.url.path),
        contains('/api/social/users/42'),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Log in to continue'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('social-community-create-post')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log in to continue'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        requests.any(
          (request) =>
              request.method != 'GET' &&
              (request.url.path == '/api/social/posts' ||
                  request.url.path.startsWith('/api/social/follows/')),
        ),
        isFalse,
      );
    },
  );

  testWidgets('experience cards support likes, comments, and saves', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var commentCount = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': 5,
                  'userId': 42,
                  'displayName': 'Alex Player',
                  'caption': 'A great match',
                  'images': [],
                  'createdAt': '2026-10-26T08:00:00.000Z',
                  'likeCount': 2,
                  'commentCount': commentCount,
                  'isLiked': false,
                  'isSaved': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/users') {
          return http.Response(jsonEncode({'users': []}), 200);
        }
        if (request.url.path == '/api/social/posts/5/comments' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'comments': []}), 200);
        }
        if (request.url.path == '/api/social/posts/5/comments' &&
            request.method == 'POST') {
          commentCount++;
          return http.Response(jsonEncode({'id': 11}), 201);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-post-like-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-post-save-5')));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/posts/5/likes',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/posts/5/saves',
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('social-post-comment-5')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-comment-input')),
      'Well played!',
    );
    await tester.tap(find.byKey(const ValueKey('social-comment-send')));
    await tester.pumpAndSettle();
    expect(commentCount, 1);
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/posts/5/comments',
      ),
      isTrue,
    );
  });

  testWidgets('profile experiences show business posts and share action', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/social/users/7');
        return http.Response(
          jsonEncode({
            'profile': {
              'postsCount': 0,
              'followersCount': 8,
              'followingCount': 4,
            },
            'posts': [],
            'businesses': [
              {
                'businessId': 23,
                'businessName': 'Northside Courts',
                'businessType': 'Sports',
                'enabled': true,
                'imageUrl': '',
                'imageUrls': ['https://example.test/northside.jpg'],
              },
            ],
          }),
          200,
        );
      }),
    );
    Map<String, dynamic>? loadedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialProfileSection(
            api: api,
            token: 'social-test-token',
            userId: 7,
            onOpenCommunity: () async {},
            onProfileLoaded: (profile) => loadedProfile = profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadedProfile?['postsCount'], 0);
    expect(loadedProfile?['followersCount'], 8);
    expect(find.text('Your experiences'), findsOneWidget);
    expect(find.byKey(const ValueKey('social-create-post')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('social-profile-business-23')),
      findsOneWidget,
    );
    final businessImage = find.descendant(
      of: find.byKey(const ValueKey('social-profile-business-23')),
      matching: find.byType(Image),
    );
    expect(businessImage, findsOneWidget);
    expect(
      (tester.widget<Image>(businessImage).image as NetworkImage).url,
      'https://example.test/northside.jpg',
    );
    expect(find.text('Northside Courts'), findsOneWidget);
    expect(find.text('Community'), findsNothing);
  });
}
