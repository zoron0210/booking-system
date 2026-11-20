import 'package:myapp/core/app_design_system.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/features/bookings/presentation/widgets/matchmaking_ticket_card.dart';
import 'package:myapp/features/messaging/presentation/messages_ui.dart';

class MessagesChatView extends StatelessWidget {
  const MessagesChatView({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.blocked,
    required this.composer,
    required this.pendingImageData,
    this.pendingGifUrl,
    this.pendingDocumentData,
    this.pendingDocumentName,
    required this.sending,
    this.composerError,
    this.onComposerChanged,
    required this.onDeleteMessage,
    this.onMatchmakingAction,
    this.onMatchmakingMerchantDecision,
    this.isMerchant = false,
    this.onOpponentPayment,
    this.replyTarget,
    this.onReplyToMessage,
    this.onClearReply,
    required this.onPickImage,
    required this.onRemovePendingImage,
    this.onPickDocument,
    this.onRemovePendingDocument,
    this.onPickGif,
    required this.onSend,
    this.scrollController,
  });

  final List<Map<String, dynamic>> messages;
  final int? currentUserId;
  final bool blocked;
  final TextEditingController composer;
  final String? pendingImageData;
  final String? pendingGifUrl;
  final String? pendingDocumentData;
  final String? pendingDocumentName;
  final bool sending;
  final String? composerError;
  final ValueChanged<String>? onComposerChanged;
  final ValueChanged<Map<String, dynamic>> onDeleteMessage;
  final Future<void> Function(Map<String, dynamic> ticket, bool accept)?
  onMatchmakingAction;
  final Future<void> Function(Map<String, dynamic> ticket, bool approve)?
  onMatchmakingMerchantDecision;
  final bool isMerchant;
  final Future<void> Function(Map<String, dynamic> ticket, String method)?
  onOpponentPayment;
  final Map<String, dynamic>? replyTarget;
  final ValueChanged<Map<String, dynamic>>? onReplyToMessage;
  final VoidCallback? onClearReply;
  final VoidCallback onPickImage;
  final VoidCallback onRemovePendingImage;
  final VoidCallback? onPickDocument;
  final VoidCallback? onRemovePendingDocument;
  final VoidCallback? onPickGif;
  final Future<void> Function() onSend;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: AppText('Write the first message.', localize: true),
                )
              : ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final mine = asInt(message['senderId']) == currentUserId;
                    final attachment = attachmentValue(message);
                    final body = messageBody(message);
                    final removedAt = message['removedAt'];
                    final attachmentType = safeString(attachment?['type']);
                    if (removedAt != null) {
                      final removedBy = safeString(
                        message['senderName'] ??
                            message['removedByName'] ??
                            [
                                  message['senderFirstName'],
                                  message['senderLastName'],
                                ]
                                .whereType<String>()
                                .where((part) => part.trim().isNotEmpty)
                                .join(' '),
                        'Someone',
                      ).trim();
                      final removedLabel = mine
                          ? appLanguageText(
                              'You deleted a message',
                              'You deleted a message',
                            )
                          : removedBy.isEmpty
                          ? appLanguageText(
                              'A message was deleted',
                              'A message was deleted',
                            )
                          : appLanguageText(
                              '{name} deleted a message',
                              '{name} deleted a message',
                            ).replaceAll('{name}', removedBy);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .76,
                            ),
                            child: Card(
                              key: ValueKey('message-bubble-${message['id']}'),
                              color: mine
                                  ? AppColors.softOrange
                                  : AppColors.surfaceVariant,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      removedLabel,
                                      key: ValueKey(
                                        'message-removed-${message['id']}',
                                      ),
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    if (_messageTime(message) case final time?)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (attachmentType == 'booking' ||
                        attachmentType == 'booking_payment_ticket' ||
                        attachmentType == 'booking_ticket') {
                      return GestureDetector(
                        onLongPress: () => onDeleteMessage(message),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Align(
                                key: ValueKey(
                                  'message-ticket-${message['id']}',
                                ),
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: MessagesBookingTicket(
                                  attachment!,
                                  key: ValueKey(
                                    'message-ticket-${message['id']}',
                                  ),
                                ),
                              ),
                              if (_messageTime(message) case final time?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    time,
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (attachmentType == 'matchmaking_ticket') {
                      return GestureDetector(
                        onLongPress: () => onDeleteMessage(message),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: MatchmakingTicketCard(
                              ticket: attachment!,
                              isHost: !mine && onMatchmakingAction != null,
                              onAction: onMatchmakingAction ?? (_, _) async {},
                              onOpponentPayment: onOpponentPayment,
                            ),
                          ),
                        ),
                      );
                    }
                    if (attachmentType ==
                        'matchmaking_booking_request_ticket') {
                      return GestureDetector(
                        onLongPress: () => onDeleteMessage(message),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: MatchmakingBookingRequestTicketCard(
                              ticket: attachment!,
                              isMerchant: isMerchant && !mine,
                              onDecision:
                                  onMatchmakingMerchantDecision ??
                                  (_, _) async {},
                            ),
                          ),
                        ),
                      );
                    }
                    final replyReference = _replyReference(message);
                    final bubble = Card(
                      key: ValueKey('message-bubble-${message['id']}'),
                      color: mine
                          ? AppColors.softOrange
                          : AppColors.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (replyReference != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? AppColors.surface.withValues(
                                          alpha: 0.45,
                                        )
                                      : AppColors.page,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      'Replying to ${replyReference['senderName'] ?? 'message'}',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AppText(
                                      replyReference['label'] ?? 'Message',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.ink,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if ((attachment != null &&
                                (safeString(attachment['type']) == 'image' ||
                                    safeString(attachment['type']) == 'gif')))
                              MessagesImageAttachment(attachment),
                            if (attachment != null &&
                                safeString(attachment['type']) == 'file')
                              MessagesFileAttachment(attachment),
                            if (body.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: AppText(
                                  body,
                                  key: ValueKey(
                                    'message-body-${message['id']}',
                                  ),
                                  style: TextStyle(color: AppColors.ink),
                                ),
                              ),
                            if (_messageTime(message) case final time?)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (mine && _isSeen(message['isSeen'])) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 14,
                                        color: AppColors.muted,
                                      ),
                                      const SizedBox(width: 4),
                                      AppText(
                                        'Seen',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        localize: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onHorizontalDragEnd: onReplyToMessage == null
                            ? null
                            : (details) {
                                final velocity =
                                    details.velocity.pixelsPerSecond.dx;
                                if (velocity > 450) {
                                  onReplyToMessage!(message);
                                }
                              },
                        onLongPress: () => onDeleteMessage(message),
                        child: bubble,
                      ),
                    );
                  },
                ),
        ),
        if (blocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.softStatus,
            child: AppText(
              'You blocked this person. Unblock them from chat options to send messages.',
              style: TextStyle(color: AppColors.ink, fontSize: 12),
              localize: true,
            ),
          ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingImageData != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(pendingImageData!.split(',').last),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onRemovePendingImage,
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: messageNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (pendingGifUrl case final gifUrl?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        Image.network(
                          gifUrl,
                          width: 110,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onRemovePendingImage,
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: messageNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (pendingDocumentName case final documentName?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            documentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              onRemovePendingDocument ?? onRemovePendingImage,
                          icon: const Icon(Icons.close_rounded),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              if (replyTarget != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.softOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Replying to ${_replySenderName(replyTarget!)}',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AppText(
                                _replyLabel(replyTarget!),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClearReply ?? () {},
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: appLanguageText('Attach image', 'Attach image'),
                    onPressed: sending || blocked ? null : onPickImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: appLanguageText('Attach file', 'Attach file'),
                    onPressed: sending || blocked ? null : onPickDocument,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  IconButton(
                    tooltip: 'Add GIF',
                    onPressed: sending || blocked ? null : onPickGif,
                    icon: const Icon(Icons.gif_box_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('messages-chat-composer'),
                      controller: composer,
                      enabled: !blocked,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 6,
                      onChanged: onComposerChanged,
                      decoration: InputDecoration(
                        errorText: composerError,
                        hintText: appLanguageText(
                          'Write a message...',
                          'Write a message...',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: sending || blocked ? null : onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic>? _replyReference(Map<String, dynamic> message) {
  final raw = message['reply'];
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(raw);
}

String _replySenderName(Map<String, dynamic> reply) {
  final value = safeString(reply['senderName'], '');
  if (value.isNotEmpty) return value;
  final first = safeString(reply['senderFirstName'], '');
  final last = safeString(reply['senderLastName'], '');
  final name = [first, last].where((part) => part.trim().isNotEmpty).join(' ');
  return name.isNotEmpty ? name : 'Message';
}

String _replyLabel(Map<String, dynamic> reply) {
  final label = safeString(reply['label']);
  if (label.isNotEmpty) return label;
  final body = safeString(reply['body']);
  if (body.isNotEmpty) {
    return body.length > 120 ? '${body.substring(0, 117)}...' : body;
  }
  final attachment = reply['attachment'];
  if (attachment is Map) {
    final type = safeString(attachment['type']);
    if (type == 'image') return 'Photo';
    if (type == 'gif') return 'GIF';
    if (type == 'file') return safeString(attachment['name'], 'File');
  }
  return 'Message';
}

String? _messageTime(Map<String, dynamic> message) {
  final createdAt = DateTime.tryParse('${message['createdAt'] ?? ''}');
  if (createdAt == null) return null;

  final localTime = createdAt.toLocal();
  final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
  final minute = localTime.minute.toString().padLeft(2, '0');
  final period = localTime.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

bool _isSeen(dynamic value) => value == true || value == 1 || value == '1';
