import 'package:myapp/core/api_http_client.dart';
import 'package:myapp/core/api_transport.dart';

class MessagingApi {
  const MessagingApi(this._api);

  final ApiTransport _api;

  Future<Map<String, dynamic>> messageOwner({
    required String token,
    required String businessKey,
  }) => _api.request(
    'GET',
    '/api/messages/owner?businessKey=${Uri.encodeQueryComponent(businessKey)}',
    headers: _api.authHeadersForToken(token),
  );

  Future<List<Map<String, dynamic>>> conversations(
    String token, {
    String? businessType,
  }) async {
    final path = businessType == null || businessType.trim().isEmpty
        ? '/api/messages/conversations'
        : '/api/messages/conversations?businessType=${Uri.encodeQueryComponent(businessType.trim())}';
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return (response['conversations'] as List<dynamic>? ??
            response['data'] as List<dynamic>? ??
            [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Map<String, dynamic>>> messageContacts(String token) async {
    final response = await _api.request(
      'GET',
      '/api/messages/contacts',
      headers: _api.authHeadersForToken(token),
    );
    return (response['contacts'] as List<dynamic>? ??
            response['data'] as List<dynamic>? ??
            [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<int> openConversation({
    required String token,
    int? recipientId,
    List<int>? participantIds,
    String? title,
    bool group = false,
  }) async {
    final ids = [...?participantIds];
    if (recipientId != null) ids.add(recipientId);
    final response = await _api.request(
      'POST',
      '/api/messages/conversations',
      body: {
        'recipientId': recipientId,
        'participantIds': ids,
        'title': title,
        'type': group ? 'group' : 'direct',
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    return (response['conversationId'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> conversationMessages({
    required String token,
    required int conversationId,
    String? businessType,
  }) async {
    final path = businessType == null || businessType.trim().isEmpty
        ? '/api/messages/conversations/$conversationId'
        : '/api/messages/conversations/$conversationId?businessType=${Uri.encodeQueryComponent(businessType.trim())}';
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return (response['messages'] as List<dynamic>? ??
            response['data'] as List<dynamic>? ??
            [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> sendConversationMessage({
    required String token,
    required int conversationId,
    required String body,
    Map<String, dynamic>? attachment,
    String? businessType,
  }) async {
    await _api.request(
      'POST',
      '/api/messages/conversations/$conversationId',
      body: {
        'body': body,
        ...?(businessType == null || businessType.trim().isEmpty
            ? null
            : {'businessType': businessType.trim()}),
        ...?(attachment == null ? null : {'attachment': attachment}),
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> deleteConversationMessage({
    required String token,
    required int conversationId,
    required int messageId,
    required String scope,
  }) async {
    if (scope != 'me' && scope != 'everyone') {
      throw const AuthApiException(
        'Choose a valid message deletion scope.',
        400,
      );
    }
    await _api.request(
      'DELETE',
      '/api/messages/conversations/$conversationId/messages/$messageId',
      body: {'scope': scope},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> setConversationState({
    required String token,
    required int conversationId,
    bool? archived,
    bool? unread,
  }) async {
    await _api.request(
      'PATCH',
      '/api/messages/conversations/$conversationId/state',
      body: {
        ...?(archived == null ? null : {'archived': archived}),
        ...?(unread == null ? null : {'unread': unread}),
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> deleteConversation({
    required String token,
    required int conversationId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/messages/conversations/$conversationId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> blockMessageUser({
    required String token,
    required int userId,
  }) async {
    await _api.request(
      'POST',
      '/api/messages/blocks/$userId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> unblockMessageUser({
    required String token,
    required int userId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/messages/blocks/$userId',
      headers: _api.authHeadersForToken(token),
    );
  }

  // Compatibility aliases for older messaging-page editor snapshots.
  Future<List<Map<String, dynamic>>> messages({
    required String token,
    required int conversationId,
  }) => conversationMessages(token: token, conversationId: conversationId);

  Future<int> createConversation({
    required String token,
    required List<int> participantIds,
    String? title,
    bool group = false,
  }) => openConversation(
    token: token,
    participantIds: participantIds,
    title: title,
    group: group,
  );

  Future<void> sendMessage({
    required String token,
    required int conversationId,
    String? body,
    Map<String, dynamic>? attachment,
  }) => sendConversationMessage(
    token: token,
    conversationId: conversationId,
    body: body ?? '',
  );
}
