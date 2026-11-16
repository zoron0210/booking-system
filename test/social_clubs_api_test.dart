import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

void main() {
  test(
    'club creation rejects a missing image before making requests',
    () async {
      final api = AuthApi(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        api.social.createSocialClub(
          token: 'test-token',
          name: 'Weekend Badminton',
          description: '',
          logo: '',
        ),
        throwsArgumentError,
      );
    },
  );

  test('club APIs serialize search, membership, and club post requests', () async {
    final requests = <http.Request>[];
    var uploadNumber = 0;
    const photo = 'data:image/png;base64,iVBORw0KGgo=';
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/social/uploads' &&
            request.method == 'POST') {
          uploadNumber += 1;
          final size = (jsonDecode(request.body) as Map)['size'];
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://storage.googleapis.com/test-bucket/upload',
              'key':
                  'gcs://social-media-staging/7/11111111-1111-4111-8111-11111111111$uploadNumber-$size',
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
                  'description': 'Play together.',
                  'ownerUserId': 7,
                  'ownerName': 'Alex Player',
                  'memberCount': 3,
                  'isOwner': true,
                  'isMember': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31') {
          return http.Response(
            jsonEncode({
              'club': {
                'id': 31,
                'name': 'Weekend Badminton',
                'ownerUserId': 7,
                'memberCount': 3,
                'isOwner': true,
                'isMember': true,
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs/31/posts') {
          return http.Response(
            jsonEncode({'posts': [], 'hasMore': false}),
            200,
          );
        }
        if (request.url.path == '/api/social/clubs' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'club': {'id': 31, 'name': 'Weekend Badminton'},
            }),
            201,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    final clubs = await api.social.socialClubs(
      token: 'test-token',
      query: 'badminton',
    );
    final club = await api.social.socialClub(token: 'test-token', clubId: 31);
    final page = await api.social.socialClubPosts(
      token: 'test-token',
      clubId: 31,
      beforeId: '44',
      limit: 20,
    );
    await api.social.joinSocialClub(token: 'test-token', clubId: 31);
    await api.social.leaveSocialClub(token: 'test-token', clubId: 31);
    final created = await api.social.createSocialClub(
      token: 'test-token',
      name: 'Weekend Badminton',
      description: '',
      logo: photo,
    );
    await api.social.createSocialPost(
      token: 'test-token',
      caption: 'Saturday practice!',
      images: [photo],
      clubId: 31,
    );

    expect(clubs.single.name, 'Weekend Badminton');
    expect(clubs.single.isOwner, isTrue);
    expect(club.isMember, isTrue);
    expect(page.posts, isEmpty);
    expect(created.id, 31);
    expect(requests[0].url.queryParameters, {'q': 'badminton'});
    expect(requests[2].url.queryParameters, {'limit': '20', 'before_id': '44'});
    expect(requests[3].method, 'POST');
    expect(requests[4].method, 'DELETE');
    final createRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/social/clubs' && request.method == 'POST',
    );
    expect(jsonDecode(createRequest.body), {
      'name': 'Weekend Badminton',
      'description': '',
      'logoImage':
          'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-8',
    });
    final postRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/social/posts' && request.method == 'POST',
    );
    expect(jsonDecode(postRequest.body), {
      'caption': 'Saturday practice!',
      'images': [
        'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111112-8',
      ],
      'clubId': 31,
    });
  });
}
