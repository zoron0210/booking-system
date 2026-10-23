import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'features/session/application/session_service.dart';
import 'social_profile_section.dart';
import 'public_user_profile.dart';

const _maxSocialPhotos = 5;
const _maxSocialPhotoBytes = 10 * 1024 * 1024;
const _maxSocialPayloadChars = 18 * 1024 * 1024;

class SocialCommunityPage extends StatefulWidget {
  const SocialCommunityPage({
    super.key,
    required this.api,
    this.composeOnOpen = false,
  });

  final AuthApi api;
  final bool composeOnOpen;

  @override
  State<SocialCommunityPage> createState() => _SocialCommunityPageState();
}

class _SocialCommunityPageState extends State<SocialCommunityPage> {
  final _searchController = TextEditingController();
  String? _token;
  List<Map<String, dynamic>> _feed = [];
  List<Map<String, dynamic>> _users = [];
  bool _loadingFeed = true;
  bool _loadingUsers = true;
  bool _posting = false;
  bool _didInitialCompose = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await AppSessionService.instance.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _token = null;
            _loadingFeed = false;
            _loadingUsers = false;
          });
        }
        return;
      }
      if (mounted) setState(() => _token = token);
      await Future.wait([_loadFeed(token), _loadUsers(token)]);
      if (socialPostingEnabled &&
          widget.composeOnOpen &&
          !_didInitialCompose &&
          mounted) {
        _didInitialCompose = true;
        await _composePost();
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loadingFeed = false;
          _loadingUsers = false;
        });
        _showMessage('Could not load the community: $error');
      }
    }
  }

  Future<void> _loadFeed([String? suppliedToken]) async {
    final token = suppliedToken ?? _token;
    if (token == null) return;
    if (mounted) setState(() => _loadingFeed = true);
    try {
      final posts = await widget.api.socialFeed(token);
      if (mounted) setState(() => _feed = posts);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not load community posts: $error');
    } finally {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  Future<void> _loadUsers([String? suppliedToken]) async {
    final token = suppliedToken ?? _token;
    if (token == null) return;
    if (mounted) setState(() => _loadingUsers = true);
    try {
      final users = await widget.api.searchSocialUsers(
        token,
        query: _searchController.text,
      );
      if (mounted) setState(() => _users = users);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not find community profiles: $error');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final id = (user['id'] as num?)?.toInt();
    if (id == null) return;
    final wasFollowing = user['isFollowing'] == true;
    setState(() {
      user['isFollowing'] = !wasFollowing;
      final count = (user['followersCount'] as num?)?.toInt() ?? 0;
      user['followersCount'] = count + (wasFollowing ? -1 : 1);
    });
    try {
      if (wasFollowing) {
        await widget.api.unfollowSocialUser(token: token, userId: id);
      } else {
        await widget.api.followSocialUser(token: token, userId: id);
      }
      await _loadFeed();
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          user['isFollowing'] = wasFollowing;
          final count = (user['followersCount'] as num?)?.toInt() ?? 0;
          user['followersCount'] = count + (wasFollowing ? 1 : -1);
        });
        _showMessage('Could not update follow status: $error');
      }
    }
  }

  Future<void> _openPerson(Map<String, dynamic> user) async {
    final id = (user['id'] as num?)?.toInt();
    final token = _token;
    if (id == null || token == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialPersonPage(
          api: widget.api,
          token: token,
          userId: id,
          onFollowChanged: _loadUsers,
        ),
      ),
    );
    await _loadFeed();
    await _loadUsers();
  }

  Future<void> _composePost() async {
    if (_token == null || _posting) return;
    final draft = await showModalBottomSheet<_SocialPostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _SocialPostComposer(),
    );
    if (draft == null || !mounted) return;
    setState(() => _posting = true);
    try {
      await widget.api.createSocialPost(
        token: _token!,
        caption: draft.caption,
        images: draft.images,
      );
      if (!mounted) return;
      _showMessage('Your experience has been shared.');
      await _loadFeed();
      await _loadUsers();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.userMessage);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not share your experience: $error');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text, localize: true)));
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Community', localize: true)),
        body: Center(
          child: _loadingFeed || _loadingUsers
              ? const CircularProgressIndicator()
              :                 const AppText('Sign in to follow people.', localize: true),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Community', localize: true),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dynamic_feed_outlined), text: 'Following'),
              Tab(icon: Icon(Icons.people_outline_rounded), text: 'People'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildFeed(), _buildPeople()]),
        floatingActionButton: socialPostingEnabled
            ? FloatingActionButton.extended(
                key: const ValueKey('social-community-create-post'),
                onPressed: _posting ? null : _composePost,
                icon: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: const AppText('Share experience', localize: true),
              )
            : null,
      ),
    );
  }

  Widget _buildFeed() {
    if (_loadingFeed && _feed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.groups_2_outlined, size: 52),
          const SizedBox(height: 12),
          const AppText(
            'Your community feed is quiet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            localize: true,
          ),
          const SizedBox(height: 8),
          const AppText(
            'Follow people to see their sports photos and experiences here.',
            textAlign: TextAlign.center,
            localize: true,
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              icon: const Icon(Icons.search_rounded),
              label: const AppText('Find people', localize: true),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
        itemCount: _feed.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _SocialPostCard(
          post: _feed[index],
          onOpenPerson: socialProfileUiEnabled
              ? () => _openPerson(_feed[index])
              : null,
          onFollow: null,
        ),
      ),
    );
  }

  Widget _buildPeople() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loadUsers(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search people',
            suffixIcon: IconButton(
              tooltip: 'Search people',
              onPressed: _loadUsers,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      Expanded(
        child: _loadingUsers && _users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: _users.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: AppText('No people found.', localize: true),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: _users.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _SocialPersonTile(
                            user: user,
                            onTap: socialProfileUiEnabled
                                ? () => _openPerson(user)
                                : null,
                            onFollow: () => _toggleFollow(user),
                          );
                        },
                      ),
              ),
      ),
    ],
  );
}

