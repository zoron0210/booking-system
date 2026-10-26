import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'guest_access.dart';
import 'features/session/application/session_service.dart';

Future<void> showPublicUserProfileDialog({
  required BuildContext context,
  required AuthApi api,
  required String? token,
  required int userId,
  required Future<void> Function() onViewProfile,
  Future<void> Function()? onFollowChanged,
}) async {
  final viewProfile = await showDialog<bool>(
    context: context,
    builder: (_) => _PublicUserProfileDialog(
      api: api,
      token: token,
      userId: userId,
      onFollowChanged: onFollowChanged,
    ),
  );
  if (viewProfile == true && context.mounted) await onViewProfile();
}

Future<void> showUserConnections({
  required BuildContext context,
  required AuthApi api,
  required String? token,
  required int userId,
  required String type,
  required Future<void> Function(int userId) onOpenProfile,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _UserConnectionsSheet(
    api: api,
    token: token,
    userId: userId,
    type: type,
    onOpenProfile: onOpenProfile,
  ),
);

class _PublicUserProfileDialog extends StatefulWidget {
  const _PublicUserProfileDialog({
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
  State<_PublicUserProfileDialog> createState() =>
      _PublicUserProfileDialogState();
}

class _PublicUserProfileDialogState extends State<_PublicUserProfileDialog> {
  Map<String, dynamic>? _profile;
  Object? _error;
  bool _loading = true;
  bool _updatingFollow = false;

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
        await widget.api.followSocialUser(
          token: token,
          userId: widget.userId,
        );
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

  @override
  Widget build(BuildContext context) {
    final avatar = _profile?['avatarUrl'];
    final provider = _avatarProvider(avatar);
    return AlertDialog(
      key: const ValueKey('public-user-profile-dialog'),
      content: SizedBox(
        width: 360,
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText('Could not load this profile: $_error'),
                  TextButton(onPressed: _load, child: const AppText('Retry')),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  CircleAvatar(
                    key: const ValueKey('public-user-profile-avatar'),
                    radius: 52,
                    backgroundImage: provider,
                    child: provider == null
                        ? const Icon(Icons.person_outline_rounded, size: 42)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  AppText(
                    '${_profile?['displayName'] ?? 'SpotGo user'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Count(label: 'Followers', value: _profile?['followersCount']),
                      const SizedBox(width: 36),
                      _Count(label: 'Following', value: _profile?['followingCount']),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('public-user-follow-button'),
                          onPressed: _updatingFollow ? null : _toggleFollow,
                          child: AppText(
                            _profile?['isFollowing'] == true
                                ? 'Following'
                                : 'Follow',
                            localize: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey(
                            'public-user-view-profile-button',
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const AppText(
                            'View profile',
                            localize: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
    required this.onOpenProfile,
  });

  final AuthApi api;
  final String? token;
  final int userId;
  final String type;
  final Future<void> Function(int userId) onOpenProfile;

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
                      TextButton(onPressed: _load, child: const AppText('Retry')),
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
                    final id = (user['id'] as num?)?.toInt();
                    final provider = _avatarProvider(user['avatarUrl']);
                    return ListTile(
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
                      onTap: id == null
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await widget.onOpenProfile(id);
                            },
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppText(
        '${(value as num?)?.toInt() ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      AppText(label, localize: true),
    ],
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
