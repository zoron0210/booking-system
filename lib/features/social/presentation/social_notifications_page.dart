import 'package:flutter/material.dart';

import '../../../auth_api.dart';
import '../../../public_user_profile.dart';
import 'social_home_palette.dart';

class SocialNotificationsPage extends StatefulWidget {
  const SocialNotificationsPage({
    super.key,
    required this.api,
    required this.token,
    this.onUnreadCountChanged,
  });

  final AuthApi api;
  final String token;
  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<SocialNotificationsPage> createState() =>
      _SocialNotificationsPageState();
}

class _SocialNotificationsPageState extends State<SocialNotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  Object? _error;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.socialNotifications(widget.token);
      if (!mounted) return;
      final notifications = (response['notifications'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final unreadCount = (response['unreadCount'] as num?)?.toInt() ?? 0;
      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
      widget.onUnreadCountChanged?.call(unreadCount);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_updating || _unreadCount == 0) return;
    setState(() => _updating = true);
    try {
      await widget.api.markAllSocialNotificationsRead(widget.token);
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
        _notifications = _notifications
            .map((notification) => {
                  ...notification,
                  'readAt': DateTime.now().toIso8601String(),
                })
            .toList();
      });
      widget.onUnreadCountChanged?.call(0);
    } on Exception catch (error) {
      if (mounted) _showError('Could not mark notifications as read: $error');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = (notification['id'] as num?)?.toInt();
    final isUnread = notification['readAt'] == null;
    if (isUnread && id != null) {
      try {
        await widget.api.markSocialNotificationRead(
          token: widget.token,
          notificationId: id,
        );
        if (!mounted) return;
        setState(() {
          _notifications = _notifications
              .map(
                (item) => item['id'] == notification['id']
                    ? {
                        ...item,
                        'readAt': DateTime.now().toIso8601String(),
                      }
                    : item,
              )
              .toList();
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount).toInt();
        });
        widget.onUnreadCountChanged?.call(_unreadCount);
      } on Exception catch (error) {
        if (mounted) _showError('Could not update this notification: $error');
      }
    }

    final targetUserId = notification['type'] == 'follow'
        ? notification['actorUserId']
        : notification['postOwnerId'];
    final userId = (targetUserId as num?)?.toInt();
    if (userId == null || !mounted) return;
    await openPublicUserProfile(
      context: context,
      api: widget.api,
      token: widget.token,
      userId: userId,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              key: const ValueKey('social-notifications-mark-all-read'),
              tooltip: 'Mark all as read',
              onPressed: _updating ? null : _markAllRead,
              icon: const Icon(Icons.mark_email_read_outlined),
            ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(SocialHomeColors colors) {
    if (_loading && _notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('social-notifications-loading')),
      );
    }
    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Could not load notifications. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: colors.muted,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'You’re all caught up',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reactions, comments, follows, and new posts from people you follow will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const ValueKey('social-notifications-list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 72,
          color: colors.border,
        ),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final actorName = _actorName(notification);
          final type = notification['type'];
          final unread = notification['readAt'] == null;
          final excerpt = type == 'comment'
              ? notification['commentText']
              : type == 'post'
              ? notification['postCaption']
              : null;
          return ListTile(
            key: ValueKey('social-notification-${notification['id']}'),
            onTap: () => _openNotification(notification),
            tileColor: unread ? colors.primary.withValues(alpha: .08) : null,
            leading: CircleAvatar(
              backgroundColor: colors.surfaceRaised,
              foregroundColor: colors.primary,
              child: Icon(_notificationIcon(type)),
            ),
            title: Text(
              _notificationTitle(type, actorName),
              style: TextStyle(
                color: colors.text,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (excerpt is String && excerpt.trim().isNotEmpty)
                    Text(
                      excerpt.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted),
                    ),
                  Text(
                    _notificationTime(notification['createdAt']),
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            trailing: unread
                ? Icon(Icons.circle, size: 10, color: colors.coral)
                : null,
          );
        },
      ),
    );
  }
}

String _actorName(Map<String, dynamic> notification) {
  final name = [notification['actorFirstName'], notification['actorLastName']]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');
  return name.isEmpty ? 'Someone' : name;
}

String _notificationTitle(dynamic type, String actorName) => switch (type) {
  'like' => '$actorName reacted to your post',
  'comment' => '$actorName commented on your post',
  'follow' => '$actorName started following you',
  'post' => '$actorName shared a new post',
  _ => '$actorName interacted with you',
};

IconData _notificationIcon(dynamic type) => switch (type) {
  'like' => Icons.favorite_rounded,
  'comment' => Icons.chat_bubble_rounded,
  'follow' => Icons.person_add_alt_1_rounded,
  'post' => Icons.post_add_rounded,
  _ => Icons.notifications_rounded,
};

String _notificationTime(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
