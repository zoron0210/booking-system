import 'package:myapp/core/api_http_client.dart';

abstract interface class ApiTransport {
  ApiHttpClient get httpClient;

  Map<String, String> authHeadersForToken(
    String? token, {
    Map<String, String>? extra,
  });

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<List<dynamic>> requestList(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });
}
