import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_text.dart';
import 'auth_api.dart';
import 'guest_access.dart';
import 'features/session/application/session_service.dart';
import 'features/social/presentation/social_profile_stats.dart';
import 'messages_dashboard.dart';
import 'social_profile_section.dart';

Future<void> openPublicUserProfile({
  required BuildContext context,
  required AuthApi api,
  required String? token,
  required int userId,
  Future<void> Function()? onFollowChanged,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PublicUserProfilePage(
        api: api,
        token: token,
        userId: userId,
        onFollowChanged: onFollowChanged,
      ),
    ),
  );
}

Future<void> showUserConnections({
  required BuildContext context,
  required AuthApi api,
  required String? token,
  required int userId,
  required String type,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      _UserConnectionsSheet(api: api, token: token, userId: userId, type: type),
);

class PublicUserProfilePage extends StatefulWidget {
  const PublicUserProfilePage({
    super.key,
    required this.api,
    required this.token,
    required this.userId,
    this.onFollowChanged,
  });

  final AuthApi api;
  final String? token;
  final int userId;
  final Future<void> Function()? onFollowChanged;

  @override
  State<PublicUserProfilePage> createState() => _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends State<PublicUserProfilePage> {
  Map<String, dynamic>? _profile;
  Object? _error;
  bool _loading = true;
  bool _updatingFollow = false;
  bool _openingMessage = false;

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
      final profile = await widget.api.socialUserProfile(
        token: widget.token,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_updatingFollow || _profile == null) return;
    var token = widget.token;
    if (token == null || token.isEmpty) {
      if (!await requireCustomerLogin(context) || !mounted) return;
      token = (await AppSessionService.instance.load()).apiToken;
      if (token == null || token.isEmpty) return;
    }
    final wasFollowing = _profile!['isFollowing'] == true;
    setState(() => _updatingFollow = true);
    try {
      if (wasFollowing) {
        await widget.api.unfollowSocialUser(
          token: token,
          userId: widget.userId,
        );
      } else {
        await widget.api.followSocialUser(token: token, userId: widget.userId);
      }
      if (!mounted) return;
      final count = (_profile?['followersCount'] as num?)?.toInt() ?? 0;
      setState(() {
        _profile = {
          ...?_profile,
          'isFollowing': !wasFollowing,
          'followersCount': count + (wasFollowing ? -1 : 1),
        };
      });
      await widget.onFollowChanged?.call();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Could not update follow status: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  Future<void> _messageUser() async {
    if (_openingMessage) return;
    final recipientId = (_profile?['id'] as num?)?.toInt() ?? widget.userId;
    if (recipientId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('This profile cannot receive messages.'),
        ),
      );
      return;
    }
    var token = widget.token;
    if (token == null || token.isEmpty) {
      if (!await requireCustomerLogin(context) || !mounted) return;
      token = (await AppSessionService.instance.load()).apiToken;
      if (token == null || token.isEmpty) return;
    }

    setState(() => _openingMessage = true);
    try {
      final conversationId = await widget.api.openConversation(
        token: token,
        participantIds: [recipientId],
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MessagesDashboardPage(
            api: widget.api,
            initialConversationId: conversationId,
          ),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('Could not open this conversation: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _profile?['avatarUrl'];
    final provider = _avatarProvider(avatar);
    final posts = (_profile?['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final businesses = (_profile?['businesses'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Scaffold(
      key: const ValueKey('public-user-profile-page'),
      backgroundColor: AppColors.page,
      appBar: AppBar(
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const AppText(
          'Player Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText('Could not load this profile: $_error'),
                    TextButton(onPressed: _load, child: const AppText('Retry')),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    key: const ValueKey('public-profile-page-scroll-view'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Container(
                        key: const ValueKey('public-profile-header'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: CircleAvatar(
                                  key: const ValueKey(
                                    'public-user-profile-avatar',
                                  ),
                                  radius: 48,
                                  backgroundColor: AppColors.softSurface,
                                  backgroundImage: provider,
                                  child: provider == null
                                      ? const Icon(
                                          Icons.person_outline_rounded,
                                          size: 40,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: AppText(
                                '${_profile?['displayName'] ?? 'SpotGo user'}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SocialProfileStats(
                              postsCount:
                                  _profile?['postsCount'] ?? posts.length,
                              followersCount: _profile?['followersCount'],
                              followingCount: _profile?['followingCount'],
                              foregroundColor: AppColors.ink,
                              mutedColor: AppColors.muted,
                              onFollowersTap: () => showUserConnections(
                                context: context,
                                api: widget.api,
                                token: widget.token,
                                userId: widget.userId,
                                type: 'followers',
                              ),
                              onFollowingTap: () => showUserConnections(
                                context: context,
                                api: widget.api,
                                token: widget.token,
                                userId: widget.userId,
                                type: 'following',
                              ),
                            ),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: AppColors.borderSubtle),
                            const SizedBox(height: 10),
                            AppText(
                              'Bio',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              localize: true,
                            ),
                            const SizedBox(height: 3),
                            AppText(
                              '${_profile?['hobby'] ?? ''}'.trim().isEmpty
                                  ? 'No bio added yet.'
                                  : '${_profile?['hobby']}'.trim(),
                              key: const ValueKey('public-user-profile-bio'),
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                              ),
                              localize: '${_profile?['hobby'] ?? ''}'
                                  .trim()
                                  .isEmpty,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    key: const ValueKey(
                                      'public-user-follow-button',
                                    ),
                                    onPressed: _updatingFollow
                                        ? null
                                        : _toggleFollow,
                                    icon: Icon(
                                      _profile?['isFollowing'] == true
                                          ? Icons.check_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                                    label: AppText(
                                      _profile?['isFollowing'] == true
                                          ? 'Following'
                                          : 'Follow',
                                      localize: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                      'public-user-message-button',
                                    ),
                                    onPressed: _openingMessage
                                        ? null
                                        : _messageUser,
                                    icon: _openingMessage
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                          ),
                                    label: const AppText(
                                      'Message',
                                      localize: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppText(
                                    'Experiences',
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                AppText(
                                  '${posts.length}',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (posts.isEmpty && businesses.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: AppText(
                                    'No public experiences yet.',
                                    localize: true,
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                key: const ValueKey(
                                  'public-user-experiences-grid',
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 5,
                                      mainAxisSpacing: 5,
                                    ),
                                itemCount: posts.length + businesses.length,
                                itemBuilder: (context, index) {
                                  if (index >= posts.length) {
                                    final business =
                                        businesses[index - posts.length];
                                    final image =
                                        '${business['imageUrl'] ?? ''}'.trim();
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: image.isEmpty
                                          ? ColoredBox(
                                              color: AppColors.softSurface,
                                              child: const Icon(
                                                Icons.storefront_outlined,
                                              ),
                                            )
                                          : socialExperienceImage(image),
                                    );
                                  }
                                  final post = posts[index];
                                  final images =
                                      (post['images'] as List<dynamic>? ?? [])
                                          .whereType<String>()
                                          .toList();
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        images.isEmpty
                                            ? ColoredBox(
                                                color: AppColors.softSurface,
                                                child: const Icon(
                                                  Icons.photo_outlined,
                                                ),
                                              )
                                            : socialExperienceImage(
                                                images.first,
                                              ),
                                        if ('${post['caption'] ?? ''}'
                                            .trim()
                                            .isNotEmpty)
                                          Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(5),
                                              color: Colors.black.withValues(
                                                alpha: .58,
                                              ),
                                              child: AppText(
                                                '${post['caption']}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _UserConnectionsSheet extends StatefulWidget {
  const _UserConnectionsSheet({
    required this.api,
    required this.token,
    required this.userId,
    required this.type,
  });

  final AuthApi api;
  final String? token;
  final int userId;
  final String type;

  @override
  State<_UserConnectionsSheet> createState() => _UserConnectionsSheetState();
}

class _UserConnectionsSheetState extends State<_UserConnectionsSheet> {
  List<Map<String, dynamic>> _users = const [];
  Object? _error;
  bool _loading = true;

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
      final users = await widget.api.socialUserConnections(
        token: widget.token,
        userId: widget.userId,
        type: widget.type,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .72,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: AppText(
                  widget.type == 'followers' ? 'Followers' : 'Following',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText('Could not load ${widget.type}: $_error'),
                      TextButton(
                        onPressed: _load,
                        child: const AppText('Retry'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
              ? Center(
                  child: AppText(
                    widget.type == 'followers'
                        ? 'No followers yet.'
                        : 'Not following anyone yet.',
                    localize: true,
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final provider = _avatarProvider(user['avatarUrl']);
                    final connectedUserId = (user['id'] as num?)?.toInt();
                    return ListTile(
                      key: ValueKey('social-connection-${user['id']}'),
                      leading: CircleAvatar(
                        backgroundImage: provider,
                        child: provider == null
                            ? const Icon(Icons.person_outline_rounded)
                            : null,
                      ),
                      title: AppText('${user['displayName'] ?? 'SpotGo user'}'),
                      subtitle: AppText(
                        '${(user['followersCount'] as num?)?.toInt() ?? 0} followers',
                        localize: true,
                      ),
                      onTap: connectedUserId == null
                          ? null
                          : () => openPublicUserProfile(
                              context: context,
                              api: widget.api,
                              token: widget.token,
                              userId: connectedUserId,
                            ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

ImageProvider<Object>? _avatarProvider(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final image = value.trim();
  if (image.startsWith('data:image/')) {
    final separator = image.indexOf(',');
    if (separator < 0 || separator == image.length - 1) return null;
    try {
      return MemoryImage(base64Decode(image.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }
  final uri = Uri.tryParse(image);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return NetworkImage(image);
}
