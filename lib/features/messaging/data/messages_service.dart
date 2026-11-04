import 'package:myapp/features/auth/data/auth_api.dart';

class MessagesService {
  MessagesService({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;

  Future<List<Map<String, dynamic>>> fetchConversations(
    String token, {
    String? businessType,
  }) => _api.messaging.conversations(token, businessType: businessType);

  Future<List<Map<String, dynamic>>> fetchContacts(String token) =>
      _api.messaging.messageContacts(token);

  Future<Map<String, dynamic>> fetchCurrentUser(String token) => _api.me(token);

  Future<int> openConversation({
    required String token,
    int? recipientId,
    List<int>? participantIds,
    String? title,
    bool group = false,
  }) => _api.messaging.openConversation(
    token: token,
    recipientId: recipientId,
    participantIds: participantIds,
    title: title,
    group: group,
  );

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String token,
    required int conversationId,
    String? businessType,
  }) => _api.messaging.conversationMessages(
    token: token,
    conversationId: conversationId,
    businessType: businessType,
  );

  Future<void> sendMessage({
    required String token,
    required int conversationId,
    required String body,
    Map<String, dynamic>? attachment,
    String? businessType,
  }) => _api.messaging.sendConversationMessage(
    token: token,
    conversationId: conversationId,
    body: body,
    attachment: attachment,
    businessType: businessType,
  );

  Future<void> deleteMessage({
    required String token,
    required int conversationId,
    required int messageId,
    required String scope,
  }) => _api.messaging.deleteConversationMessage(
    token: token,
    conversationId: conversationId,
    messageId: messageId,
    scope: scope,
  );

  Future<void> setConversationState({
    required String token,
    required int conversationId,
    bool? archived,
    bool? unread,
  }) => _api.messaging.setConversationState(
    token: token,
    conversationId: conversationId,
    archived: archived,
    unread: unread,
  );

  Future<void> deleteConversation({
    required String token,
    required int conversationId,
  }) => _api.messaging.deleteConversation(
    token: token,
    conversationId: conversationId,
  );

  Future<void> blockUser({required String token, required int userId}) =>
      _api.messaging.blockMessageUser(token: token, userId: userId);

  Future<void> unblockUser({required String token, required int userId}) =>
      _api.messaging.unblockMessageUser(token: token, userId: userId);
}