class _SocialPersonTile extends StatelessWidget {
  const _SocialPersonTile({
    required this.user,
    required this.onTap,
    required this.onFollow,
  });

  final Map<String, dynamic> user;
  final VoidCallback? onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final avatar = user['avatarUrl'] as String?;
    final avatarProvider = avatar == null || avatar.isEmpty
        ? null
        : _socialAvatarProvider(avatar);
    final following = user['isFollowing'] == true;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: avatarProvider,
        child: avatarProvider == null
            ? const Icon(Icons.person_outline_rounded)
            : null,
      ),
      title: AppText(
        '${user['displayName'] ?? 'TinkerPro user'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: AppText(
        '${(user['followersCount'] as num?)?.toInt() ?? 0} followers',
        localize: true,
      ),
      trailing: OutlinedButton(
        onPressed: onFollow,
        child: AppText(following ? 'Following' : 'Follow', localize: true),
      ),
    );
  }
}

class SocialPersonPage extends StatefulWidget {
  const SocialPersonPage({
    super.key,
    required this.api,
    required this.token,
    required this.userId,
    this.onFollowChanged,
  });

  final AuthApi api;
  final String token;
  final int userId;
  final Future<void> Function()? onFollowChanged;

  @override
  State<SocialPersonPage> createState() => _SocialPersonPageState();
}

