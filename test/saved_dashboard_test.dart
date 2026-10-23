import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/app_bottom_navigation.dart';
import 'package:myapp/news_feed.dart';
import 'package:myapp/saved_dashboard.dart';
import 'package:myapp/saved_icons.dart';
import 'package:myapp/sports.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('maps fitness business type to the fitness saved-item category', () {
    expect(
      SavedDashboardPage.itemTypeForBusinessType('Fitness & Wellness'),
      'fitness',
    );
  });

  testWidgets('fitness saved page shows fitness venues only', (tester) async {
    final session = await AppSession.load();
    await session.setApiToken('test-token');
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 1,
                  'businessName': 'Basketball Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'title': 'Basketball Court',
                  'body': 'Basketball news',
                  'imageUrl': 'https://example.test/basketball.jpg',
                  'enabled': true,
                },
                {
                  'businessId': 2,
                  'businessName': 'Pilates Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Pilates',
                  'title': 'Pilates Studio',
                  'body': 'Pilates news',
                  'imageUrl': 'https://example.test/pilates.jpg',
                  'enabled': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 1,
                  'name': 'Basketball Court',
                  'businessType': 'Sports',
                  'enabled': true,
                },
                {
                  'id': 2,
                  'name': 'Pilates Studio',
                  'businessType': 'Fitness & Wellness',
                  'enabled': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/saved-items') {
          return http.Response(
            jsonEncode({
              'items': [
                {'itemType': 'fitness', 'itemKey': '2'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SavedDashboardPage(
          itemType: SavedDashboardPage.itemTypeForBusinessType(
            'Fitness & Wellness',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(feed.savedOnly, isTrue);
    expect(find.byKey(const ValueKey('saved-venues-image-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-feed-search')), findsNothing);
    expect(
      find.byKey(const ValueKey('saved-venue-tile-business-2')),
      findsOneWidget,
    );
    expect(
      find.text('Pilates Studio'),
      findsWidgets,
      reason:
          '${requests.join(' | ')}; ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data ?? widget.textSpan?.toPlainText()).join(' | ')}',
    );
    expect(find.text('Basketball Court'), findsNothing);
  });

  testWidgets('saved venue detail stays saved and can be unsaved', (
    tester,
  ) async {
    final session = await AppSession.load();
    await session.setApiToken('test-token');
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.url.path == '/api/saved-items') {
          return http.Response(
            jsonEncode({
              'items': [
                {'itemType': 'fitness', 'itemKey': '2'},
                {'itemType': 'sports', 'itemKey': '2'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/saved-item-counts') {
          return http.Response(jsonEncode({'counts': {'2': 1}}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SportsVenueDetailPage(
          venue: (
            id: 2,
            name: 'Pilates Studio',
            sport: 'Pilates',
            address: 'Cebu City',
            ownerName: 'Studio',
            type: 'Fitness',
            courts: '',
            hours: '',
            availability: '',
            details: '',
            image: 'https://example.test/pilates.jpg',
            images: <String>['https://example.test/pilates.jpg'],
            priceDay: '',
            priceNight: '',
            priceLines: <String>[],
            maxPrice: 0,
            averageRating: 0,
            reviewCount: 0,
            ratingUserCount: 0,
            includedPlayers: 0,
            additionalPlayerFee: 0,
            totalSlots: 0,
            sportsSlots: <Map<String, dynamic>>[],
            tags: <String>[],
            rateLabels: <String>[],
            latitude: 0,
            longitude: 0,
            distanceLabel: '',
            heartCount: 0,
            visitUrl: '',
            merchantEmail: '',
            merchantPhone: '',
            merchantAvatarUrl: '',
          ),
          api: api,
          savedItemType: 'fitness',
          onReserve: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(savedItemSelectedIcon), findsOneWidget);
    await tester.tap(find.byIcon(savedItemSelectedIcon));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.startsWith('DELETE ') &&
            request.endsWith('/api/saved-items/fitness/2'),
      ),
      isTrue,
    );
    expect(find.byIcon(savedItemIcon), findsOneWidget);
  });

  testWidgets('embedded saved tab hides its own app bar and bottom nav', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/businesses') {
          return http.Response(jsonEncode({'businesses': []}), 200);
        }
        if (request.url.path == '/api/saved-items') {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (request.url.path == '/api/news-feed') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SavedDashboardPage(
          embedded: true,
          api: api,
          itemType: 'sports',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(AppBottomNavigation), findsNothing);
    expect(find.text('You have no saved venues yet.'), findsOneWidget);
  });
}
