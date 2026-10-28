import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/news_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disabled venues are unavailable and do not navigate from discovery cards',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      FlutterSecureStorage.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'businessId': 42,
                    'businessName': 'Disabled venue',
                    'businessType': 'Sports',
                    'category': 'Basketball',
                    'pricePerHour': 200,
                    'enabled': true,
                    'reviewCount': 3,
                    'averageRating': 4.5,
                    'title': 'Venue update',
                    'body': 'Details',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(jsonEncode({'businesses': []}), 200);
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected API request'}),
            500,
          );
        }),
      );
      final observer = _PushObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: NewsFeedPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('UNAVAILABLE'), findsOneWidget);
      final smallCard = find
          .byKey(const ValueKey('news-feed-mini-business-42'))
          .first;
      final smallCardTap = find.descendant(
        of: smallCard,
        matching: find.byType(InkWell),
      ).first;
      expect(tester.widget<InkWell>(smallCardTap).onTap, isNull);
      final pushesBeforeTap = observer.pushCount;

      await tester.tap(smallCard);
      await tester.pumpAndSettle();

      expect(observer.pushCount, pushesBeforeTap);
      expect(find.text('Sports Courts'), findsOneWidget);
      expect(find.text('SpotGo'), findsOneWidget);
      expect(find.byKey(const ValueKey('news-feed-search')), findsOneWidget);
      final feedScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      final listedCard = find.byKey(
        const ValueKey('news-feed-card-business-42'),
      );
      await tester.scrollUntilVisible(
        listedCard,
        180,
        scrollable: feedScrollable,
      );
      expect(find.text('UNAVAILABLE · Booking disabled'), findsOneWidget);
      final listedCardTap = find
          .descendant(of: listedCard, matching: find.byType(InkWell))
          .first;
      expect(tester.widget<InkWell>(listedCardTap).onTap, isNull);
      final pushesBeforeListedTap = observer.pushCount;
      await tester.tap(listedCard);
      await tester.pumpAndSettle();
      expect(observer.pushCount, pushesBeforeListedTap);
    },
  );
}

class _PushObserver extends NavigatorObserver {
  int pushCount = 0;
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}
