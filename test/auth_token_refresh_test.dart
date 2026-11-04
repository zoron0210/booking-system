import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'authenticated requests rotate expired access tokens and retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final sessionService = AppSessionService.instance;
      final session = await sessionService.load();
      await session.setTokens(
        apiToken: 'expired-access-token',
        refreshToken: 'current-refresh-token',
      );
      final requests = <http.Request>[];
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/auth/refresh') {
            expect(jsonDecode(request.body), {
              'refreshToken': 'current-refresh-token',
            });
            return http.Response(
              jsonEncode({
                'token': 'new-access-token',
                'refreshToken': 'rotated-refresh-token',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.headers['Authorization'] == 'Bearer new-access-token') {
            return http.Response(
              jsonEncode({
                'user': {'id': 42},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'error': 'Access token expired.'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await api.me('expired-access-token');

      expect(response['user'], {'id': 42});
      expect(requests.map((request) => request.url.path), [
        '/api/auth/me',
        '/api/auth/refresh',
        '/api/auth/me',
      ]);
      expect(session.apiToken, 'new-access-token');
      expect(session.refreshToken, 'rotated-refresh-token');
    },
  );
}
