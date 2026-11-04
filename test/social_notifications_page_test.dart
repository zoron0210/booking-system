import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/social/presentation/social_home_palette.dart';
import 'package:myapp/features/social/presentation/social_notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows social activity separately from the account activity log',
    (tester) async {
      final requests = <http.Request>[];
      int? changedUnreadCount;
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/social/notifications') {
            return http.Response(
              jsonEncode({
                'unreadCount': 2,
                'notifications': [
                  {
                    'id': 8,
                    'type': 'comment',
                    'postId': 35,
                    'postOwnerId': 7,
                    'actorUserId': 12,
                    'actorFirstName': 'Alex',
                    'actorLastName': 'Player',
                    'commentText': 'Great game!',
                    'createdAt': DateTime.now().toIso8601String(),
                    'readAt': null,
                  },
                  {
                    'id': 9,
                    'type': 'follow',
                    'actorUserId': 15,
                    'actorFirstName': 'Taylor',
                    'actorLastName': 'Player',
                    'createdAt': DateTime.now().toIso8601String(),
                    'readAt': '2026-10-28T08:00:00.000Z',
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

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: SocialNotificationsPage(
            api: api,
            token: 'test-token',
            onUnreadCountChanged: (count) => changedUnreadCount = count,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        SocialHomeColors.forBrightness(Brightness.light).canvas,
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Activity log'), findsNothing);
      expect(find.text('Alex Player commented on your post'), findsOneWidget);
      expect(find.text('Great game!'), findsOneWidget);
      expect(find.text('Taylor Player started following you'), findsOneWidget);
      expect(changedUnreadCount, 2);

      await tester.tap(
        find.byKey(const ValueKey('social-notifications-mark-all-read')),
      );
      await tester.pumpAndSettle();

      expect(
        requests.any(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/api/social/notifications/read-all',
        ),
        isTrue,
      );
      expect(changedUnreadCount, 0);
    },
  );

  testWidgets('uses the active dark theme for notification colors', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'unreadCount': 0, 'notifications': []}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SocialNotificationsPage(api: api, token: 'test-token'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      SocialHomeColors.forBrightness(Brightness.dark).canvas,
    );
  });
}
