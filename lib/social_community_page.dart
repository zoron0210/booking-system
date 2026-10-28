import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'guest_access.dart';
import 'features/session/application/session_service.dart';
import 'social_message_tools.dart';
import 'social_post_interactions.dart';
import 'features/social/presentation/social_home_palette.dart';
import 'social_profile_section.dart';

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
    final token = await _requireToken();
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

  Future<void> _composePost() async {
    if (_posting) return;
    final token = await _requireToken();
    if (token == null || !mounted) return;
    final draft = await showSocialPostComposer(
      context,
      api: widget.api,
      token: token,
    );
    if (draft == null || !mounted) return;
    setState(() => _posting = true);
    try {
      await widget.api.createSocialPost(
        token: token,
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

  Future<String?> _requireToken() async {
    final existingToken = _token;
    if (existingToken != null && existingToken.isNotEmpty) return existingToken;
    if (!await requireCustomerLogin(context) || !mounted) return null;
    final token = (await AppSessionService.instance.load()).apiToken;
    if (token == null || token.isEmpty) {
      _showMessage('Sign in to use community actions.');
      return null;
    }
    setState(() => _token = token);
    return token;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text, localize: true)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Community', localize: true),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.dynamic_feed_outlined),
                text: _token == null ? 'Feed' : 'Following',
              ),
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
        itemBuilder: (context, index) => SocialExperiencePostCard(
          post: _feed[index],
          onOpenPerson: null,
          onFollow: null,
          api: widget.api,
          token: _token,
          onRequireToken: _requireToken,
          onPostChanged: _loadFeed,
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
                            onTap: null,
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
        : socialAvatarProvider(avatar);
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
        '${user['displayName'] ?? 'SpotGo user'}',
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

class SocialExperiencePostCard extends StatelessWidget {
  const SocialExperiencePostCard({
    super.key,
    required this.post,
    required this.onOpenPerson,
    required this.onFollow,
    this.api,
    this.token,
    this.onRequireToken,
    this.onPostChanged,
    this.homeFeedStyle = false,
  });

  final Map<String, dynamic> post;
  final VoidCallback? onOpenPerson;
  final VoidCallback? onFollow;
  final AuthApi? api;
  final String? token;
  final Future<String?> Function()? onRequireToken;
  final VoidCallback? onPostChanged;
  final bool homeFeedStyle;

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final avatar = post['avatarUrl'] as String?;
    final avatarProvider = avatar == null || avatar.isEmpty
        ? null
        : socialAvatarProvider(avatar);
    final caption = '${post['caption'] ?? ''}'.trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: homeFeedStyle ? SocialHomeColors.of(context).surface : null,
      shape: homeFeedStyle
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: SocialHomeColors.of(context).border),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (homeFeedStyle)
            _HomeFeedPostHeader(
              displayName: '${post['displayName'] ?? 'SpotGo user'}',
              createdAt: _socialDate(post['createdAt']),
              avatarProvider: avatarProvider,
              onTap: onOpenPerson,
              trailing: api == null
                  ? null
                  : _SocialPostOptionsMenu(
                      post: post,
                      api: api!,
                      token: token,
                      onRequireToken: onRequireToken,
                      onViewProfile: onOpenPerson,
                      onPostChanged: onPostChanged,
                    ),
            )
          else
            ListTile(
              onTap: onOpenPerson,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              title: AppText(
                '${post['displayName'] ?? 'SpotGo user'}',
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: homeFeedStyle ? 10 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(homeFeedStyle ? 10 : 0),
                child: homeFeedStyle
                    ? GestureDetector(
                        key: ValueKey('social-post-image-${post['id']}'),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => _SocialExperienceImageViewer(
                              post: post,
                              images: images,
                              api: api,
                              token: token,
                              onRequireToken: onRequireToken,
                              onViewProfile: onOpenPerson,
                              onPostChanged: onPostChanged,
                            ),
                          ),
                        ),
                        child: Container(
                          color: SocialHomeColors.of(context).surfaceRaised,
                          child: AspectRatio(
                            aspectRatio: 0.8,
                            child: PageView.builder(
                              itemCount: images.length,
                              itemBuilder: (context, index) => Center(
                                child: socialExperienceImage(
                                  images[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 280,
                        child: PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (context, index) => SizedBox.expand(
                            child: socialExperienceImage(images[index]),
                          ),
                        ),
                      ),
              ),
            ),
          if (homeFeedStyle && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: AppText(
                caption,
                style: TextStyle(
                  color: SocialHomeColors.of(context).text,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          if (api != null)
            SocialPostInteractionBar(
              post: post,
              api: api!,
              token: token,
              onRequireToken: onRequireToken,
              onPostChanged: onPostChanged,
              compact: homeFeedStyle,
              showSave: !homeFeedStyle,
            ),
          if (!homeFeedStyle && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppText(caption),
            ),
        ],
      ),
    );
  }
}

class _HomeFeedPostHeader extends StatelessWidget {
  const _HomeFeedPostHeader({
    required this.displayName,
    required this.createdAt,
    required this.avatarProvider,
    required this.onTap,
    this.trailing,
  });

  final String displayName;
  final String createdAt;
  final ImageProvider<Object>? avatarProvider;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? const Icon(Icons.person_outline_rounded)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Flexible(
                      child: AppText(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.circle, size: 3, color: colors.muted),
                      const SizedBox(width: 5),
                      AppText(
                        createdAt,
                        maxLines: 1,
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SocialPostOptionsMenu extends StatefulWidget {
  const _SocialPostOptionsMenu({
    required this.post,
    required this.api,
    required this.onViewProfile,
    this.token,
    this.onRequireToken,
    this.onPostChanged,
  });

  final Map<String, dynamic> post;
  final AuthApi api;
  final VoidCallback? onViewProfile;
  final String? token;
  final Future<String?> Function()? onRequireToken;
  final VoidCallback? onPostChanged;

  @override
  State<_SocialPostOptionsMenu> createState() => _SocialPostOptionsMenuState();
}

class _SocialPostOptionsMenuState extends State<_SocialPostOptionsMenu> {
  bool _working = false;

  Future<String?> _requireToken() async {
    final token = widget.token;
    if (token != null && token.isNotEmpty) return token;
    return widget.onRequireToken?.call();
  }

  Future<void> _select(String value) async {
    if (value == 'profile') {
      widget.onViewProfile?.call();
      return;
    }
    if (value == 'save') {
      await _toggleSave();
    } else if (value == 'report') {
      await _report();
    }
  }

  Future<void> _toggleSave() async {
    final id = (widget.post['id'] as num?)?.toInt();
    if (id == null || _working) return;
    final token = await _requireToken();
    if (token == null || !mounted) return;
    final wasSaved = widget.post['isSaved'] == true;
    setState(() => _working = true);
    try {
      await widget.api.setSocialPostSaved(
        token: token,
        postId: id,
        saved: !wasSaved,
      );
      widget.post['isSaved'] = !wasSaved;
      widget.onPostChanged?.call();
      _showMessage(wasSaved ? 'Removed from Saved.' : 'Saved to your profile.');
    } on Exception catch (error) {
      _showMessage('Could not update this post: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _report() async {
    final id = (widget.post['id'] as num?)?.toInt();
    if (id == null || _working) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: AppText(
                'Report this experience',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: AppText('Why are you reporting this post?'),
            ),
            for (final (value, label, icon) in [
              ('spam', 'Spam', Icons.campaign_outlined),
              (
                'harassment',
                'Harassment or bullying',
                Icons.person_off_outlined,
              ),
              (
                'inappropriate',
                'Inappropriate content',
                Icons.warning_amber_rounded,
              ),
              ('other', 'Something else', Icons.more_horiz_rounded),
            ])
              ListTile(
                leading: Icon(icon),
                title: AppText(label, localize: true),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final token = await _requireToken();
    if (token == null || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.api.reportSocialPost(
        token: token,
        postId: id,
        reason: reason,
      );
      _showMessage('Thanks. Your report has been submitted.');
    } on Exception catch (error) {
      _showMessage('Could not report this post: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message, localize: true)));
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey('social-post-options-${widget.post['id']}'),
    tooltip: 'Post options',
    enabled: !_working,
    onSelected: _select,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'profile',
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline_rounded),
          title: AppText('View profile', localize: true),
        ),
      ),
      PopupMenuItem(
        value: 'report',
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flag_outlined),
          title: AppText('Report', localize: true),
        ),
      ),
      PopupMenuItem(
        value: 'save',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            widget.post['isSaved'] == true
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_border_rounded,
          ),
          title: AppText(
            widget.post['isSaved'] == true ? 'Unsave' : 'Save',
            localize: true,
          ),
        ),
      ),
    ],
    icon: const Icon(Icons.more_vert_rounded),
  );
}

class _SocialExperienceImageViewer extends StatelessWidget {
  const _SocialExperienceImageViewer({
    required this.post,
    required this.images,
    required this.api,
    required this.token,
    required this.onRequireToken,
    required this.onViewProfile,
    required this.onPostChanged,
  });

  final Map<String, dynamic> post;
  final List<String> images;
  final AuthApi? api;
  final String? token;
  final Future<String?> Function()? onRequireToken;
  final VoidCallback? onViewProfile;
  final VoidCallback? onPostChanged;

  @override
  Widget build(BuildContext context) {
    final caption = '${post['caption'] ?? ''}'.trim();
    final colors = SocialHomeColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.28),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('social-post-image-viewer-back'),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: AppText(
          '${post['displayName'] ?? 'SpotGo user'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (api != null)
            _SocialPostOptionsMenu(
              post: post,
              api: api!,
              token: token,
              onRequireToken: onRequireToken,
              onViewProfile: onViewProfile,
              onPostChanged: onPostChanged,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: PageView.builder(
                key: ValueKey('social-post-image-viewer-${post['id']}'),
                itemCount: images.length,
                itemBuilder: (context, index) => Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: SizedBox.expand(
                      child: socialExperienceImage(
                        images[index],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  caption,
                  style: TextStyle(color: colors.text, fontSize: 14),
                ),
              ),
            ),
          if (api != null)
            SocialPostInteractionBar(
              post: post,
              api: api!,
              token: token,
              onRequireToken: onRequireToken,
              onPostChanged: onPostChanged,
              compact: true,
              showSave: false,
            ),
        ],
      ),
    );
  }
}

class _SocialPostComposer extends StatefulWidget {
  const _SocialPostComposer({required this.api, required this.token});

  final AuthApi api;
  final String token;

  @override
  State<_SocialPostComposer> createState() => _SocialPostComposerState();
}

class _SocialPostComposerState extends State<_SocialPostComposer> {
  final _captionController = TextEditingController();
  final List<String> _images = [];
  bool _picking = false;

  Future<void> _addGif() async {
    if (_images.length >= _maxSocialPhotos) {
      _showError('You can add up to five photos or GIFs.');
      return;
    }
    final gif = await showTenorGifPicker(
      context,
      api: widget.api,
      token: widget.token,
    );
    final url = gif?['url'];
    if (mounted && url is String) setState(() => _images.add(url));
  }

  Future<void> _addEmoji() async {
    final emoji = await showSocialEmojiPicker(context);
    if (emoji == null || !mounted) return;
    final value = _captionController.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    final text = value.text.replaceRange(start, end, emoji);
    _captionController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

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
      if (picked.length + _images.length > _maxSocialPhotos) {
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
        setState(() => _images.addAll(images));
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
        .pop(SocialPostDraft(caption: caption, images: List.of(_images)));
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
            Row(
              children: [
                IconButton(
                  key: const ValueKey('social-post-emoji'),
                  tooltip: 'Add emoji',
                  onPressed: _addEmoji,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                TextButton.icon(
                  key: const ValueKey('social-post-gif'),
                  onPressed: _addGif,
                  icon: const Icon(Icons.gif_box_outlined),
                  label: const AppText('GIF'),
                ),
              ],
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

Future<SocialPostDraft?> showSocialPostComposer(
  BuildContext context, {
  required AuthApi api,
  required String token,
}) => showModalBottomSheet<SocialPostDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _SocialPostComposer(api: api, token: token),
);

class SocialPostDraft {
  const SocialPostDraft({required this.caption, required this.images});

  final String caption;
  final List<String> images;
}

ImageProvider<Object>? socialAvatarProvider(String value) {
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
