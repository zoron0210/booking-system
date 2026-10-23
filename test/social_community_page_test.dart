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

  testWidgets('users can find and follow people while posting is disabled', (
    tester,
  ) async {
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
      findsNothing,
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

    await expectLater(
      api.createSocialPost(
        token: 'social-test-token',
        caption: 'Great day on court!',
        images: const [],
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      requests.any((request) => request.url.path == '/api/social/posts'),
      isFalse,
    );
  });

  testWidgets('profile experiences remain available for future re-enable', (
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
    expect(find.byKey(const ValueKey('social-create-post')), findsNothing);
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
    expect(find.text('Followers'), findsNothing);
  });
}
