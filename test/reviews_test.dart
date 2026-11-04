import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/venues/presentation/reviews.dart';
import 'package:myapp/core/rating_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const reviewerAvatar =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=';

  setUp(() async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
  });

  testWidgets('shared rating input remains centered and tappable on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selectedRatings = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppRatingInput(
              rating: 3,
              onChanged: selectedRatings.add,
              keyPrefix: 'alignment-test-star-',
              tooltipForRating: (rating) => '$rating stars',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ratingInput = find.byType(AppRatingInput);
    final ratingRow = find.descendant(
      of: ratingInput,
      matching: find.byType(Row),
    );
    expect(tester.getRect(ratingRow).center.dx, closeTo(160, 1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('alignment-test-star-4')));

    expect(selectedRatings, [4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review list shows each reviewer profile image', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'id': 31,
                'customerId': 7,
                'firstName': 'Ziggy',
                'lastName': 'Player',
                'avatarUrl': reviewerAvatar,
                'imageData': reviewerAvatar,
                'rating': 5,
                'comment': 'Great court.',
                'createdAt': DateTime.now()
                    .subtract(const Duration(minutes: 1))
                    .toIso8601String(),
                'reactionCount': 3,
                'replies': [
                  {
                    'id': 55,
                    'userId': 9,
                    'firstName': 'Maya',
                    'lastName': 'Player',
                    'avatarUrl': reviewerAvatar,
                    'text': 'I agree!',
                    'createdAt': DateTime.now()
                        .subtract(const Duration(minutes: 2))
                        .toIso8601String(),
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/bookings') {
        return http.Response(
          jsonEncode({'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewerImage = tester.widget<Image>(find.byType(Image).first);
    expect(reviewerImage.image, isA<MemoryImage>());
    expect(find.text('Ziggy Player'), findsOneWidget);
    expect(find.text('Great court.'), findsOneWidget);
    expect(find.text('1 min ago'), findsOneWidget);
    expect(find.text('2 mins ago'), findsOneWidget);
    expect(find.text('Like 3'), findsOneWidget);
    expect(find.text('Reply (1)'), findsOneWidget);
    expect(find.text('I agree!'), findsOneWidget);
    expect(
      find.text('Only customers with a completed booking can submit a review.'),
      findsOneWidget,
    );
    expect(find.text('Log in to continue'), findsNothing);
    expect(find.byKey(const ValueKey('review-photo-0')), findsOneWidget);
    final reviewerRating = tester.widget<Row>(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byType(Row),
      ),
    );
    expect(reviewerRating.children, hasLength(5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNWidgets(5),
    );
    expect(find.text('5/5'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('review-photo-tap-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('review-photo-fullscreen')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-photo-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-photo-fullscreen')), findsNothing);

    client.close();
  });

  testWidgets('review reactions and replies use authenticated venue APIs', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/news-feed/12/reviews') {
          return http.Response(
            jsonEncode({
              'reviews': [
                {
                  'id': 31,
                  'customerId': 7,
                  'firstName': 'Ziggy',
                  'rating': 5,
                  'comment': 'Great court.',
                  'reactionCount': 0,
                  'reactedByMe': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        if (request.url.path == '/api/venue-reviews/31/reactions' ||
            request.url.path == '/api/venue-reviews/31/replies') {
          return http.Response('{}', 201);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: api,
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-reaction-31')));
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/venue-reviews/31/reactions' &&
            request.headers.containsKey('authorization'),
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('review-reply-toggle-31')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('review-reply-input-31')),
      'Thanks for sharing!',
    );
    await tester.tap(find.byKey(const ValueKey('review-reply-send-31')));
    await tester.pumpAndSettle();
    final replyRequest = requests.firstWhere(
      (request) => request.url.path == '/api/venue-reviews/31/replies',
    );
    expect(replyRequest.method, 'POST');
    expect(replyRequest.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(replyRequest.body), {'text': 'Thanks for sharing!'});
  });

  testWidgets('review avatar opens the reviewer public profile', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/news-feed/12/reviews') {
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'id': 31,
                'customerId': 7,
                'firstName': 'Ziggy',
                'rating': 5,
                'comment': 'Great court.',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/bookings') {
        return http.Response(jsonEncode({'bookings': []}), 200);
      }
      if (request.url.path == '/api/social/users/7') {
        return http.Response(
          jsonEncode({
            'profile': {
              'id': 7,
              'displayName': 'Ziggy Player',
              'followersCount': 0,
              'followingCount': 0,
              'isFollowing': false,
            },
            'posts': [],
            'businesses': [],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-user-avatar-7')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-user-profile-page')),
      findsOneWidget,
    );
    expect(find.text('Ziggy Player'), findsOneWidget);
    client.close();
  });

  testWidgets('review list keeps initials when no profile image is available', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'customerId': 8,
                'firstName': 'Maya',
                'lastName': 'Player',
                'rating': 4,
                'comment': 'Nice venue.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/bookings') {
        return http.Response(
          jsonEncode({'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('M'), findsOneWidget);
    expect(find.text('Maya Player'), findsOneWidget);
    final reviewerRating = tester.widget<Row>(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byType(Row),
      ),
    );
    expect(reviewerRating.children, hasLength(5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNWidgets(4),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('4/5'), findsNothing);

    client.close();
  });

  testWidgets('guest can read reviews without requesting customer bookings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    http.Request? reviewRequest;
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/reviews')) {
        reviewRequest = request;
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'id': 31,
                'customerId': 7,
                'firstName': 'Maya',
                'lastName': 'Player',
                'rating': 5,
                'comment': 'Open to everyone.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 401);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya Player'), findsOneWidget);
    expect(find.text('Open to everyone.'), findsOneWidget);
    expect(
      find.text('Log in to review this venue after booking.'),
      findsOneWidget,
    );
    expect(find.text('Log in to continue'), findsOneWidget);
    expect(reviewRequest?.headers.containsKey('Authorization'), isFalse);
    expect(requestedPaths, ['/api/news-feed/12/reviews']);

    client.close();
  });
}
