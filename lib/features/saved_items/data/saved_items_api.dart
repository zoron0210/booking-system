import 'package:myapp/core/api_transport.dart';

class SavedItemsApi {
  const SavedItemsApi(this._api);

  final ApiTransport _api;

  Future<List<Map<String, dynamic>>> savedItems(String token) async {
    final response = await _api.request(
      'GET',
      '/api/saved-items',
      headers: _api.authHeadersForToken(token),
    );
    return (response['items'] as List<dynamic>? ??
            response['data'] as List<dynamic>? ??
            [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, int>> savedItemCounts(String token, String type) async {
    final response = await _api.request(
      'GET',
      '/api/saved-item-counts?itemType=${Uri.encodeQueryComponent(type)}',
      headers: _api.authHeadersForToken(token),
    );
    final counts = response['counts'];
    if (counts is! Map) return {};
    return counts.map<String, int>(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  Future<void> saveItem({
    required String token,
    required String type,
    required String key,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) async {
    await _api.request(
      'POST',
      '/api/saved-items',
      body: {
        'itemType': type,
        'itemKey': key,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> removeSavedItem(String token, String type, String key) async {
    await _api.request(
      'DELETE',
      '/api/saved-items/${Uri.encodeComponent(type)}/${Uri.encodeComponent(key)}',
      headers: _api.authHeadersForToken(token),
    );
  }
}
