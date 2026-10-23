import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_text.dart';
import 'package:myapp/news_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest can browse public venue listings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'name': 'Community Sports Center',
                  'businessType': 'Sports',
                  'enabled': true,
                  'category': 'Basketball',
                  'address': 'Cebu City',
                  'details': 'Indoor courts available for booking.',
                  'pricePerHour': 500,
                  'imageUrls': [],
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': 'This signed-out request is not allowed.'}),
          401,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Community Sports Center'), findsWidgets);
    expect(
      find.byKey(const ValueKey('news-feed-mini-business-42')),
      findsOneWidget,
    );
    expect(requests, contains('/api/businesses'));
    expect(requests, isNot(contains('/api/news-feed')));

    await tester.tap(find.byKey(const ValueKey('news-feed-mini-business-42')));
    await tester.pumpAndSettle();
    expect(find.text('Community Sports Center'), findsWidgets);
    expect(find.text('Reserve'), findsOneWidget);

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    expect(find.text('Log in to continue'), findsOneWidget);
    expect(find.text('Continue to log in'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log in to continue'), findsNothing);
    expect(requests.where((path) => path.contains('/bookings')), isEmpty);
  });

  testWidgets('guest can open saved, messages, bookings, and profile tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/businesses') {
          return http.Response(jsonEncode({'businesses': []}), 200);
        }
        return http.Response(
          jsonEncode({'error': 'Unexpected guest request.'}),
          401,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news-feed-nav-saved')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-messages')));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Log in to view your messages.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-bookings')));
    await tester.pumpAndSettle();
    expect(find.text('Bookings'), findsWidgets);
    expect(find.text('No pending bookings.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Player Profile'), findsOneWidget);
    expect(
      tester
          .widget<AppText>(find.byKey(const ValueKey('profile-guest-name')))
          .data,
      matches(RegExp(r'^Guest #?[A-HJ-NP-Z2-9]{10}$')),
    );
    expect(find.byKey(const ValueKey('profile-guest-login')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-guest-name-row')),
        matching: find.byKey(const ValueKey('profile-guest-login')),
      ),
      findsNothing,
    );
    expect(find.text('Browsing as a guest'), findsOneWidget);
    expect(find.text('Followers'), findsNothing);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Your activity'), findsNothing);
    expect(find.text('Completed matches'), findsNothing);
    expect(find.text('Your bookings & history'), findsNothing);
    expect(
      find.text('Keep track of what is coming up and where you have been.'),
      findsNothing,
    );
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('profile-history-tab-saved-items')),
    );
    await tester.pumpAndSettle();
    final savedFeed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(savedFeed.savedOnly, isTrue);
    expect(savedFeed.savedItemType, 'sports');
    final profileScroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('profile-page-scroll-view')),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(profileScroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byKey(const ValueKey('profile-page-scroll-view')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(profileScroll.position.pixels, greaterThan(0));
    expect(
      requests.where(
        (path) =>
            path.contains('/api/messages') ||
            path.contains('/api/bookings') ||
            path.contains('/api/customer'),
      ),
      isEmpty,
    );
  });
}