class _SocialPersonPageState extends State<SocialPersonPage> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _updatingFollow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.socialUserProfile(
        token: widget.token,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = (profile['posts'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Could not load profile: $error')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_updatingFollow) return;
    setState(() => _updatingFollow = true);
    final following = _profile?['isFollowing'] == true;
    try {
      if (following) {
        await widget.api.unfollowSocialUser(
          token: widget.token,
          userId: widget.userId,
        );
      } else {
        await widget.api.followSocialUser(
          token: widget.token,
          userId: widget.userId,
        );
      }
      if (!mounted) return;
      final count = (_profile?['followersCount'] as num?)?.toInt() ?? 0;
      setState(() {
        _profile = {
          ...?_profile,
          'isFollowing': !following,
          'followersCount': count + (following ? -1 : 1),
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

  Future<void> _openConnections(String type) async {
    await showUserConnections(
      context: context,
      api: widget.api,
      token: widget.token,
      userId: widget.userId,
      type: type,
      onOpenProfile: (otherUserId) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SocialPersonPage(
              api: widget.api,
              token: widget.token,
              userId: otherUserId,
              onFollowChanged: widget.onFollowChanged,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _profile?['avatarUrl'] as String?;
    final avatarProvider = avatar == null || avatar.isEmpty
        ? null
        : _socialAvatarProvider(avatar);
    return Scaffold(
      appBar: AppBar(
        title: AppText('${_profile?['displayName'] ?? 'Profile'}'),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                '${_profile?['displayName'] ?? 'TinkerPro user'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    key: const ValueKey(
                                      'public-profile-followers',
                                    ),
                                    onPressed: () =>
                                        _openConnections('followers'),
                                    child: AppText(
                                      '${(_profile?['followersCount'] as num?)?.toInt() ?? 0} followers',
                                      localize: true,
                                    ),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'public-profile-following',
                                    ),
                                    onPressed: () =>
                                        _openConnections('following'),
                                    child: AppText(
                                      '${(_profile?['followingCount'] as num?)?.toInt() ?? 0} following',
                                      localize: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _updatingFollow ? null : _toggleFollow,
                          child: AppText(
                            _profile?['isFollowing'] == true
                                ? 'Following'
                                : 'Follow',
                            localize: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const AppText(
                  'Experiences',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (_posts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: AppText('No posts yet.', localize: true),
                    ),
                  )
                else
                  ..._posts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SocialPostCard(
                        post: {
                          ...post,
                          'displayName': _profile?['displayName'],
                          'avatarUrl': _profile?['avatarUrl'],
                        },
                        onOpenPerson: null,
                        onFollow: null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _SocialPostCard extends StatelessWidget {
  const _SocialPostCard({
    required this.post,
    required this.onOpenPerson,
    required this.onFollow,
  });

  final Map<String, dynamic> post;
  final VoidCallback? onOpenPerson;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final avatar = post['avatarUrl'] as String?;
    final avatarProvider = avatar == null || avatar.isEmpty
        ? null
        : _socialAvatarProvider(avatar);
    final caption = '${post['caption'] ?? ''}'.trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onOpenPerson,
            leading: CircleAvatar(
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? const Icon(Icons.person_outline_rounded)
                  : null,
            ),
            title: AppText(
              '${post['displayName'] ?? 'TinkerPro user'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: AppText(_socialDate(post['createdAt'])),
            trailing: onFollow == null
                ? null
                : TextButton(
                    onPressed: onFollow,
                    child: const AppText('Follow', localize: true),
                  ),
          ),
          if (images.isNotEmpty)
            SizedBox(
              height: 280,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) => SizedBox.expand(
                  child: socialExperienceImage(images[index]),
                ),
              ),
            ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AppText(caption),
            ),
        ],
      ),
    );
  }
}

class _SocialPostComposer extends StatefulWidget {
  const _SocialPostComposer();

  @override
  State<_SocialPostComposer> createState() => _SocialPostComposerState();
}

class _SocialPostComposerState extends State<_SocialPostComposer> {
  final _captionController = TextEditingController();
  final List<String> _images = [];
  bool _picking = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked.isEmpty || !mounted) return;
      if (picked.length > _maxSocialPhotos) {
        _showError('Choose up to five photos per post.');
        return;
      }
      final images = <String>[];
      var totalCharacters = 0;
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxSocialPhotoBytes) {
          _showError('Each photo must be 10 MB or smaller.');
          return;
        }
        final extension = file.name.split('.').last.toLowerCase();
        final mime = switch (extension) {
          'png' => 'png',
          'webp' => 'webp',
          'jpg' || 'jpeg' => 'jpeg',
          _ => null,
        };
        if (mime == null) {
          _showError('Choose JPEG, PNG, or WebP photos.');
          return;
        }
        final data = 'data:image/$mime;base64,${base64Encode(bytes)}';
        totalCharacters += data.length;
        if (totalCharacters > _maxSocialPayloadChars) {
          _showError('Choose fewer or smaller photos and try again.');
          return;
        }
        images.add(data);
      }
      if (mounted) {
        setState(
          () => _images
            ..clear()
            ..addAll(images),
        );
      }
    } on Exception catch (error) {
      if (mounted) _showError('Could not choose photos: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(error, localize: true)));
  }

  void _submit() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _images.isEmpty) {
      _showError('Add a caption or choose at least one photo.');
      return;
    }
    if (caption.length > 2000) {
      _showError('Keep your caption under 2,000 characters.');
      return;
    }
    Navigator.of(context)
        .pop(_SocialPostDraft(caption: caption, images: List.of(_images)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Share an experience',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('social-post-caption'),
              controller: _captionController,
              autofocus: true,
              minLines: 3,
              maxLines: 7,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'What did you enjoy about your experience?',
                border: OutlineInputBorder(),
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => SizedBox(
                    width: 90,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: socialExperienceImage(_images[index]),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                            icon: const Icon(Icons.close_rounded, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _picking || _images.length >= _maxSocialPhotos
                      ? null
                      : _pickPhotos,
                  icon: _picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: AppText(
                    _images.isEmpty
                        ? 'Add photos'
                        : 'Photos (${_images.length}/$_maxSocialPhotos)',
                    localize: true,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey('social-post-submit'),
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const AppText('Share', localize: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const AppText(
              'Up to five photos per post. Limit: five posts every 24 hours.',
              style: TextStyle(fontSize: 12),
              localize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialPostDraft {
  const _SocialPostDraft({required this.caption, required this.images});

  final String caption;
  final List<String> images;
}

ImageProvider<Object>? _socialAvatarProvider(String value) {
  final match = RegExp(
    r'^data:image/(?:jpeg|jpg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) {
    try {
      return MemoryImage(base64Decode(match.group(1)!));
    } on FormatException {
      return null;
    }
  }
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return NetworkImage(value);
}

String _socialDate(dynamic value) {
  final parsed = DateTime.tryParse('$value')?.toLocal();
  if (parsed == null) return '';
  final now = DateTime.now();
  final difference = now.difference(parsed);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${parsed.month}/${parsed.day}/${parsed.year}';
}
