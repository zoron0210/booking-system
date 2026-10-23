part of '../../../auth_api.dart';

// Keep these implementations available while their customer-facing UI is on hold.
const bool socialPostingEnabled = false;
const bool socialProfileUiEnabled = false;

extension AuthApiSocialOperations on AuthApi {
  Future<List<Map<String, dynamic>>> socialFeed(String token) async {
    final response = await _request(
      'GET',
      '/api/social/feed',
      headers: _authHeaders(token),
    );
    return _socialMapList(response['posts']);
  }

  Future<List<Map<String, dynamic>>> searchSocialUsers(
    String token, {
    String query = '',
  }) async {
    final path = query.trim().isEmpty
        ? '/api/social/users'
        : '/api/social/users?q=${Uri.encodeQueryComponent(query.trim())}';
    final response = await _request('GET', path, headers: _authHeaders(token));
    return _socialMapList(response['users']);
  }

  Future<Map<String, dynamic>> socialUserProfile({
    required String token,
    required int userId,
  }) async {
    final response = await _request(
      'GET',
      '/api/social/users/$userId',
      headers: _authHeaders(token),
    );
    return {
      ...?response['profile'] as Map<String, dynamic>?,
      'posts': _socialMapList(response['posts']),
      'businesses': _socialMapList(response['businesses']),
    };
  }

  Future<List<Map<String, dynamic>>> socialUserConnections({
    required String token,
    required int userId,
    required String type,
  }) async {
    if (type != 'followers' && type != 'following') {
      throw ArgumentError.value(
        type,
        'type',
        'Expected followers or following.',
      );
    }
    final response = await _request(
      'GET',
      '/api/social/users/$userId/$type',
      headers: _authHeaders(token),
    );
    return _socialMapList(response['users']);
  }

  Future<Map<String, dynamic>> createSocialPost({
    required String token,
    required String caption,
    required List<String> images,
  }) async {
    if (!socialPostingEnabled) {
      throw StateError('Social posting is currently disabled.');
    }
    return _request(
      'POST',
      '/api/social/posts',
      body: {'caption': caption, 'images': images},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> followSocialUser({
    required String token,
    required int userId,
  }) async {
    await _request(
      'POST',
      '/api/social/follows/$userId',
      headers: _authHeaders(token),
    );
  }

  Future<void> unfollowSocialUser({
    required String token,
    required int userId,
  }) async {
    await _request(
      'DELETE',
      '/api/social/follows/$userId',
      headers: _authHeaders(token),
    );
  }
}

List<Map<String, dynamic>> _socialMapList(dynamic value) =>
    (value as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
