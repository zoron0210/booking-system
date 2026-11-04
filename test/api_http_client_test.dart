import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/core/api_http_client.dart';

void main() {
  test(
    'request joins base and endpoint paths without duplicate slashes',
    () async {
      late Uri receivedUri;
      final client = ApiHttpClient(
        baseUrl: 'https://api.example.test/v1/',
        client: MockClient((request) async {
          receivedUri = request.url;
          return http.Response('{}', 200);
        }),
      );

      await client.request('GET', '/api/venues');

      expect(receivedUri.toString(), 'https://api.example.test/v1/api/venues');
    },
  );

  test(
    'request supports base URLs without a path and endpoints without a slash',
    () async {
      late Uri receivedUri;
      final client = ApiHttpClient(
        baseUrl: 'https://api.example.test/',
        client: MockClient((request) async {
          receivedUri = request.url;
          return http.Response('{}', 200);
        }),
      );

      await client.request('GET', 'api/venues');

      expect(receivedUri.toString(), 'https://api.example.test/api/venues');
    },
  );

  test('request preserves endpoint query parameters', () async {
    late Uri receivedUri;
    final client = ApiHttpClient(
      baseUrl: 'https://api.example.test/v1/',
      client: MockClient((request) async {
        receivedUri = request.url;
        return http.Response('{}', 200);
      }),
    );

    await client.request('GET', '/api/bookings?businessType=Fitness%20Center');

    expect(receivedUri.path, '/v1/api/bookings');
    expect(receivedUri.queryParameters, {'businessType': 'Fitness Center'});
  });

  test('request preserves successful top-level JSON arrays', () async {
    final client = ApiHttpClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((_) async => http.Response('[{"id":1}]', 200)),
    );

    await expectLater(
      client.request('GET', '/api/venues'),
      completion({
        'data': [
          {'id': 1},
        ],
      }),
    );
    await expectLater(
      client.requestList('GET', '/api/venues'),
      completion([
        {'id': 1},
      ]),
    );
  });
}
