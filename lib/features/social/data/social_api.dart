import 'dart:convert';

import 'package:myapp/core/api_http_client.dart';
import 'package:myapp/core/api_transport.dart';
import 'package:myapp/features/social/domain/social_club.dart';

const bool socialPostingEnabled = true;
const bool socialProfileUiEnabled = true;

class SocialFeedPage {
  const SocialFeedPage({
    required this.posts,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> posts;
  final String? nextCursor;
  final bool hasMore;
}

class SocialApi {
  const SocialApi(this._api);

  final ApiTransport _api;

  Future<Map<String, dynamic>> socialNotifications(String token) =>
      _api.request(
        'GET',
        '/api/social/notifications',
        headers: _api.authHeadersForToken(token),
      );

  Future<void> markSocialNotificationRead({
    required String token,
    required int notificationId,
  }) async {
    await _api.request(
      'PATCH',
      '/api/social/notifications/$notificationId/read',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> markAllSocialNotificationsRead(String token) async {
    await _api.request(
      'POST',
      '/api/social/notifications/read-all',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<List<Map<String, dynamic>>> socialFeed(
    String? token, {
    bool allPublicPosts = false,
    bool followingOnly = false,
    String query = '',
  }) async => (await socialFeedPage(
    token,
    allPublicPosts: allPublicPosts,
    followingOnly: followingOnly,
    query: query,
    limit: 50,
  )).posts;

  Future<SocialFeedPage> socialFeedPage(
    String? token, {
    bool allPublicPosts = false,
    bool followingOnly = false,
    String query = '',
    String? beforeId,
    int limit = 20,
  }) async {
    if (allPublicPosts && followingOnly) {
      throw ArgumentError('Choose either the public or following feed.');
    }
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }
    final scope = allPublicPosts
        ? 'public'
        : followingOnly
        ? 'following'
        : null;
    final queryParameters = <String, String>{
      'limit': '$limit',
      'scope': ?scope,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'before_id': ?beforeId,
    };
    final path = Uri(
      path: '/api/social/feed',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return SocialFeedPage(
      posts: _socialMapList(response['posts'] ?? response['data']),
      nextCursor: response['nextCursor']?.toString(),
      hasMore: response['hasMore'] == true,
    );
  }

  Future<List<Map<String, dynamic>>> searchSocialUsers(
    String? token, {
    String query = '',
  }) async {
    final path = query.trim().isEmpty
        ? '/api/social/users'
        : '/api/social/users?q=${Uri.encodeQueryComponent(query.trim())}';
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return _socialMapList(response['users'] ?? response['data']);
  }

  Future<List<SocialClub>> socialClubs({
    required String? token,
    String query = '',
  }) async {
    final trimmedQuery = query.trim();
    final path = Uri(
      path: '/api/social/clubs',
      queryParameters: trimmedQuery.isEmpty ? null : {'q': trimmedQuery},
    ).toString();
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return _socialClubList(response['clubs'] ?? response['data']);
  }

  Future<SocialClub> socialClub({
    required String? token,
    required int clubId,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/social/clubs/$clubId',
      headers: _api.authHeadersForToken(token),
    );
    final club = response['club'];
    if (club is! Map) {
      throw const AuthApiException('The server returned an invalid club.', 502);
    }
    return SocialClub.fromJson(Map<String, dynamic>.from(club));
  }

  Future<SocialClub> createSocialClub({
    required String token,
    required String name,
    required String description,
    required String logo,
  }) async {
    final uploadedLogo = await _uploadSocialImage(token, logo);
    if (!uploadedLogo.startsWith('gcs://social-media-staging/')) {
      throw ArgumentError.value(logo, 'logo', 'A new club requires a photo.');
    }
    final response = await _api.request(
      'POST',
      '/api/social/clubs',
      body: {
        'name': name,
        'description': description,
        'logoImage': uploadedLogo,
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    final club = response['club'];
    if (club is! Map) {
      throw const AuthApiException('The server returned an invalid club.', 502);
    }
    return SocialClub.fromJson(Map<String, dynamic>.from(club));
  }

  Future<Map<String, dynamic>> joinSocialClub({
    required String token,
    required int clubId,
  }) async {
    return _api.request(
      'POST',
      '/api/social/clubs/$clubId/join',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> updateSocialClub({
    required String token,
    required int clubId,
    required String name,
    required String description,
    String? logo,
  }) async {
    final uploadedLogo = logo == null
        ? null
        : await _uploadSocialImage(token, logo);
    if (uploadedLogo != null &&
        !uploadedLogo.startsWith('gcs://social-media-staging/')) {
      throw ArgumentError.value(logo, 'logo', 'Choose a new logo photo.');
    }
    await _api.request(
      'PATCH',
      '/api/social/clubs/$clubId',
      body: {
        'name': name,
        'description': description,
        'logoImage': ?uploadedLogo,
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> updateSocialClubJoinApproval({
    required String token,
    required int clubId,
    required bool requiresApproval,
  }) async {
    await _api.request(
      'PATCH',
      '/api/social/clubs/$clubId/settings',
      body: {'requiresJoinApproval': requiresApproval},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> socialClubJoinRequests({
    required String token,
    required int clubId,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/social/clubs/$clubId/join-requests',
      headers: _api.authHeadersForToken(token),
    );
    return _socialMapList(response['requests']);
  }

  Future<void> reviewSocialClubJoinRequest({
    required String token,
    required int clubId,
    required int userId,
    required bool approve,
  }) async {
    await _api.request(
      'PATCH',
      '/api/social/clubs/$clubId/join-requests/$userId',
      body: {'action': approve ? 'approve' : 'reject'},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> deleteSocialClub({
    required String token,
    required int clubId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/social/clubs/$clubId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> leaveSocialClub({
    required String token,
    required int clubId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/social/clubs/$clubId/membership',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<SocialFeedPage> socialClubPosts({
    required String? token,
    required int clubId,
    String? beforeId,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }
    final path = Uri(
      path: '/api/social/clubs/$clubId/posts',
      queryParameters: {'limit': '$limit', 'before_id': ?beforeId},
    ).toString();
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return SocialFeedPage(
      posts: _socialMapList(response['posts'] ?? response['data']),
      nextCursor: response['nextCursor']?.toString(),
      hasMore: response['hasMore'] == true,
    );
  }

  Future<Map<String, dynamic>> socialUserProfile({
    required String? token,
    required int userId,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/social/users/$userId',
      headers: _api.authHeadersForToken(token),
    );
    return {
      ...?response['profile'] as Map<String, dynamic>?,
      'posts': _socialMapList(response['posts'] ?? response['data']),
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
    final response = await _api.request(
      'GET',
      '/api/social/users/$userId/$type',
      headers: _api.authHeadersForToken(token),
    );
    return _socialMapList(response['users'] ?? response['data']);
  }

  Future<Map<String, dynamic>> createSocialPost({
    required String token,
    required String caption,
    required List<String> images,
    int? clubId,
  }) async {
    final uploadedImages = <String>[];
    for (final image in images) {
      uploadedImages.add(await _uploadSocialImage(token, image));
    }

    return _api.request(
      'POST',
      '/api/social/posts',
      body: {'caption': caption, 'images': uploadedImages, 'clubId': ?clubId},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<String> _uploadSocialImage(String token, String image) async {
    final match = RegExp(
      r'^data:(image/(?:jpeg|png|webp));base64,([A-Za-z0-9+/]+={0,2})$',
      caseSensitive: false,
    ).firstMatch(image);
    if (match == null) return image;

    final contentType = match.group(1)!.toLowerCase();
    final bytes = base64Decode(match.group(2)!);
    late final Map<String, dynamic> upload;
    try {
      upload = await _api.request(
        'POST',
        '/api/social/uploads',
        body: {'contentType': contentType, 'size': bytes.length},
        headers: _api.authHeadersForToken(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
      );
    } on AuthApiException catch (error) {
      if (error.statusCode == 503 &&
          error.data['legacyUploadsAllowed'] == true) {
        return image;
      }
      rethrow;
    }
    final uploadUrl = upload['uploadUrl'];
    final key = upload['key'];
    final rawHeaders = upload['headers'];
    if (uploadUrl is! String ||
        key is! String ||
        !key.startsWith('gcs://social-media-staging/') ||
        rawHeaders is! Map) {
      throw const AuthApiException(
        'The server returned an invalid photo upload request.',
        502,
      );
    }
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'storage.googleapis.com') {
      throw const AuthApiException(
        'The server returned an invalid photo upload address.',
        502,
      );
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const AuthApiException(
          'The server returned invalid photo upload headers.',
          502,
        );
      }
      headers[entry.key as String] = entry.value as String;
    }
    await _api.httpClient.putBytes(uri, body: bytes, headers: headers);
    return key;
  }

  Future<List<Map<String, dynamic>>> searchSocialGifs(
    String query, {
    String? token,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/social/gifs?q=${Uri.encodeQueryComponent(query.trim())}',
      headers: _api.authHeadersForToken(token),
    );
    return _socialMapList(response['gifs'] ?? response['data']);
  }

  Future<List<Map<String, dynamic>>> socialPostComments({
    required String? token,
    required int postId,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/social/posts/$postId/comments',
      headers: _api.authHeadersForToken(token),
    );
    return _socialMapList(response['comments'] ?? response['data']);
  }

  Future<void> createSocialPostComment({
    required String token,
    required int postId,
    required String text,
    String? gifUrl,
  }) async {
    await _api.request(
      'POST',
      '/api/social/posts/$postId/comments',
      body: {'text': text, 'gifUrl': gifUrl},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> setSocialPostCommentReaction({
    required String token,
    required int postId,
    required int commentId,
    required bool reacted,
  }) async {
    await _api.request(
      reacted ? 'POST' : 'DELETE',
      '/api/social/posts/$postId/comments/$commentId/reactions',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> createSocialPostCommentReply({
    required String token,
    required int postId,
    required int commentId,
    required String text,
  }) async {
    await _api.request(
      'POST',
      '/api/social/posts/$postId/comments/$commentId/replies',
      body: {'text': text},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> setSocialPostLiked({
    required String token,
    required int postId,
    required bool liked,
  }) async {
    await _api.request(
      liked ? 'POST' : 'DELETE',
      '/api/social/posts/$postId/likes',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> setSocialPostSaved({
    required String token,
    required int postId,
    required bool saved,
  }) async {
    await _api.request(
      saved ? 'POST' : 'DELETE',
      '/api/social/posts/$postId/saves',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> deleteSocialPost({
    required String token,
    required int postId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/social/posts/$postId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> reportSocialPost({
    required String token,
    required int postId,
    required String reason,
  }) async {
    await _api.request(
      'POST',
      '/api/social/posts/$postId/reports',
      body: {'reason': reason},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> followSocialUser({
    required String token,
    required int userId,
  }) async {
    await _api.request(
      'POST',
      '/api/social/follows/$userId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> unfollowSocialUser({
    required String token,
    required int userId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/social/follows/$userId',
      headers: _api.authHeadersForToken(token),
    );
  }
}

List<Map<String, dynamic>> _socialMapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];

List<SocialClub> _socialClubList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => SocialClub.fromJson(Map<String, dynamic>.from(item)))
          .toList()
    : const [];
