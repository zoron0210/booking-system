part of '../../../auth_api.dart';

const bool socialPostingEnabled = true;
const bool socialProfileUiEnabled = true;

extension AuthApiSocialOperations on AuthApi {
  Future<Map<String, dynamic>> socialNotifications(String token) =>
      _request(
        'GET',
        '/api/social/notifications',
        headers: _authHeaders(token),
      );

  Future<void> markSocialNotificationRead({
    required String token,
    required int notificationId,
  }) async {
    await _request(
      'PATCH',
      '/api/social/notifications/$notificationId/read',
      headers: _authHeaders(token),
    );
  }

  Future<void> markAllSocialNotificationsRead(String token) async {
    await _request(
      'POST',
      '/api/social/notifications/read-all',
      headers: _authHeaders(token),
    );
  }

  Future<List<Map<String, dynamic>>> socialFeed(
    String? token, {
    bool allPublicPosts = false,
    bool followingOnly = false,
  }) async {
    if (allPublicPosts && followingOnly) {
      throw ArgumentError('Choose either the public or following feed.');
    }
    final scope = allPublicPosts
        ? 'public'
        : followingOnly
        ? 'following'
        : null;
    final path = scope == null
        ? '/api/social/feed'
        : '/api/social/feed?scope=$scope';
    final response = await _request('GET', path, headers: _authHeaders(token));
    return _socialMapList(response['posts']);
  }

  Future<List<Map<String, dynamic>>> searchSocialUsers(
    String? token, {
    String query = '',
  }) async {
    final path = query.trim().isEmpty
        ? '/api/social/users'
        : '/api/social/users?q=${Uri.encodeQueryComponent(query.trim())}';
    final response = await _request('GET', path, headers: _authHeaders(token));
    return _socialMapList(response['users']);
  }

  Future<Map<String, dynamic>> socialUserProfile({
    required String? token,
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
    required String? token,
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
  }) => _request(
    'POST',
    '/api/social/posts',
    body: {'caption': caption, 'images': images},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<List<Map<String, dynamic>>> searchSocialGifs(
    String query, {
    String? token,
  }) async {
    final response = await _request(
      'GET',
      '/api/social/gifs?q=${Uri.encodeQueryComponent(query.trim())}',
      headers: _authHeaders(token),
    );
    return _socialMapList(response['gifs']);
  }

  Future<List<Map<String, dynamic>>> socialPostComments({
    required String? token,
    required int postId,
  }) async {
    final response = await _request(
      'GET',
      '/api/social/posts/$postId/comments',
      headers: _authHeaders(token),
    );
    return _socialMapList(response['comments']);
  }

  Future<void> createSocialPostComment({
    required String token,
    required int postId,
    required String text,
    String? gifUrl,
  }) async {
    await _request(
      'POST',
      '/api/social/posts/$postId/comments',
      body: {'text': text, 'gifUrl': gifUrl},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> setSocialPostLiked({
    required String token,
    required int postId,
    required bool liked,
  }) async {
    await _request(
      liked ? 'POST' : 'DELETE',
      '/api/social/posts/$postId/likes',
      headers: _authHeaders(token),
    );
  }

  Future<void> setSocialPostSaved({
    required String token,
    required int postId,
    required bool saved,
  }) async {
    await _request(
      saved ? 'POST' : 'DELETE',
      '/api/social/posts/$postId/saves',
      headers: _authHeaders(token),
    );
  }

  Future<void> reportSocialPost({
    required String token,
    required int postId,
    required String reason,
  }) async {
    await _request(
      'POST',
      '/api/social/posts/$postId/reports',
      body: {'reason': reason},
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
