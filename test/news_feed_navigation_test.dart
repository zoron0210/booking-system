import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/all_venues_page.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/features/social/presentation/social_home_palette.dart';
import 'package:myapp/customer_bookings_page.dart';
import 'package:myapp/event_dashboard.dart';
import 'package:myapp/fitness_dashboard.dart';
import 'package:myapp/messages_dashboard.dart';
import 'package:myapp/news_feed.dart';
import 'package:myapp/profile_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final venues = [
    {
      'businessId': 42,
      'businessName': 'Basketball court',
      'businessType': 'Sports',
      'category': 'Basketball',
      'address': 'Cebu City',
      'facilityType': 'Indoor',
      'pricePerHour': 200,
      'enabled': true,
      'reviewCount': 5,
      'averageRating': 4.6,
      'heartCount': 9,
      'heartedByMe': false,
      'availableSlots': ['9:00 AM', '10:00 AM'],
      'title': 'Basketball news',
      'body': 'Court updates',
    },
    {
      'businessId': 43,
      'businessName': 'Tennis court',
      'businessType': 'Sports',
      'category': 'Tennis',
      'address': 'Manila',
      'facilityType': 'Outdoor',
      'pricePerHour': 500,
      'enabled': true,
      'reviewCount': 2,
      'averageRating': 4.9,
      'heartCount': 2,
      'heartedByMe': false,
      'title': 'Tennis news',
      'body': 'Court updates',
    },
  ];

  AuthApi api({List<Map<String, dynamic>>? feedPosts}) => AuthApi(
    client: MockClient((request) async {
      if (request.url.path == '/api/news-feed') {
        return http.Response(
          jsonEncode({'posts': feedPosts ?? venues}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/businesses') {
        return http.Response(
          jsonEncode({
            'businesses': [
              {'id': 42, 'enabled': true},
              {'id': 43, 'enabled': true},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
  });

  testWidgets('venue cards keep compact tablet proportions', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    final miniCard = find.byKey(
      const ValueKey('news-feed-most-popular-card-business-42'),
    );
    expect(tester.getSize(miniCard).width, greaterThan(280));
    expect(tester.getSize(miniCard).width, lessThanOrEqualTo(1024));

    final feed = find.byKey(const ValueKey('news-feed-content-list'));
    await tester.drag(feed, const Offset(0, -1000));
    await tester.pumpAndSettle();
    final largeCard = find.byKey(const ValueKey('news-feed-card-business-42'));
    expect(tester.getSize(largeCard).width, lessThanOrEqualTo(1024));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('news-feed-image-business-42')))
          .height,
      174,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer Home shows all public experience posts', (
    tester,
  ) async {
    final feedRequests = <http.Request>[];
    final homeApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/feed') {
          feedRequests.add(request);
          final following = request.url.queryParameters['scope'] == 'following';
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': following ? 16 : 15,
                  'userId': following ? 43 : 42,
                  'displayName': following ? 'Taylor Player' : 'Alex Player',
                  'caption': following
                      ? 'A followed player experience'
                      : 'A match-day experience',
                  'images': [],
                  'createdAt': '2026-10-26T08:00:00.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pumpAndSettle();

    expect(find.text('Home').first, findsOneWidget);
    expect(find.text('A match-day experience'), findsOneWidget);
    expect(
      feedRequests.map((request) => request.url.queryParameters['scope']),
      containsAll(['public', 'following']),
    );
    expect(
      feedRequests.every(
        (request) => request.headers['Authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
    expect(find.byKey(const ValueKey('customer-nav-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-home-add')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('A followed player experience'), findsOneWidget);
  });

  testWidgets('customer Home adapts its header and surfaces to theme mode', (
    tester,
  ) async {
    final homeApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: CustomerHomePage(api: homeApi),
      ),
    );
    await tester.pumpAndSettle();

    var scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    var appBarTheme = Theme.of(tester.element(find.byType(AppBar).first))
        .appBarTheme;
    expect(appBarTheme.backgroundColor, const Color(0xFFEEF1F7));
    expect(appBarTheme.foregroundColor, const Color(0xFF182238));
    expect(scaffold.backgroundColor, const Color(0xFFF5F6FA));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CustomerHomePage(api: homeApi),
      ),
    );
    await tester.pumpAndSettle();

    scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    appBarTheme = Theme.of(tester.element(find.byType(AppBar).first))
        .appBarTheme;
    expect(appBarTheme.backgroundColor, SocialHomePalette.surfaceRaised);
    expect(appBarTheme.foregroundColor, SocialHomePalette.text);
    expect(scaffold.backgroundColor, SocialHomePalette.canvas);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home experience photos open and post menu supports save and report',
    (tester) async {
      final requests = <http.Request>[];
      var isSaved = false;
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/social/feed') {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'id': 77,
                    'userId': 42,
                    'displayName': 'Alex Player',
                    'caption': 'A full-frame experience',
                    'images': [
                      'data:image/png;base64,'
                          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0L8AAAAASUVORK5CYII=',
                    ],
                    'createdAt': '2026-10-26T08:00:00.000Z',
                    'likeCount': 3,
                    'commentCount': 2,
                    'isSaved': isSaved,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/social/posts/77/saves') {
            isSaved = request.method == 'POST';
            return http.Response('{}', 200);
          }
          if (request.url.path == '/api/social/posts/77/reports') {
            return http.Response(jsonEncode({'reported': true}), 201);
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: api)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('social-post-image-77')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('social-post-image-77')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-post-image-viewer-77')),
        findsOneWidget,
      );
      final viewerImage = find.descendant(
        of: find.byKey(const ValueKey('social-post-image-viewer-77')),
        matching: find.byType(Image),
      );
      expect(tester.widget<Image>(viewerImage).fit, BoxFit.contain);
      await tester.tap(
        find.byKey(const ValueKey('social-post-image-viewer-back')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('social-post-options-77')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('social-post-options-77')));
      await tester.pumpAndSettle();
      expect(find.text('View profile'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (request) =>
              request.url.path == '/api/social/posts/77/saves' &&
              request.method == 'POST',
        ),
        isTrue,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('social-post-options-77')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('social-post-options-77')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (request) =>
              request.url.path == '/api/social/posts/77/reports' &&
              jsonDecode(request.body)['reason'] == 'spam',
        ),
        isTrue,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home share sends an experience through in-app messages', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': 77,
                  'userId': 42,
                  'displayName': 'Alex Player',
                  'caption': 'A shared experience',
                  'images': [],
                  'createdAt': '2026-10-26T08:00:00.000Z',
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
                {'id': 31, 'displayName': 'Morgan User'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversationId': 88}), 201);
        }
        if (request.url.path == '/api/messages/conversations/88') {
          return http.Response('{}', 201);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('social-post-share-77')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-post-share-77')));
    await tester.pumpAndSettle();

    expect(find.text('Share experience'), findsOneWidget);
    expect(find.text('Morgan User'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-share-user-31')));
    await tester.pumpAndSettle();

    final sharedMessage = requests.singleWhere(
      (request) => request.url.path == '/api/messages/conversations/88',
    );
    expect(
      jsonDecode(sharedMessage.body)['body'],
      contains('A shared experience'),
    );
    expect(jsonDecode(sharedMessage.body)['body'], contains('SpotGo post #77'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping another Home post author opens a public dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final homeApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/social/feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': 51,
                  'userId': 42,
                  'displayName': 'Alex Player',
                  'caption': 'A public experience',
                  'images': [],
                  'createdAt': '2026-10-26T08:00:00.000Z',
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
                'followingCount': 5,
                'isFollowing': false,
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

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Player').last);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomePage), findsNothing);
    expect(find.byType(ProfileDashboardPage), findsNothing);
    expect(
      find.byKey(const ValueKey('public-user-profile-page')),
      findsOneWidget,
    );
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('History'), findsNothing);
    expect(requests, contains('/api/social/users/42'));
  });

  testWidgets('tapping your own Home post opens your profile dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    final requests = <String>[];
    final homeApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/social/feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': 51,
                  'userId': 42,
                  'displayName': 'Alex Player',
                  'caption': 'My experience',
                  'images': [],
                  'createdAt': '2026-10-26T08:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 42,
                'role': 'customer',
                'firstName': 'Alex',
                'lastName': 'Player',
                'email': 'alex@example.test',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Player').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProfileDashboardPage), findsOneWidget);
    expect(requests, contains('/api/auth/me'));
    expect(
      find.byKey(const ValueKey('public-user-profile-dialog')),
      findsNothing,
    );
  });

  testWidgets('tapping the Home profile icon opens the owner dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final homeApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-home-own-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileDashboardPage), findsOneWidget);
  });

  testWidgets('Home Profile opens the original profile dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final homeApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('news-feed-nav-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileDashboardPage), findsOneWidget);
    expect(find.text('Player Profile'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(requests, isNot(contains('/api/auth/me')));
    expect(requests, isNot(contains('/api/social/users/42')));
  });

  testWidgets('customer Home shows skeletons then an actionable empty state', (
    tester,
  ) async {
    final publicFeed = Completer<http.Response>();
    final homeApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/social/feed' &&
            request.url.queryParameters['scope'] == 'public') {
          return publicFeed.future;
        }
        if (request.url.path == '/api/social/feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerHomePage(api: homeApi)));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('customer-home-feed-skeleton')),
      findsOneWidget,
    );

    publicFeed.complete(http.Response(jsonEncode({'posts': []}), 200));
    await tester.pumpAndSettle();
    expect(find.text('No experiences yet.'), findsOneWidget);
    expect(find.text('Explore sports venues'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(
      find.text('People you follow haven’t shared experiences yet.'),
      findsOneWidget,
    );
    expect(find.text('Browse For You'), findsOneWidget);
  });

  testWidgets(
    'Home add opens the experience composer without opening Community',
    (tester) async {
      final postRequests = <http.Request>[];
      final homeApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/social/feed') {
            return http.Response(jsonEncode({'posts': []}), 200);
          }
          if (request.url.path == '/api/social/posts' &&
              request.method == 'POST') {
            postRequests.add(request);
            return http.Response(jsonEncode({'id': 88}), 201);
          }
          return http.Response('{}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerHomePage(api: homeApi)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-home-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('social-post-caption')), findsOneWidget);
      expect(find.text('Community'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('social-post-caption')),
        'Great match!',
      );
      await tester.tap(find.byKey(const ValueKey('social-post-submit')));
      await tester.pumpAndSettle();
      expect(postRequests, hasLength(1));
      expect(jsonDecode(postRequests.single.body)['caption'], 'Great match!');
    },
  );

  testWidgets('News Feed and Saved skeletons fit a narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> verifyLoadingSkeleton({required bool savedOnly}) async {
      final delayedFeed = Completer<http.Response>();
      final loadingApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') return delayedFeed.future;
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({'businesses': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/customer/venue-hearts') {
            return http.Response('{}', 404);
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewsFeedPage(api: loadingApi, savedOnly: savedOnly),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('news-feed-loading-skeleton')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      delayedFeed.complete(
        http.Response(
          jsonEncode({'posts': []}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }

    await verifyLoadingSkeleton(savedOnly: false);
    await verifyLoadingSkeleton(savedOnly: true);
  });

  testWidgets('news feed connection failures show backend retry guidance', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          throw http.ClientException('Connection refused');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({'businesses': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We couldn’t reach the service. Check your Wi-Fi connection and make sure the app backend is running, then try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('192.168.1.18'), findsNothing);
    expect(find.byKey(const ValueKey('news-feed-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('News Feed filters open from the right and show active count', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Filter venues'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('filter-panel-surface'))).width,
      440,
    );
    expect(tester.widget<Text>(find.text('Filter venues')).style?.fontSize, 20);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('filter-panel-surface')),
        matching: find.text('SPORT TYPE'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-Basketball')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('news-feed-filter-sport-Basketball')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basketball court'), findsWidgets);
    expect(find.text('Tennis court'), findsNothing);
    final filterBadge = tester.widget<Badge>(find.byType(Badge).first);
    expect(filterBadge.isLabelVisible, isTrue);
    expect(find.byTooltip('Filter venues (1 active)'), findsOneWidget);
  });

  testWidgets('sports filter includes every sport configured for a court', (
    tester,
  ) async {
    final multiSportPost = {...venues.first, 'category': 'Badminton'};
    final multiSportApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [multiSportPost],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'businessType': 'Sports',
                  'enabled': true,
                  'category': 'Badminton',
                  'sportsSlots': [
                    {'sportType': 'Badminton'},
                    {'sportType': 'Basketball'},
                    {'sportType': 'Volleyball'},
                    {'sportType': 'Pickleball'},
                    {'sportType': 'Tennis'},
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: NewsFeedPage(api: multiSportApi)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('news-feed-search')),
      'tennis',
    );
    await tester.pumpAndSettle();
    expect(find.text('Basketball court'), findsWidgets);
    expect(find.text('No courts match your search.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('news-feed-search-clear')));
    await tester.pumpAndSettle();

    for (final sport in [
      'Badminton',
      'Basketball',
      'Volleyball',
      'Pickleball',
      'Tennis',
    ]) {
      expect(
        find.byKey(ValueKey('news-feed-filter-sport-$sport')),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.byKey(const ValueKey('news-feed-filter-sport-Volleyball')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basketball court'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('News Feed price filter includes venues above 700', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedPage(
          api: api(
            feedPosts: [
              {...venues.first, 'pricePerHour': 1200},
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    final priceSlider = find.byKey(const ValueKey('news-feed-filter-price'));
    await tester.scrollUntilVisible(
      priceSlider,
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(tester.widget<Slider>(priceSlider).max, 1200);
    expect(tester.widget<Slider>(priceSlider).divisions, 24);
  });

  testWidgets('empty venue search offers a clear-search action', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('news-feed-search')),
      'no matching venue',
    );
    await tester.pumpAndSettle();
    expect(find.text('No courts match your search.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-clear-search-and-filters')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('news-feed-clear-search-and-filters')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basketball court'), findsWidgets);
    final tennisCard = find.byKey(const ValueKey('news-feed-card-business-43'));
    await tester.scrollUntilVisible(
      tennisCard,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Tennis court'), findsWidgets);
  });

  testWidgets('Event dashboard uses the shared Event-only feed cards', (
    tester,
  ) async {
    final requests = <String>[];
    final submittedReviews = <Map<String, dynamic>>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/news-feed') {
          fail('Event dashboard must not depend on the News Feed endpoint');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 88,
                  'businessType': 'Event',
                  'name': 'Cebu Event Hall',
                  'category': 'Garden',
                  'eventTypes': ['Wedding', 'Birthday'],
                  'address': 'Cebu City',
                  'facilityType': 'Garden venue',
                  'details': 'Bring your own decorations.',
                  'eventFee': 1200,
                  'enabled': true,
                  'reviewCount': 3,
                  'averageRating': 4.7,
                  'ratingUserCount': 3,
                  'heartCount': 6,
                },
                {
                  'id': 89,
                  'businessType': 'Sports',
                  'name': 'Sports Court',
                  'enabled': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'businessId': 88},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  'id': 180,
                  'venueId': 88,
                  'venueName': 'Cebu Event Hall',
                  'businessType': 'Event',
                  'eventType': 'Wedding',
                  'status': 'finished',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses/88/heart') {
          return http.Response(
            jsonEncode({
              'heartCount': request.method == 'DELETE' ? 5 : 7,
              'heartedByMe': request.method != 'DELETE',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/news-feed/88/reviews' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({'reviews': submittedReviews}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/news-feed/88/reviews' &&
            request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          submittedReviews.add({
            'id': 1,
            'customerId': 42,
            'rating': payload['rating'],
            'comment': payload['comment'],
            'firstName': 'Event',
            'lastName': 'Guest',
          });

          return http.Response(
            jsonEncode({'review': submittedReviews.last}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Event');
    expect(feed.savedItemType, 'event');
    expect(feed.pageTitle, 'Event Venues');
    expect(find.text('Find a space for your next event'), findsOneWidget);
    expect(find.text('Popular event venues'), findsOneWidget);
    expect(find.text('Most popular'), findsNothing);
    expect(find.text('Cebu Event Hall'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('EVENT TYPE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-Wedding')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('news-feed-card-business-88')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final eventListCard = find.byKey(
      const ValueKey('news-feed-card-business-88'),
    );
    await tester.ensureVisible(eventListCard);
    expect(find.text('Wedding, Birthday'), findsWidgets);
    expect(
      find.byKey(const ValueKey('news-feed-save-business-88')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('news-feed-heart-business-88')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('news-feed-reviews-business-88')),
      findsOneWidget,
    );
    expect(find.textContaining('Review'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('news-feed-heart-business-88')),
          )
          .tooltip,
      'Remove heart',
    );

    await tester.drag(
      find.byKey(const ValueKey('news-feed-content-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    final heartButton = find.byKey(
      const ValueKey('news-feed-heart-business-88'),
    );
    await tester.ensureVisible(heartButton);
    await tester.tap(heartButton);
    await tester.pumpAndSettle();
    expect(requests, contains('DELETE /api/businesses/88/heart'));
    expect(
      find.byKey(const ValueKey('news-feed-heart-count-business-88')),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(heartButton).tooltip, 'Heart venue');

    final reviewsButton = find.byKey(
      const ValueKey('news-feed-reviews-business-88'),
    );
    await tester.ensureVisible(reviewsButton);
    await tester.tap(reviewsButton);
    await tester.pumpAndSettle();
    expect(requests, contains('GET /api/news-feed/88/reviews'));
    expect(find.text('Cebu Event Hall ratings & reviews'), findsOneWidget);
    expect(
      find.text('Rate this event venue after your completed booking'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('review-rating-star-4')));
    await tester.enterText(
      find.widgetWithText(TextField, 'Comment'),
      'Great event venue.',
    );
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /api/news-feed/88/reviews'));
    expect(submittedReviews.single['rating'], 4);
    expect(submittedReviews.single['comment'], 'Great event venue.');
    Navigator.of(tester.element(find.text('Cebu Event Hall ratings & reviews')))
        .pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(eventListCard);
    await tester.tap(eventListCard);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sports-venue-content-panel')),
      findsOneWidget,
    );
    final eventContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (eventContentPanel.decoration! as BoxDecoration).boxShadow ?? const [],
      isEmpty,
    );
    expect(find.text('\u{20B1} 1200.00 / event'), findsWidgets);
    expect(find.text('Bring your own decorations.'), findsOneWidget);
    expect(find.text('Reserve event'), findsOneWidget);
    final eventTitle = tester.widget<Text>(
      find.byKey(const ValueKey('sports-venue-title')),
    );
    expect(eventTitle.style?.fontSize, 24);
    expect(eventTitle.style?.fontWeight, FontWeight.w800);

    await tester.tap(find.text('Reserve event'));
    await tester.pumpAndSettle();
    expect(find.text('Book Event'), findsOneWidget);
    expect(find.text('BOOKING CONFIGURATION'), findsOneWidget);
    expect(find.text('Request event booking'), findsNothing);
  });

  testWidgets('Event bookings return to the Event-only Explore feed', (
    tester,
  ) async {
    final requests = <String>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/news-feed') {
          fail('Event Explore must not load the sports news feed');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 91,
                  'businessType': 'Event',
                  'name': 'Cebu Event Hall',
                  'eventTypes': ['Wedding'],
                  'enabled': true,
                },
                {
                  'id': 92,
                  'businessType': 'Sports',
                  'name': 'Sports Court',
                  'enabled': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response('{}', 404);
        }
        return http.Response(
          jsonEncode({'bookings': [], 'conversations': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(api: eventApi, businessType: 'Event'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Event');
    expect(feed.savedItemType, 'event');
    expect(feed.pageTitle, 'Event Venues');
    expect(find.text('Cebu Event Hall'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(requests, isNot(contains('/api/news-feed')));
  });

  testWidgets('Fitness bookings return to a Fitness-only Explore feed', (
    tester,
  ) async {
    final requests = <Uri>[];
    final fitnessApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 101,
                  'businessName': 'Cebu Yoga Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Yoga',
                  'address': 'Cebu City',
                  'enabled': true,
                  'title': 'Yoga classes',
                  'body': 'Join a class',
                },
                {
                  'businessId': 102,
                  'businessName': 'Sports Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'address': 'Cebu City',
                  'enabled': true,
                  'title': 'Basketball news',
                  'body': 'Court updates',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 101,
                  'businessType': 'Fitness & Wellness',
                  'enabled': true,
                },
                {'id': 102, 'businessType': 'Sports', 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'bookings': [], 'conversations': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(
          api: fitnessApi,
          businessType: 'Fitness & Wellness',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(feed.pageTitle, 'Fitness & Wellness');
    expect(find.text('Cebu Yoga Studio'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(
      requests
          .where((uri) => uri.path == '/api/news-feed')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
  });

  testWidgets('Fitness messages return to a Fitness-only Explore feed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    final requests = <Uri>[];
    final fitnessApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 101,
                  'businessName': 'Cebu Yoga Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Yoga',
                  'enabled': true,
                  'title': 'Yoga classes',
                  'body': 'Join a class',
                },
                {
                  'businessId': 102,
                  'businessName': 'Sports Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'enabled': true,
                  'title': 'Basketball news',
                  'body': 'Court updates',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 101,
                  'businessType': 'Fitness & Wellness',
                  'enabled': true,
                },
                {'id': 102, 'businessType': 'Sports', 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 42},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'conversations': [], 'contacts': [], 'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesDashboardPage(
          api: fitnessApi,
          businessType: 'Fitness & Wellness',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(find.text('Cebu Yoga Studio'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(
      requests
          .where((uri) => uri.path == '/api/news-feed')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
  });

  testWidgets('Event dashboard lists event businesses without news posts', (
    tester,
  ) async {
    final requests = <String>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/news-feed') {
          fail('Event dashboard must not depend on the News Feed endpoint');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 91,
                  'name': 'Garden Event Place',
                  'businessType': 'Event',
                  'category': 'Garden',
                  'eventTypes': ['Wedding', 'Birthday'],
                  'address': 'Cebu City',
                  'eventFee': 2500,
                  'pricePerHour': 2500,
                  'enabled': true,
                  'averageRating': 0,
                  'reviewCount': 0,
                  'heartCount': 0,
                  'details': 'Outdoor venue for celebrations.',
                },
                {
                  'id': 92,
                  'name': 'Basketball Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'enabled': true,
                },
                {
                  'id': 93,
                  'name': 'Closed Event Garden',
                  'businessType': 'Event',
                  'category': 'Garden',
                  'eventTypes': ['Wedding'],
                  'address': 'Cebu City',
                  'enabled': false,
                  'eventFee': 900,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response('{}', 404);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    final feedScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('news-feed-content-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    final firstEventCard = find.byKey(
      const ValueKey('news-feed-card-business-91'),
    );
    await tester.scrollUntilVisible(
      firstEventCard,
      180,
      scrollable: feedScrollable,
    );
    await tester.ensureVisible(firstEventCard);
    expect(find.text('Garden Event Place'), findsWidgets);
    expect(find.text('Wedding, Birthday'), findsWidgets);
    final closedEventCard = find.byKey(
      const ValueKey('news-feed-card-business-93'),
    );
    await tester.scrollUntilVisible(
      closedEventCard,
      180,
      scrollable: feedScrollable,
    );
    expect(find.text('Closed Event Garden'), findsWidgets);
    expect(find.text('UNAVAILABLE · Booking disabled'), findsWidgets);
    expect(find.text('Basketball Court'), findsNothing);
    expect(find.textContaining('Could not load the news feed'), findsNothing);
    expect(find.text('No event venues match your search.'), findsNothing);
    expect(requests, contains('GET /api/businesses'));
    expect(requests, isNot(contains('GET /api/customer/event-businesses')));
    expect(requests, isNot(contains('GET /api/news-feed')));
    await tester.scrollUntilVisible(
      firstEventCard,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(firstEventCard, findsOneWidget);
    final firstEventHeart = find.byKey(
      const ValueKey('news-feed-heart-business-91'),
    );
    await tester.scrollUntilVisible(
      firstEventHeart,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(firstEventHeart, findsOneWidget);
  });

  testWidgets(
    'Event dashboard remains available when heart-state route is missing',
    (tester) async {
      final eventApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 94,
                    'name': 'Event Garden',
                    'businessType': 'Event',
                    'eventTypes': ['Wedding'],
                    'enabled': true,
                    'heartCount': 2,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/customer/venue-hearts') {
            return http.Response(
              '<!doctype html><html><body>Not Found</body></html>',
              404,
              headers: {'content-type': 'text/html'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: EventDashboardPage(api: eventApi)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Garden'), findsWidgets);
      final eventCard = find.byKey(
        const ValueKey('news-feed-card-business-94'),
      );
      await tester.scrollUntilVisible(
        eventCard,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('news-feed-content-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(eventCard, findsOneWidget);
      expect(find.textContaining('Could not load the news feed'), findsNothing);
    },
  );

  testWidgets(
    'Event popular and highest-rated lists include event fees over 700',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final eventApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 95,
                    'name': 'Grand Event Hall',
                    'businessType': 'Event',
                    'category': 'Wedding',
                    'eventTypes': ['Wedding'],
                    'eventFee': 2400,
                    'enabled': true,
                    'heartCount': 12,
                    'reviewCount': 4,
                    'averageRating': 4.8,
                    'ratingUserCount': 4,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/customer/venue-hearts') {
            return http.Response(
              jsonEncode({'businesses': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: EventDashboardPage(api: eventApi)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('news-feed-most-popular-card-business-95')),
        findsOneWidget,
      );
      for (final key in const [
        'news-feed-see-all-popular-event-venues',
        'news-feed-see-all-highest-rated',
      ]) {
        final seeAll = find.byKey(ValueKey(key));
        await tester.ensureVisible(seeAll);
        await tester.tap(seeAll);
        await tester.pumpAndSettle();

        expect(find.text('Grand Event Hall'), findsOneWidget);
        final allVenuesList = find.byKey(const ValueKey('all-venues-list'));
        expect(allVenuesList, findsOneWidget);
        expect(
          find.descendant(
            of: allVenuesList,
            matching: find.byKey(const ValueKey('news-feed-card-business-95')),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AllVenuesPage>(find.byType(AllVenuesPage))
              .priceFilterLabel,
          'Price (\u{20B1} / event)',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('venue feed cards use a featured image and compact listing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final venue = {
      ...venues.first,
      'imageUrls': [
        'https://example.com/court.jpg',
        'https://example.com/court-2.jpg',
      ],
    };
    final multiImageApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [venue],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'businessType': 'Sports',
                  'enabled': true,
                  'averageRating': 4.6,
                  'reviewCount': 5,
                  'imageUrls': venue['imageUrls'],
                  'sportsSlots': [
                    {'sportType': 'Basketball'},
                    {'sportType': 'Tennis'},
                    {'sportType': 'Volleyball'},
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: NewsFeedPage(api: multiImageApi)),
    );
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final cardKey in const [
      ValueKey('news-feed-most-popular-card-business-42'),
      ValueKey('news-feed-card-business-42'),
    ]) {
      final miniCard = find.byKey(cardKey);
      await tester.scrollUntilVisible(
        miniCard,
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('news-feed-content-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(miniCard);
      final miniImages = tester
          .widgetList<Image>(
            find.descendant(of: miniCard, matching: find.byType(Image)),
          )
          .toList();
      expect(
        miniImages.any(
          (image) =>
              image.image is NetworkImage &&
              (image.image as NetworkImage).url ==
                  'https://example.com/court.jpg',
        ),
        isTrue,
        reason: '$cardKey should display the merchant gallery image',
      );
      if (cardKey ==
          const ValueKey('news-feed-most-popular-card-business-42')) {
        final secondImageDot = find.byKey(
          const ValueKey('news-feed-featured-image-dot-business-42-1'),
        );
        expect(secondImageDot, findsOneWidget);
        await tester.tap(secondImageDot);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<Image>(
                find.descendant(of: miniCard, matching: find.byType(Image)),
              )
              .any(
                (image) =>
                    image.image is NetworkImage &&
                    (image.image as NetworkImage).url ==
                        'https://example.com/court-2.jpg',
              ),
          isTrue,
        );
      }
    }

    final card = find.byKey(const ValueKey('news-feed-card-business-42'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(
      find.descendant(of: card, matching: find.text('Basketball')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Review')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('news-feed-image-business-42')))
          .height,
      174,
    );
    expect(
      find.byKey(const ValueKey('news-feed-available-slots-business-42')),
      findsOneWidget,
    );
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Cebu City')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('\u{20B1} 200 / hr')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'location filter remains available without a Saved navigation button',
    (tester) async {
      final position = Position(
        longitude: 123.8854,
        latitude: 10.3157,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NewsFeedPage(api: api(), initialUserPosition: position),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('news-feed-nav-saved')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Using my location · nearest first'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('location remains enabled when switching to Messages and back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    final venue = {...venues.first, 'latitude': 10.3157, 'longitude': 123.8854};
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [venue],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'id': 42, 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final position = Position(
      longitude: 123.8854,
      latitude: 10.3157,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedPage(api: testApi, initialUserPosition: position),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesDashboardPage), findsOneWidget);
    expect(
      tester
          .widget<MessagesDashboardPage>(find.byType(MessagesDashboardPage))
          .initialUserPosition,
      position,
    );

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 km away'), findsWidgets);
  });

  testWidgets(
    'venue hearts update counts and determine the popular hero venue',
    (tester) async {
      String? heartMethod;
      String? heartPath;
      final heartApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({'posts': venues}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 42,
                    'businessType': 'Sports',
                    'enabled': true,
                    'averageRating': 4.6,
                    'reviewCount': 5,
                    'heartCount': 9,
                  },
                  {
                    'id': 43,
                    'businessType': 'Sports',
                    'enabled': true,
                    'averageRating': 4.9,
                    'reviewCount': 2,
                    'heartCount': 2,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          heartMethod = request.method;
          heartPath = request.url.path;
          return http.Response(
            jsonEncode({'heartCount': 10, 'heartedByMe': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: heartApi)));
      await tester.pumpAndSettle();

      final popularBasketball = find.byKey(
        const ValueKey('news-feed-most-popular-card-business-42'),
      );
      final popularTennis = find.byKey(
        const ValueKey('news-feed-most-popular-card-business-43'),
      );
      expect(popularBasketball, findsOneWidget);
      expect(popularTennis, findsNothing);
      expect(find.text('Highest rate'), findsNothing);

      final miniHeart = find
          .byKey(const ValueKey('news-feed-mini-heart-business-42'))
          .first;
      await tester.ensureVisible(miniHeart);
      await tester.tap(miniHeart);
      await tester.pumpAndSettle();

      expect(heartMethod, 'PUT');
      expect(heartPath, '/api/businesses/42/heart');
      expect(
        find.byKey(const ValueKey('news-feed-mini-heart-count-business-42')),
        findsWidgets,
      );
      expect(find.text('10'), findsWidgets);
    },
  );

  testWidgets('opened venue booking card shows location distance and hearts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final venue = {
      ...venues.first,
      'details': 'Bring your own equipments',
      'ratePeriods': [
        {'start': '3:53 PM', 'end': '5:53 AM', 'pricePerHour': 200},
      ],
      'imageUrls': [
        'https://example.com/court.jpg',
        'https://example.com/court-2.jpg',
      ],
      'imageUrl': 'https://example.com/court.jpg',
      'latitude': 10.3157,
      'longitude': 123.8854,
      'heartCount': 17,
      'heartedByMe': false,
    };
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [venue],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'enabled': true,
                  'businessType': 'Sports',
                  'pricePerHour': 200,
                  'imageUrls': [
                    'https://example.com/court.jpg',
                    'https://example.com/court-2.jpg',
                  ],
                  'latitude': 10.3157,
                  'longitude': 123.8854,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final userPosition = Position(
      longitude: 123.8854,
      latitude: 10.3157,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedPage(api: testApi, initialUserPosition: userPosition),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('news-feed-mini-business-42')).first,
    );
    await tester.pumpAndSettle();

    final heroImage = tester.getSize(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sports-venue-hero-image')),
        matching: find.byType(PageView),
      ),
      findsOneWidget,
    );
    final backButton = tester.getTopLeft(
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    );
    final saveButton = tester.getTopLeft(
      find.byIcon(Icons.bookmark_border_rounded),
    );
    final shareButton = tester.getTopLeft(find.byIcon(Icons.ios_share_rounded));
    expect(backButton.dy, greaterThanOrEqualTo(32));
    expect(saveButton.dy, greaterThanOrEqualTo(32));
    expect(shareButton.dy, greaterThanOrEqualTo(32));
    expect(
      heroImage.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(
      heroImage.height,
      closeTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.5,
        0.1,
      ),
    );
    final heroBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    final contentTop = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(contentTop.dy - heroBottom.dy, -26);
    final sportsContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (sportsContentPanel.decoration! as BoxDecoration).boxShadow ?? const [],
      isEmpty,
    );
    final imageCountBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-image-count')),
    );
    expect(contentTop.dy - imageCountBottom.dy, 18);
    expect(find.byKey(const ValueKey('sports-venue-distance')), findsOneWidget);
    expect(find.text('0.0 km away'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sports-venue-heart-count')),
      findsOneWidget,
    );
    expect(find.text('17'), findsOneWidget);
    expect(tester.widget<Text>(find.text('17')).style?.fontSize, 16);
    final ratesHeading = find.text('Rates');
    final venueDescription = find.byKey(
      const ValueKey('sports-venue-description'),
    );
    await tester.ensureVisible(venueDescription);
    expect(
      tester.getTopLeft(ratesHeading).dy,
      lessThan(tester.getTopLeft(venueDescription).dy),
    );
    expect(find.text('Bring your own equipments'), findsOneWidget);
    final venueTitle = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-title')),
    );
    final heartCount = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-heart-count')),
    );
    expect((venueTitle.dy - heartCount.dy).abs(), lessThan(8));
  });

  testWidgets('Fitness venue route opens its configured booking plans', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final post = {
      'businessId': 77,
      'businessName': 'Yoga Studio',
      'businessType': 'Fitness & Wellness',
      'category': 'Yoga',
      'address': 'Cebu City',
      'facilityType': 'Fitness Studio',
      'hours': '7:00 AM - 9:00 PM',
      'availability': 'Open daily',
      'details': 'Yoga studio with beginner and advanced classes.',
      'tags': ['Parking', 'Changing room'],
      'imageUrls': [
        'https://example.com/yoga-studio.jpg',
        'https://example.com/yoga-studio-2.jpg',
      ],
      'ownerName': 'Alex Merchant',
      'enabled': true,
      'title': 'Yoga classes now open',
      'body': 'Book a visit',
    };
    final business = {
      'id': 77,
      'name': 'Yoga Studio',
      'businessType': 'Fitness & Wellness',
      'category': 'Yoga',
      'address': 'Cebu City',
      'facilityType': 'Fitness Studio',
      'hours': '7:00 AM - 9:00 PM',
      'availability': 'Open daily',
      'details': 'Yoga studio with beginner and advanced classes.',
      'tags': ['Parking', 'Changing room'],
      'ownerName': 'Alex Merchant',
      'enabled': true,
      'fitnessCategories': [
        {
          'category': 'Yoga',
          'sessionPrice': 500,
          'monthlyPrice': 1200,
          'yearlyPrice': 12000,
          'yearlyDiscountType': 'none',
        },
      ],
      'fitnessCoaches': <Map<String, dynamic>>[],
    };
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [post],
            }),
            200,
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [business],
            }),
            200,
          );
        }
        if (request.url.path == '/api/bookings/availability') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: FitnessDashboardPage(api: testApi)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yoga Studio'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('news-feed-mini-business-77')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sports-venue-title')), findsOneWidget);
    final heroImage = tester.getSize(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(
      heroImage.height,
      closeTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.5,
        0.1,
      ),
    );
    final contentTop = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    final heroBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(contentTop.dy - heroBottom.dy, -26);
    final fitnessContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (fitnessContentPanel.decoration! as BoxDecoration).boxShadow ?? const [],
      isEmpty,
    );
    for (final control in [
      Icons.arrow_back_ios_new_rounded,
      Icons.bookmark_border_rounded,
      Icons.ios_share_rounded,
    ]) {
      expect(
        tester.getTopLeft(find.byIcon(control)).dy,
        greaterThanOrEqualTo(32),
      );
    }
    final imageCountBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-image-count')),
    );
    expect(contentTop.dy - imageCountBottom.dy, 18);
    expect(find.text('Yoga Studio'), findsOneWidget);
    expect(find.text('Cebu City'), findsWidgets);
    expect(find.text('7:00 AM - 9:00 PM'), findsOneWidget);
    expect(find.text('Open daily'), findsOneWidget);
    expect(find.text('FITNESS AMENITIES'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00 / session'), findsWidgets);
    expect(find.text('Hosted by merchant'), findsOneWidget);
    expect(find.text('Alex Merchant'), findsOneWidget);

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    expect(find.text('Book Fitness'), findsOneWidget);
    expect(find.text('FITNESS CONFIGURATION'), findsOneWidget);
    expect(
      find.textContaining('Full-day session · \u{20B1} 500.00'),
      findsOneWidget,
    );
  });

  testWidgets('See all slides in from the right and reverses in equal time', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: NewsFeedPage(api: api()),
      ),
    );
    await tester.pumpAndSettle();

    final seeAll = find.byKey(const ValueKey('news-feed-see-all-most-popular'));
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byType(AllVenuesPage), findsOneWidget);
    final route = observer.lastPushedRoute! as PageRoute<void>;
    expect(route, isA<PageRouteBuilder<void>>());
    expect(route.transitionDuration, const Duration(milliseconds: 320));
    expect(route.reverseTransitionDuration, route.transitionDuration);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sports Courts'), findsOneWidget);
  });

  testWidgets('booking type changes reload an isolated home feed', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          final businessType = request.url.queryParameters['businessType'];
          final post = businessType == 'Fitness'
              ? {
                  'businessId': 77,
                  'businessName': 'Fitness Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Yoga',
                  'enabled': true,
                  'title': 'Yoga classes',
                  'body': 'Book a session',
                }
              : {
                  'businessId': 42,
                  'businessName': 'Basketball Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'enabled': true,
                  'title': 'Basketball court updates',
                  'body': 'Book court time',
                };
          return http.Response(
            jsonEncode({
              'posts': [post],
            }),
            200,
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'businessType': 'Sports',
                  'name': 'Basketball Court',
                  'enabled': true,
                },
                {
                  'id': 77,
                  'businessType': 'Fitness & Wellness',
                  'name': 'Fitness Studio',
                  'enabled': true,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    var businessType = 'Sports';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Stack(
            fit: StackFit.expand,
            children: [
              NewsFeedPage(
                api: api,
                businessType: businessType,
                pageTitle: businessType == 'Sports'
                    ? 'Sports Courts'
                    : 'Fitness & Wellness',
                savedItemType: businessType == 'Sports' ? 'sports' : 'fitness',
              ),
              Positioned(
                top: 72,
                left: 16,
                child: TextButton(
                  key: const ValueKey('switch-booking-type'),
                  onPressed: () => setState(() => businessType = 'Fitness'),
                  child: const Text('Switch to Fitness'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Basketball Court'), findsWidgets);
    expect(
      find.byKey(const ValueKey('news-feed-sport-filter-bar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('switch-booking-type')));
    await tester.pumpAndSettle();

    expect(find.text('Fitness & Wellness'), findsOneWidget);
    expect(find.text('Fitness Studio'), findsWidgets);
    expect(find.text('Basketball Court'), findsNothing);
    expect(
      find.byKey(const ValueKey('news-feed-booking-type-intro-fitness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('news-feed-sport-filter-bar')),
      findsNothing,
    );
  });

  testWidgets('Sports Venue discovery uses the redesigned layout', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    expect(find.text('SpotGo'), findsOneWidget);
    expect(find.text('Sports Courts'), findsOneWidget);
    expect(find.text('Most popular'), findsOneWidget);
    expect(find.text('Highest rate'), findsNothing);
    expect(find.text('Available today'), findsOneWidget);
    expect(find.text('4.5+'), findsOneWidget);
    expect(find.text('Indoor / AC'), findsOneWidget);
    expect(find.text('Instant book'), findsNothing);
    expect(
      find.byKey(const ValueKey('news-feed-featured-save-business-42')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('news-feed-view-on-map')), findsNothing);
    expect(tester.widget<Text>(find.text('Sports Courts')).style?.fontSize, 11);
    expect(tester.widget<Text>(find.text('Most popular')).style?.fontSize, 16);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('news-feed-search-container')),
          )
          .padding,
      const EdgeInsets.fromLTRB(16, 12, 16, 2),
    );
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('news-feed-content-list')),
          )
          .padding!
          .resolve(TextDirection.ltr)
          .top,
      8,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('news-feed-most-popular-card-business-42'),
                ),
              )
              .dy -
          tester.getBottomLeft(find.text('Most popular')).dy,
      6,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFFF5F6FA),
    );
    await tester.tap(
      find.byKey(const ValueKey('news-feed-quick-filter-indoor')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Basketball court'), findsWidgets);
    expect(find.text('Tennis court'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('news-feed-filter-amenity-Indoor / AC')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('news-feed-quick-filter-indoor')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('news-feed-search')),
      'no venue has this name',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('news-feed-quick-filters')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('news-feed-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('news-feed-section-info-most-popular')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Most hearts from users'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('All listed courts'),
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('All listed courts'), findsOneWidget);

    final sportFilterBar = find.byKey(
      const ValueKey('news-feed-sport-filter-bar'),
    );
    final searchBar = find.byKey(const ValueKey('news-feed-search-container'));
    expect(sportFilterBar, findsOneWidget);
    expect(
      tester.getTopLeft(sportFilterBar).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(searchBar).dy),
    );
    expect(
      find.descendant(of: sportFilterBar, matching: find.text('SPORT TYPE')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('filter-panel-surface')),
        matching: find.text('SPORT TYPE'),
      ),
      findsNothing,
    );
    expect(find.text('COURT TYPE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-All sports')),
      findsOneWidget,
    );
  });

  testWidgets('venue discovery adapts to light and dark app modes', (
    tester,
  ) async {
    await AppPreferences.instance.update(darkMode: false);
    addTearDown(() => AppPreferences.instance.update(darkMode: false));

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppPreferences.instance,
        builder: (context, _) => MaterialApp(
          theme: ThemeData(
            brightness: AppPreferences.instance.darkMode
                ? Brightness.dark
                : Brightness.light,
          ),
          home: NewsFeedPage(api: api()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    var appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    var search = tester.widget<TextField>(
      find.byKey(const ValueKey('news-feed-search')),
    );
    var navigationTheme = Theme.of(tester.element(find.byType(NavigationBar)))
        .navigationBarTheme;
    expect(scaffold.backgroundColor, const Color(0xFFF5F6FA));
    expect(appBar.backgroundColor, const Color(0xFFF5F6FA));
    expect(appBar.foregroundColor, const Color(0xFF182238));
    expect(search.decoration!.fillColor, Colors.white);
    expect(navigationTheme.backgroundColor, Colors.white);
    expect(navigationTheme.indicatorColor, const Color(0xFFE7E6FF));

    await AppPreferences.instance.update(darkMode: true);
    await tester.pumpAndSettle();

    scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    search = tester.widget<TextField>(
      find.byKey(const ValueKey('news-feed-search')),
    );
    navigationTheme = Theme.of(tester.element(find.byType(NavigationBar)))
        .navigationBarTheme;
    expect(scaffold.backgroundColor, const Color(0xFF0B1326));
    expect(appBar.backgroundColor, const Color(0xFF0B1326));
    expect(appBar.foregroundColor, const Color(0xFFF4F3FF));
    expect(search.decoration!.fillColor, const Color(0xFF131B2E));
    expect(navigationTheme.backgroundColor, const Color(0xFF131B2E));
    expect(navigationTheme.indicatorColor, const Color(0xFF3935A8));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Fitness discovery filters by business type, maps real venues, and reuses feed filters',
    (tester) async {
      final fitnessPosts = [
        {
          'businessId': 71,
          'businessName': 'Pilates Studio',
          'businessType': 'Fitness & Wellness',
          'category': 'Pilates',
          'address': 'Cebu City',
          'facilityType': 'Indoor',
          'pricePerHour': 450,
          'enabled': true,
          'reviewCount': 5,
          'averageRating': 4.8,
          'heartCount': 3,
          'heartedByMe': false,
          'title': 'New reformer classes',
          'body': 'Try a new class this week.',
          'latitude': 10.325,
          'longitude': 123.901,
        },
        {
          'businessId': 72,
          'businessName': 'Yoga Wellness',
          'businessType': 'Wellness',
          'category': 'Yoga',
          'address': 'Mandaue City',
          'facilityType': 'Studio',
          'pricePerHour': 300,
          'enabled': true,
          'reviewCount': 2,
          'averageRating': 4.6,
          'heartCount': 1,
          'heartedByMe': false,
          'title': 'Morning yoga',
          'body': 'Join the sunrise session.',
          'latitude': 10.333,
          'longitude': 123.912,
        },
        {
          ...venues.first,
          'businessId': 73,
          'businessName': 'Basketball court',
          'businessType': 'Sports',
        },
      ];
      String? heartRequestMethod;
      final fitnessApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({'posts': fitnessPosts}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 71,
                    'name': 'Pilates Studio',
                    'businessType': 'Fitness & Wellness',
                    'category': 'Pilates',
                    'address': 'Cebu City',
                    'pricePerHour': 450,
                    'averageRating': 4.8,
                    'enabled': true,
                    'latitude': 10.325,
                    'longitude': 123.901,
                  },
                  {
                    'id': 72,
                    'name': 'Yoga Wellness',
                    'businessType': 'Wellness',
                    'category': 'Yoga',
                    'address': 'Mandaue City',
                    'pricePerHour': 300,
                    'averageRating': 4.6,
                    'enabled': true,
                    'latitude': 10.333,
                    'longitude': 123.912,
                  },
                  {
                    'id': 73,
                    'name': 'Basketball court',
                    'businessType': 'Sports',
                    'enabled': true,
                    'latitude': 10.3157,
                    'longitude': 123.8854,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses/71/heart') {
            heartRequestMethod = request.method;
            return http.Response(
              jsonEncode({'heartCount': 4, 'heartedByMe': true}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final customerPosition = Position(
        longitude: 123.89,
        latitude: 10.31,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitnessDashboardPage(
            api: fitnessApi,
            initialUserPosition: customerPosition,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
      expect(feed.businessType, 'Fitness');
      expect(feed.savedItemType, 'fitness');
      expect(feed.savedOnly, isFalse);
      expect(find.text('Fitness & Wellness'), findsOneWidget);
      expect(find.text('Find a space for your next workout'), findsOneWidget);
      expect(find.text('Popular fitness spaces'), findsOneWidget);
      expect(find.text('Most popular'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Highest rated'),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('news-feed-content-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Highest rated'), findsOneWidget);
      final highestRatedCard = find.byKey(
        const ValueKey('news-feed-highest-rated-card-business-71'),
      );
      await tester.scrollUntilVisible(
        highestRatedCard,
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(highestRatedCard, findsOneWidget);
      expect(
        find.descendant(
          of: highestRatedCard,
          matching: find.byKey(
            const ValueKey('news-feed-highest-rated-book-business-71'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Pilates Studio'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Yoga Wellness'),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('news-feed-highest-rated-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Yoga Wellness'), findsWidgets);
      expect(find.text('Basketball court'), findsNothing);

      expect(find.byKey(const ValueKey('news-feed-nav-saved')), findsNothing);

      await tester.scrollUntilVisible(
        find.text('All venues'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('All venues'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('news-feed-toggle-court-map')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 venues on map'), findsOneWidget);
      expect(
        tester
            .widgetList<MarkerLayer>(find.byType(MarkerLayer))
            .expand((layer) => layer.markers),
        hasLength(3),
      );
      await tester.tap(find.byIcon(Icons.location_on).first);
      await tester.pumpAndSettle();
      expect(find.text('Pilates Studio'), findsOneWidget);
      expect(find.text('Pilates'), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
      expect(find.text('\u{20B1} 450 / hr'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      await tester.tapAt(const Offset(12, 200));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('news-feed-toggle-court-map')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('FITNESS TYPE'), findsOneWidget);
      expect(find.text('FACILITY TYPE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('news-feed-filter-sport-Pilates')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('news-feed-filter-sport-Pilates')),
      );
      await tester.tap(find.byKey(const ValueKey('news-feed-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Pilates Studio'), findsWidgets);
      expect(find.text('Yoga Wellness'), findsNothing);

      await tester.drag(
        find.byKey(const ValueKey('news-feed-content-list')),
        const Offset(0, 1200),
      );
      await tester.pumpAndSettle();
      final heart = find
          .byKey(const ValueKey('news-feed-mini-heart-business-71'))
          .first;
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(heartRequestMethod, 'PUT');
      expect(
        find.byKey(const ValueKey('news-feed-mini-heart-count-business-71')),
        findsWidgets,
      );
      final seeAll = find.byKey(
        const ValueKey('news-feed-see-all-popular-fitness-spaces'),
      );
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AllVenuesPage>(find.byType(AllVenuesPage))
            .any(
              (page) => identical(page.initialUserPosition, customerPosition),
            ),
        isTrue,
      );
      expect(
        find.text('Fitness & Wellness venues with the most hearts'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('all-venues-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('FITNESS TYPE'), findsOneWidget);
      expect(find.text('FACILITY TYPE'), findsOneWidget);
    },
  );
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}
