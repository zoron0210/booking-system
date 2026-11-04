import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

void main() {
  test(
    'social feed page sends cursor and limit and parses page metadata',
    () async {
      late Uri requestUri;
      final api = AuthApi(
        client: MockClient((request) async {
          requestUri = request.url;
          return http.Response(
            jsonEncode({
              'posts': [
                {'id': 42, 'caption': 'A post'},
              ],
              'hasMore': true,
              'nextCursor': 42,
            }),
            200,
          );
        }),
      );

      final page = await api.social.socialFeedPage(
        'test-token',
        followingOnly: true,
        query: 'weekend match',
        limit: 20,
        beforeId: '51',
      );

      expect(requestUri.path, '/api/social/feed');
      expect(requestUri.queryParameters, {
        'scope': 'following',
        'q': 'weekend match',
        'limit': '20',
        'before_id': '51',
      });
      expect(page.posts.single['id'], 42);
      expect(page.nextCursor, '42');
      expect(page.hasMore, isTrue);
    },
  );

  test('social feed page rejects limits outside the supported range', () async {
    final api = AuthApi(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      api.social.socialFeedPage('test-token', limit: 51),
      throwsArgumentError,
    );
  });
}
