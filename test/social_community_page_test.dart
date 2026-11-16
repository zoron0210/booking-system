import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/social/presentation/social_community_page.dart';
import 'package:myapp/features/social/presentation/social_profile_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _TestImagePickerPlatform.imagePickCalls = 0;
    _TestImagePickerPlatform.multiImagePickCalls = 0;
    ImagePickerPlatform.instance = _TestImagePickerPlatform();
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'social-test-token',
    });
  });

  testWidgets('a user can create a club and becomes its owner member', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/uploads' &&
            request.method == 'POST') {
          final size = (jsonDecode(request.body) as Map)['size'];
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://storage.googleapis.com/test-bucket/upload',
              'key':
                  'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-$size',
              'headers': {'Content-Type': 'image/png'},
            }),
            201,
          );
        }
        if (request.method == 'PUT') return http.Response('', 200);
        if (request.url.path == '/api/social/clubs' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'clubs': []}), 200);
        }
        if (request.url.path == '/api/social/clubs' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'club': {
                'id': 31,
                'name': 'Cebu Runners',
                'logoUrl': 'https://storage.googleapis.com/club-logo.png',
                'description': 'Sunday morning runs.',
                'ownerUserId': 7,
                'ownerName': 'Current Player',
                'memberCount': 1,
                'isOwner': true,
                'isMember': true,
              },
            }),
            201,
          );
        }
        if (request.url.path == '/api/social/clubs/31/join-requests') {
          return http.Response(
            jsonEncode({
              'requests': [
                {'userId': 9, 'displayName': 'New Member'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31/settings' &&
            request.method == 'PATCH') {
          return http.Response(jsonEncode({'requiresJoinApproval': true}), 200);
        }
        if (request.url.path == '/api/social/clubs/31/join-requests/9' &&
            request.method == 'PATCH') {
          return http.Response(jsonEncode({'approved': true}), 200);
        }
        if (request.url.path == '/api/social/clubs/31') {
          return http.Response(
            jsonEncode({
              'club': {
                'id': 31,
                'name': 'Cebu Runners',
                'description': 'Sunday morning runs.',
                'ownerUserId': 7,
                'ownerName': 'Current Player',
                'memberCount': 1,
                'isOwner': true,
                'isMember': true,
                'isPending': false,
                'requiresJoinApproval': false,
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31/posts') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/social/users') {
          return http.Response(jsonEncode({'users': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-club-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-club-name')),
      'Cebu Runners',
    );
    await tester.enterText(
      find.byKey(const ValueKey('social-club-description')),
      'Sunday morning runs.',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-club-create-submit')),
          )
          .onPressed,
      isNull,
    );
    final logoPicker = find.byKey(const ValueKey('social-club-logo-pick'));
    await tester.ensureVisible(logoPicker);
    await tester.tap(logoPicker);
    await tester.pumpAndSettle();
    expect(_TestImagePickerPlatform.imagePickCalls, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-club-create-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('social-club-create-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Cebu Runners'), findsNWidgets(2));
    expect(find.text('You created this club.'), findsOneWidget);
    expect(find.byKey(const ValueKey('social-club-post')), findsOneWidget);
    expect(find.text('1 member'), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    final createRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/social/clubs' && request.method == 'POST',
    );
    expect(jsonDecode(createRequest.body), {
      'name': 'Cebu Runners',
      'description': 'Sunday morning runs.',
      'logoImage': 'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-68',
    });

    await tester.tap(find.byKey(const ValueKey('social-club-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('social-club-settings-dialog')),
      findsOneWidget,
    );
    expect(find.text('New Member'), findsOneWidget);
    final approveRequest = find.byKey(
      const ValueKey('social-club-request-approve-9'),
    );
    await tester.ensureVisible(approveRequest);
    await tester.tap(approveRequest);
    await tester.pumpAndSettle();
    expect(find.text('New Member'), findsNothing);
    final approvalSetting = find.byKey(
      const ValueKey('social-club-require-approval'),
    );
    await tester.ensureVisible(approvalSetting);
    await tester.tap(approvalSetting);
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path == '/api/social/clubs/31/settings',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path == '/api/social/clubs/31/join-requests/9' &&
            jsonDecode(request.body)['action'] == 'approve',
      ),
      isTrue,
    );
  });

  testWidgets('users create a public club, join for free, and post in its page', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var isMember = false;
    final posts = <Map<String, dynamic>>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/uploads' &&
            request.method == 'POST') {
          final size = (jsonDecode(request.body) as Map)['size'];
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://storage.googleapis.com/test-bucket/upload',
              'key':
                  'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-$size',
              'headers': {'Content-Type': 'image/png'},
            }),
            201,
          );
        }
        if (request.method == 'PUT') return http.Response('', 200);
        if (request.url.path == '/api/social/clubs' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'clubs': [
                {
                  'id': 31,
                  'name': 'Weekend Badminton',
                  'description': 'Play together in Cebu.',
                  'ownerUserId': 42,
                  'ownerName': 'Alex Player',
                  'memberCount': isMember ? 2 : 1,
                  'isOwner': false,
                  'isMember': isMember,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'club': {
                'id': 31,
                'name': 'Weekend Badminton',
                'description': 'Play together in Cebu.',
                'ownerUserId': 42,
                'ownerName': 'Alex Player',
                'memberCount': isMember ? 2 : 1,
                'isOwner': false,
                'isMember': isMember,
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31/posts') {
          return http.Response(
            jsonEncode({'posts': posts, 'hasMore': false}),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31/join') {
          isMember = true;
          return http.Response(jsonEncode({'isMember': true}), 200);
        }
        if (request.url.path == '/api/social/posts' &&
            request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          posts.add({
            'id': 77,
            'userId': 7,
            'displayName': 'Current Player',
            'caption': body['caption'],
            'images': [],
            'createdAt': DateTime.now().toIso8601String(),
          });
          return http.Response(jsonEncode({'id': 77}), 201);
        }
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/social/users') {
          return http.Response(jsonEncode({'users': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Play together. Join a club for free.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-club-31')));
    await tester.pumpAndSettle();

    expect(find.text('Weekend Badminton'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('social-club-join')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('social-club-post')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('social-club-post')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-club-post-submit')),
          )
          .onPressed,
      isNull,
    );
    final postPhotoPicker = find.byKey(
      const ValueKey('social-club-post-pick-photo'),
    );
    await tester.ensureVisible(postPhotoPicker);
    await tester.tap(postPhotoPicker);
    await tester.pumpAndSettle();
    expect(_TestImagePickerPlatform.multiImagePickCalls, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-club-post-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('social-club-post-caption')),
      'Saturday practice at 9!',
    );
    await tester.tap(find.byKey(const ValueKey('social-club-post-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Saturday practice at 9!'), findsOneWidget);
    final postRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/social/posts' && request.method == 'POST',
    );
    expect(jsonDecode(postRequest.body), {
      'caption': 'Saturday practice at 9!',
      'images': [
        'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-68',
      ],
      'clubId': 31,
    });
    expect(tester.takeException(), isNull);
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
    expect(find.text('Clubs'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
    await tester.pumpAndSettle();
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

  testWidgets('community feed appends older posts while scrolling', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/feed') {
          final cursor = request.url.queryParameters['before_id'];
          return http.Response(
            jsonEncode(
              cursor == null
                  ? {
                      'posts': List.generate(
                        20,
                        (index) => {
                          'id': 100 - index,
                          'userId': 42,
                          'displayName': 'Alex Player',
                          'caption': 'Post $index',
                          'images': [],
                          'createdAt': '2026-10-26T08:00:00.000Z',
                        },
                      ),
                      'hasMore': true,
                      'nextCursor': 81,
                    }
                  : {
                      'posts': [
                        {
                          'id': 80,
                          'userId': 42,
                          'displayName': 'Alex Player',
                          'caption': 'Older post',
                          'images': [],
                          'createdAt': '2026-10-25T08:00:00.000Z',
                        },
                      ],
                      'hasMore': false,
                      'nextCursor': null,
                    },
            ),
            200,
          );
        }
        if (request.url.path == '/api/social/users') {
          return http.Response(jsonEncode({'users': []}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SocialCommunityPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('social-community-feed-list')),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Older post'), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/social/feed' &&
            request.url.queryParameters['before_id'] == '81',
      ),
      isTrue,
    );
  });

  testWidgets('guests can browse posts without opening another profile', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
    await tester.pumpAndSettle();

    expect(find.text('Public match'), findsOneWidget);
    await tester.tap(find.text('Alex Player').first);
    await tester.pumpAndSettle();
    expect(find.text('Community'), findsOneWidget);
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/social/users/42')),
    );

    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('Log in to continue'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
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
  });

  testWidgets('experience cards support likes, comments, and saves', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final openedProfiles = <int>[];
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
          return http.Response(
            jsonEncode({
              'comments': [
                {
                  'id': 11,
                  'userId': 88,
                  'displayName': 'Jamie Reviewer',
                  'avatarUrl': null,
                  'text': 'Well played!',
                  'createdAt': DateTime.now()
                      .toUtc()
                      .subtract(const Duration(minutes: 1, seconds: 5))
                      .toIso8601String(),
                  'reactionCount': 0,
                  'reactedByMe': false,
                  'replies': [
                    {
                      'id': 12,
                      'userId': 89,
                      'displayName': 'Alex Replier',
                      'avatarUrl': null,
                      'text': 'Thanks!',
                      'createdAt': DateTime.now()
                          .toUtc()
                          .subtract(const Duration(minutes: 2))
                          .toIso8601String(),
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/posts/5/comments' &&
            request.method == 'POST') {
          commentCount++;
          return http.Response(jsonEncode({'id': 11}), 201);
        }
        if (request.url.path == '/api/social/posts/5/comments/11/reactions' ||
            request.url.path == '/api/social/posts/5/comments/11/replies') {
          return http.Response('{}', 201);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SocialCommunityPage(
          api: api,
          onOpenProfile: (userId) async => openedProfiles.add(userId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-community-feed-tab')));
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
    expect(find.text('1 min ago'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-comment-avatar-88')));
    await tester.pumpAndSettle();
    expect(openedProfiles, [88]);
    await tester.tap(
      find.byKey(const ValueKey('social-comment-reply-avatar-89')),
    );
    await tester.pumpAndSettle();
    expect(openedProfiles, [88, 89]);
    await tester.tap(find.byKey(const ValueKey('social-comment-react-11')));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/posts/5/comments/11/reactions',
      ),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('social-comment-reply-11')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-comment-reply-input-11')),
      'Thanks!',
    );
    await tester.tap(
      find.byKey(const ValueKey('social-comment-reply-send-11')),
    );
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/social/posts/5/comments/11/replies',
      ),
      isTrue,
    );
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

  testWidgets('home feed cards surface linked sports context without generic posts', (
    tester,
  ) async {
    final post = {
      'id': 42,
      'userId': 7,
      'displayName': 'Court Crew',
      'caption': 'Game night at the courts.',
      'images': ['https://example.test/landscape-post.jpg'],
      'createdAt': '2026-10-26T08:00:00.000Z',
      'sportType': 'Basketball',
      'businessName': 'Northside Courts',
      'location': 'Cebu City',
      'matchId': 99,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialExperiencePostCard(
            post: post,
            onOpenPerson: null,
            onFollow: null,
            homeFeedStyle: true,
          ),
        ),
      ),
    );

    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Northside Courts'), findsOneWidget);
    expect(find.text('Cebu City'), findsOneWidget);
    expect(find.text('View match'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialExperiencePostCard(
            post: {
              'id': 11,
              'userId': 4,
              'displayName': 'Solo Player',
              'caption': 'Just a normal day at the park.',
              'images': ['https://example.test/square-post.jpg'],
              'createdAt': '2026-10-26T08:00:00.000Z',
            },
            onOpenPerson: null,
            onFollow: null,
            homeFeedStyle: true,
          ),
        ),
      ),
    );

    expect(find.text('Basketball'), findsNothing);
    expect(find.text('View match'), findsNothing);
  });

  testWidgets('users can delete their own post from the options menu', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/posts/35' &&
            request.method == 'DELETE') {
          return http.Response(jsonEncode({'deleted': true}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    var postExists = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: postExists
                ? SocialExperiencePostCard(
                    post: {
                      'id': 35,
                      'userId': 7,
                      'isOwnPost': true,
                      'displayName': 'Current Player',
                      'caption': 'My own post',
                      'images': [],
                      'createdAt': '2026-10-26T08:00:00.000Z',
                    },
                    onOpenPerson: null,
                    onFollow: null,
                    api: api,
                    token: 'social-test-token',
                    homeFeedStyle: true,
                    onPostChanged: () => setState(() => postExists = false),
                  )
                : const Text('Post removed'),
          ),
        ),
      ),
    );
    expect(find.text('My own post'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('social-post-options-35')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete post?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('social-post-delete-confirm-35')),
    );
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/api/social/posts/35',
      ),
      isTrue,
    );
    expect(find.text('Post removed'), findsOneWidget);
    expect(find.text('Post deleted.'), findsOneWidget);
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
            'posts': [
              {
                'id': 12,
                'caption': 'A great game',
                'images': [],
                'likeCount': 18,
                'commentCount': 6,
              },
            ],
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
      find.byKey(const ValueKey('social-profile-post-12')),
      findsOneWidget,
    );
    expect(find.text('18'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
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

class _TestImagePickerPlatform extends ImagePickerPlatform {
  static int imagePickCalls = 0;
  static int multiImagePickCalls = 0;

  static final _image = XFile.fromData(
    Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1f,
      0x15,
      0xc4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0b,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9c,
      0x63,
      0x60,
      0x00,
      0x02,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0xa5,
      0xf6,
      0x45,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4e,
      0x44,
      0xae,
      0x42,
      0x60,
      0x82,
    ]),
    path: 'club.png',
    name: 'club.png',
  );

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    imagePickCalls++;
    return _image;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiImagePickCalls++;
    return [_image];
  }
}
