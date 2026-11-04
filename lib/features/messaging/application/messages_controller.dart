import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myapp/core/live_updates_client.dart';

import 'package:myapp/features/messaging/data/messages_session_provider.dart';
import 'package:myapp/features/messaging/data/messages_service.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    MessagesService? service,
    MessagesSessionProvider? sessionProvider,
    LiveUpdatesClient Function()? liveUpdatesClientFactory,
    this.businessType,
  }) : _service = service ?? MessagesService(),
       _sessionProvider = sessionProvider ?? AppMessagesSessionProvider(),
       _liveUpdatesClientFactory =
           liveUpdatesClientFactory ?? LiveUpdatesClient.new;

  static const _realtimeRefreshInterval = Duration(seconds: 15);

  final MessagesService _service;
  final MessagesSessionProvider _sessionProvider;
  final LiveUpdatesClient Function() _liveUpdatesClientFactory;
  final String? businessType;

  String? token;
  String? role;
  int? currentUserId;
  int? selectedConversationId;
  List<Map<String, dynamic>> conversations = const [];
  List<Map<String, dynamic>> contacts = const [];
  List<Map<String, dynamic>> messages = const [];
  bool loading = true;
  bool sending = false;
  bool showChat = false;
  bool showArchivedConversations = false;
  bool showBlockedConversations = false;
  String conversationQuery = '';
  int loadRequestId = 0;
  int messageRequestId = 0;
  int conversationStateRevision = 0;
  Timer? realtimeTimer;
  bool realtimeRefreshInFlight = false;
  bool _isDisposed = false;
  LiveUpdatesClient? _realtimeClient;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  String? _realtimeToken;

  int get unreadMessageCount => conversations.fold<int>(
    0,
    (total, conversation) =>
        total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
  );

  Future<void> load() async {
    final requestId = ++loadRequestId;
    try {
      final session = await _sessionProvider.load();
      final sessionToken = session.apiToken;
      if (sessionToken == null || sessionToken.isEmpty) {
        if (requestId != loadRequestId) return;
        _stopRealtimeUpdates();
        token = null;
        role = session.role ?? 'guest';
        currentUserId = null;
        conversations = const [];
        contacts = const [];
        messages = const [];
        loading = false;
        notifyListeners();
        return;
      }

      final loadedConversations = await _service.fetchConversations(
        sessionToken,
        businessType: businessType,
      );
      final loadedContacts = await _service.fetchContacts(sessionToken);
      final currentUser = await _service.fetchCurrentUser(sessionToken);

      if (requestId != loadRequestId) return;

      final currentUserData = currentUser['user'];
      final currentUserRole = currentUserData is Map<String, dynamic>
          ? currentUserData['role']
          : null;
      final currentUserIdValue = currentUserData is Map<String, dynamic>
          ? currentUserData['id']
          : null;
      token = sessionToken;
      role =
          currentUserRole is String &&
              (currentUserRole == 'customer' || currentUserRole == 'merchant')
          ? currentUserRole
          : session.role;
      currentUserId = currentUserIdValue is num
          ? currentUserIdValue.toInt()
          : null;
      conversations = loadedConversations;
      contacts = loadedContacts;
      loading = false;
      notifyListeners();

      startRealtimeUpdates();
    } on Exception {
      if (requestId == loadRequestId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<int?> openOwnerConversation({
    required int ownerId,
    String? businessTitle,
  }) async {
    final sessionToken = token;
    if (sessionToken == null) return null;

    try {
      final id = await _service.openConversation(
        token: sessionToken,
        recipientId: ownerId,
        title: businessTitle,
      );
      await load();
      return id;
    } catch (_) {
      rethrow;
    }
  }

  void startRealtimeUpdates() {
    final sessionToken = token;
    if (sessionToken == null || sessionToken == _realtimeToken) return;
    _stopRealtimeUpdates();

    final client = _liveUpdatesClientFactory();
    _realtimeClient = client;
    _realtimeToken = sessionToken;
    _realtimeSubscription = client.events.listen(
      (event) {
        if (event['type'] == 'message.created') {
          unawaited(refreshRealtime());
        }
      },
      onError: (_, _) => _startPollingFallback(client),
      onDone: () => _startPollingFallback(client),
    );
    unawaited(_connectRealtime(client, sessionToken));
  }

  Future<void> _connectRealtime(
    LiveUpdatesClient client,
    String sessionToken,
  ) async {
    try {
      await client.connect(sessionToken);
      if (client != _realtimeClient || sessionToken != token) {
        await client.close();
        return;
      }
      realtimeTimer?.cancel();
      realtimeTimer = null;
    } on Object {
      _startPollingFallback(client);
    }
  }

  void _startPollingFallback(LiveUpdatesClient client) {
    if (client != _realtimeClient || realtimeTimer != null) return;
    realtimeTimer = Timer.periodic(
      _realtimeRefreshInterval,
      (_) => unawaited(refreshRealtime()),
    );
  }

  void _stopRealtimeUpdates() {
    final client = _realtimeClient;
    realtimeTimer?.cancel();
    realtimeTimer = null;
    _realtimeToken = null;
    _realtimeClient = null;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    if (client != null) unawaited(client.close());
  }

  Future<void> refreshRealtime() async {
    final sessionToken = token;
    if (sessionToken == null || realtimeRefreshInFlight) return;

    realtimeRefreshInFlight = true;
    try {
      final stateRevision = conversationStateRevision;
      final messageRequestIdAtStart = messageRequestId;
      final selectedConversation = selectedConversationId;
      final conversationsFuture = _service.fetchConversations(
        sessionToken,
        businessType: businessType,
      );
      final messagesFuture = selectedConversation == null
          ? null
          : _service.fetchMessages(
              token: sessionToken,
              conversationId: selectedConversation,
              businessType: businessType,
            );

      final loadedConversations = await conversationsFuture;
      final loadedMessages = messagesFuture == null
          ? null
          : await messagesFuture;

      if (sessionToken != token || stateRevision != conversationStateRevision) {
        return;
      }
      if (_isDisposed) return;

      conversations = loadedConversations;
      if (selectedConversation != null &&
          selectedConversation == selectedConversationId &&
          messageRequestIdAtStart == messageRequestId &&
          loadedMessages != null) {
        messages = loadedMessages;
        _markConversationRead(selectedConversation);
      }
      notifyListeners();
    } finally {
      realtimeRefreshInFlight = false;
    }
  }

  Future<void> select(int id) async {
    final sessionToken = token;
    if (sessionToken == null) return;

    final requestId = beginSelectingConversation(id);

    try {
      final loadedMessages = await _service.fetchMessages(
        token: sessionToken,
        conversationId: id,
        businessType: businessType,
      );
      if (requestId != messageRequestId) return;
      if (selectedConversationId != id) return;
      messages = loadedMessages;
      _markConversationRead(id);
      notifyListeners();
      await _service.setConversationState(
        token: sessionToken,
        conversationId: id,
        unread: false,
      );
    } on Exception {
      if (requestId == messageRequestId) {
        notifyListeners();
      }
      rethrow;
    }
  }

  void setConversationQuery(String value) {
    conversationQuery = value;
    notifyListeners();
  }

  void clearConversationQuery() {
    conversationQuery = '';
    notifyListeners();
  }

  void setShowArchivedConversations(bool value) {
    showArchivedConversations = value;
    if (value) showBlockedConversations = false;
    notifyListeners();
  }

  void setShowBlockedConversations(bool value) {
    showBlockedConversations = value;
    if (value) showArchivedConversations = false;
    notifyListeners();
  }

  int beginSelectingConversation(int id) {
    final requestId = ++messageRequestId;
    if (selectedConversationId != id) {
      messages = const [];
    }
    selectedConversationId = id;
    showChat = true;
    notifyListeners();
    return requestId;
  }

  void setSelectedConversation(int id) {
    beginSelectingConversation(id);
  }

  void setMessages(List<Map<String, dynamic>> nextMessages) {
    messages = nextMessages;
    final selectedId = selectedConversationId;
    if (selectedId != null) _markConversationRead(selectedId);
    notifyListeners();
  }

  void setConversationArchived(int conversationId, bool archived) {
    conversationStateRevision++;
    conversations = conversations
        .map(
          (conversation) =>
              (conversation['id'] as num?)?.toInt() == conversationId
              ? {...conversation, 'archived': archived}
              : conversation,
        )
        .toList();
    notifyListeners();
  }

  void setUserBlocked(int userId, bool blocked) {
    conversationStateRevision++;
    conversations = conversations.map((conversation) {
      final members = conversation['members'] as List<dynamic>? ?? const [];
      final includesUser = members.whereType<Map>().any(
        (member) => (member['id'] as num?)?.toInt() == userId,
      );
      return includesUser
          ? {...conversation, 'blockedByMe': blocked}
          : conversation;
    }).toList();
    notifyListeners();
  }

  void _markConversationRead(int conversationId) {
    conversationStateRevision++;
    Map<String, dynamic>? selectedConversation;
    for (final conversation in conversations) {
      if ((conversation['id'] as num?)?.toInt() == conversationId) {
        selectedConversation = conversation;
        break;
      }
    }
    final selectedPeerId = _directPeerId(selectedConversation);
    final selectedArchived = _isArchived(selectedConversation?['archived']);
    conversations = conversations.map((conversation) {
      final isSelected =
          (conversation['id'] as num?)?.toInt() == conversationId;
      final isMergedDirectChat =
          selectedPeerId != null &&
          _directPeerId(conversation) == selectedPeerId &&
          _isArchived(conversation['archived']) == selectedArchived;
      if (!isSelected && !isMergedDirectChat) {
        return conversation;
      }
      return {...conversation, 'unreadCount': 0, 'manuallyUnread': false};
    }).toList();
  }

  int? _directPeerId(Map<String, dynamic>? conversation) {
    if (conversation == null || conversation['type'] != 'direct') return null;
    final members = conversation['members'] as List<dynamic>? ?? const [];
    final otherMembers = members.whereType<Map>().where((member) {
      return (member['id'] as num?)?.toInt() != currentUserId;
    });
    if (otherMembers.length != 1) return null;
    return (otherMembers.first['id'] as num?)?.toInt();
  }

  bool _isArchived(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  void setSending(bool nextSending) {
    sending = nextSending;
    notifyListeners();
  }

  void backToInbox() {
    messageRequestId++;
    showChat = false;
    selectedConversationId = null;
    messages = const [];
    notifyListeners();
  }

  void disposeController() {
    _stopRealtimeUpdates();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopRealtimeUpdates();
    super.dispose();
  }
}
