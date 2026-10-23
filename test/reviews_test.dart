import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/reviews.dart';
import 'package:myapp/rating_widgets.dart';
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
                'customerId': 7,
                'firstName': 'Ziggy',
                'lastName': 'Player',
                'avatarUrl': reviewerAvatar,
                'imageData': reviewerAvatar,
                'rating': 5,
                'comment': 'Great court.',
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
