import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

void main() {
  test('uploads photo bytes directly before creating a social post', () async {
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0L8AAAAASUVORK5CYII=',
    );
    final uploadedKey =
        'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-68';
    var uploadBytesSent = false;
    Map<String, dynamic>? postRequestBody;
    final client = MockClient((request) async {
      if (request.url.path == '/api/social/uploads') {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'contentType': 'image/png',
          'size': pngBytes.length,
        });
        return http.Response(
          jsonEncode({
            'uploadUrl': 'https://storage.googleapis.com/test-bucket/staging?signature=secret',
            'key': uploadedKey,
            'headers': {'Content-Type': 'image/png'},
          }),
          201,
        );
      }
      if (request.url.host == 'storage.googleapis.com') {
        expect(request.method, 'PUT');
        expect(request.headers['Content-Type'], 'image/png');
        expect(request.bodyBytes, pngBytes);
        uploadBytesSent = true;
        return http.Response('', 200);
      }
      if (request.url.path == '/api/social/posts') {
        postRequestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': 42}), 201);
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });

    final api = AuthApi(client: client);
    await api.social.createSocialPost(
      token: 'token',
      caption: 'Match day',
      images: ['data:image/png;base64,${base64Encode(pngBytes)}'],
    );

    expect(uploadBytesSent, isTrue);
    expect(postRequestBody, {
      'caption': 'Match day',
      'images': [uploadedKey],
    });
  });
}
