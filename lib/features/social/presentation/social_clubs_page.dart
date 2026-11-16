import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:myapp/core/app_text.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/social/domain/social_club.dart';
import 'package:myapp/features/social/presentation/social_post_interactions.dart';

const _maxClubPhotoBytes = 10 * 1024 * 1024;
const _maxClubPostPhotos = 5;

Future<String> _encodeClubPhoto(XFile file) async {
  final bytes = await file.readAsBytes();
  if (bytes.length > _maxClubPhotoBytes) {
    throw const FormatException('Each photo must be 10 MiB or smaller.');
  }
  final extension = file.name.split('.').last.toLowerCase();
  final mime = switch (extension) {
    'png' => 'png',
    'webp' => 'webp',
    'jpg' || 'jpeg' => 'jpeg',
    _ => null,
  };
  if (mime == null) {
    throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
  }
  return 'data:image/$mime;base64,${base64Encode(bytes)}';
}

Widget _clubPhotoPreview(String data, {double size = 72}) => ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Image.memory(
    base64Decode(data.substring(data.indexOf(',') + 1)),
    width: size,
    height: size,
    fit: BoxFit.cover,
  ),
);

class _CreateSocialClubDialog extends StatefulWidget {
  const _CreateSocialClubDialog();

  @override
  State<_CreateSocialClubDialog> createState() =>
      _CreateSocialClubDialogState();
}

class _CreateSocialClubDialogState extends State<_CreateSocialClubDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _logo;
  String? _photoError;
  bool _pickingLogo = false;

  Future<void> _pickLogo() async {
    if (_pickingLogo) return;
    setState(() {
      _pickingLogo = true;
      _photoError = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null || !mounted) return;
      final logo = await _encodeClubPhoto(file);
      if (mounted) setState(() => _logo = logo);
    } on Exception catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Create a club', localize: true),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              Semantics(
                button: true,
                label: _logo == null
                    ? 'Choose required club logo'
                    : 'Change club logo',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('social-club-logo-pick'),
                    onTap: _pickingLogo ? null : _pickLogo,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipOval(
                            child: _logo != null && !_pickingLogo
                                ? Image.memory(
                                    base64Decode(
                                      _logo!.substring(_logo!.indexOf(',') + 1),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : ColoredBox(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Center(
                                      child: _pickingLogo
                                          ? const CircularProgressIndicator()
                                          : Icon(
                                              Icons.groups_2_outlined,
                                              size: 40,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimary,
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppText(
                _logo == null ? 'Add club logo · Required' : 'Change club logo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            ],
          ),
          if (_photoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppText(
                _photoError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          TextField(
            key: const ValueKey('social-club-name'),
            controller: _nameController,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Club name',
              hintText: 'e.g. Cebu Weekend Badminton',
            ),
          ),
          TextField(
            key: const ValueKey('social-club-description'),
            controller: _descriptionController,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'About this club',
              hintText: 'What do members get together to play?',
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              'Clubs are public and free to join.',
              style: TextStyle(fontSize: 12),
              localize: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel', localize: true),
      ),
      FilledButton(
        key: const ValueKey('social-club-create-submit'),
        onPressed: _logo == null || _pickingLogo
            ? null
            : () => Navigator.pop(context, (
                _nameController.text,
                _descriptionController.text,
                _logo!,
              )),
        child: const AppText('Create club', localize: true),
      ),
    ],
  );
}

class _CreateSocialClubPostDialog extends StatefulWidget {
  const _CreateSocialClubPostDialog({required this.clubName});

  final String clubName;

  @override
  State<_CreateSocialClubPostDialog> createState() =>
      _CreateSocialClubPostDialogState();
}

class _CreateSocialClubPostDialogState
    extends State<_CreateSocialClubPostDialog> {
  final _captionController = TextEditingController();
  final List<String> _images = [];
  String? _photoError;
  bool _pickingPhotos = false;

  Future<void> _pickPhotos() async {
    if (_pickingPhotos) return;
    setState(() {
      _pickingPhotos = true;
      _photoError = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (files.isEmpty || !mounted) return;
      if (files.length + _images.length > _maxClubPostPhotos) {
        setState(() => _photoError = 'Choose up to five photos per post.');
        return;
      }
      final images = <String>[];
      for (final file in files) {
        images.add(await _encodeClubPhoto(file));
      }
      if (mounted) setState(() => _images.addAll(images));
    } on Exception catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText('Post to ${widget.clubName}', localize: true),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _images.length; index++)
                Stack(
                  children: [
                    _clubPhotoPreview(_images[index]),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        key: ValueKey('social-club-post-remove-photo-$index'),
                        onPressed: () =>
                            setState(() => _images.removeAt(index)),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          OutlinedButton.icon(
            key: const ValueKey('social-club-post-pick-photo'),
            onPressed: _pickingPhotos || _images.length >= _maxClubPostPhotos
                ? null
                : _pickPhotos,
            icon: _pickingPhotos
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: const AppText('Add required photo', localize: true),
          ),
          const AppText(
            'At least one JPEG, PNG, or WebP photo is required.',
            style: TextStyle(fontSize: 12),
            localize: true,
          ),
          if (_photoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppText(
                _photoError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('social-club-post-caption'),
            controller: _captionController,
            maxLength: 2000,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Share an update with your club',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel', localize: true),
      ),
      FilledButton(
        key: const ValueKey('social-club-post-submit'),
        onPressed: _images.isEmpty || _pickingPhotos
            ? null
            : () => Navigator.pop(context, (
                _captionController.text,
                List<String>.of(_images),
              )),
        child: const AppText('Post', localize: true),
      ),
    ],
  );
}

class SocialClubsPage extends StatefulWidget {
  const SocialClubsPage({
    super.key,
    required this.api,
    required this.token,
    required this.onRequireToken,
    this.onOpenProfile,
  });

  final AuthApi api;
  final String? token;
  final Future<String?> Function() onRequireToken;
  final Future<void> Function(int userId)? onOpenProfile;

  @override
  State<SocialClubsPage> createState() => _SocialClubsPageState();
}

class _SocialClubsPageState extends State<SocialClubsPage> {
  List<SocialClub> _clubs = const [];
  bool _loading = true;
  bool _creating = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void didUpdateWidget(covariant SocialClubsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final clubs = await widget.api.social.socialClubs(token: widget.token);
      if (mounted) setState(() => _clubs = clubs);
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createClub() async {
    if (_creating) return;
    final token = await widget.onRequireToken();
    if (token == null || !mounted) return;
    final values = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const _CreateSocialClubDialog(),
    );
    if (values == null || !mounted) return;
    if (values.$1.trim().length < 3) {
      _showMessage('Club names must be at least 3 characters.');
      return;
    }
    setState(() => _creating = true);
    try {
      final club = await widget.api.social.createSocialClub(
        token: token,
        name: values.$1,
        description: values.$2,
        logo: values.$3,
      );
      if (!mounted) return;
      _showMessage('Your club is ready to join.');
      await _openClub(club, token: token);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.userMessage);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not create the club: $error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openClub(SocialClub club, {String? token}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SocialClubDetailPage(
          api: widget.api,
          clubId: club.id,
          token: token ?? widget.token,
          onRequireToken: widget.onRequireToken,
          onOpenProfile: widget.onOpenProfile,
        ),
      ),
    );
    if (mounted) await _loadClubs();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message, localize: true)));
  }

  @override
  Widget build(BuildContext context) {
    final joined = _clubs.where((club) => club.isMember).toList();
    final discover = _clubs.where((club) => !club.isMember).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: AppText(
                  'Play together. Join a club for free.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  localize: true,
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('social-club-create'),
                onPressed: _creating ? null : _createClub,
                icon: const Icon(Icons.add_rounded),
                label: const AppText('Create club', localize: true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _clubs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null && _clubs.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 12),
                    const AppText(
                      'Could not load clubs.',
                      textAlign: TextAlign.center,
                      localize: true,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _loadClubs,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const AppText('Try again', localize: true),
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadClubs,
                  child: _clubs.isEmpty
                      ? ListView(
                          key: const ValueKey('social-clubs-empty'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 72),
                            Icon(Icons.groups_2_outlined, size: 52),
                            SizedBox(height: 12),
                            AppText(
                              'No clubs yet. Start one for your sport or neighborhood.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                              localize: true,
                            ),
                          ],
                        )
                      : ListView(
                          key: const ValueKey('social-club-list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          children: [
                            if (joined.isNotEmpty) ...[
                              const _ClubSectionHeading(
                                title: 'Your clubs',
                                icon: Icons.verified_outlined,
                              ),
                              for (final club in joined)
                                _ClubListTile(
                                  club: club,
                                  onTap: () => _openClub(club),
                                ),
                              const SizedBox(height: 8),
                            ],
                            const _ClubSectionHeading(
                              title: 'Discover clubs',
                              icon: Icons.explore_outlined,
                            ),
                            if (discover.isEmpty && joined.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: AppText(
                                  "You're all caught up. Search for another club or create one.",
                                  textAlign: TextAlign.center,
                                  localize: true,
                                ),
                              ),
                            for (final club in discover)
                              _ClubListTile(
                                club: club,
                                onTap: () => _openClub(club),
                              ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}

class SocialClubDetailPage extends StatefulWidget {
  const SocialClubDetailPage({
    super.key,
    required this.api,
    required this.clubId,
    required this.token,
    required this.onRequireToken,
    this.onOpenProfile,
  });

  final AuthApi api;
  final int clubId;
  final String? token;
  final Future<String?> Function() onRequireToken;
  final Future<void> Function(int userId)? onOpenProfile;

  @override
  State<SocialClubDetailPage> createState() => _SocialClubDetailPageState();
}

class _SocialClubDetailPageState extends State<SocialClubDetailPage> {
  String? _token;
  SocialClub? _club;
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextCursor;
  Object? _loadError;
  bool _posting = false;
  bool _membershipAction = false;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _load();
  }

  @override
  void didUpdateWidget(covariant SocialClubDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _token = widget.token;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await Future.wait([
        widget.api.social.socialClub(token: _token, clubId: widget.clubId),
        widget.api.social.socialClubPosts(token: _token, clubId: widget.clubId),
      ]);
      if (!mounted) return;
      setState(() {
        _club = values[0] as SocialClub;
        final page = values[1] as SocialFeedPage;
        _posts = page.posts;
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loading || _loadingMore || !_hasMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.social.socialClubPosts(
        token: _token,
        clubId: widget.clubId,
        beforeId: cursor,
      );
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...page.posts];
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not load more club posts: $error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleMembership() async {
    final club = _club;
    if (club == null || _membershipAction || club.isPending) return;
    final token = await widget.onRequireToken();
    if (token == null || !mounted) return;
    setState(() {
      _token = token;
      _membershipAction = true;
    });
    try {
      if (club.isMember) {
        await widget.api.social.leaveSocialClub(token: token, clubId: club.id);
        _showMessage('You left ${club.name}.');
      } else {
        final result = await widget.api.social.joinSocialClub(
          token: token,
          clubId: club.id,
        );
        if (result['isPending'] == true) {
          _showMessage('Your request to join ${club.name} was sent.');
        } else {
          _showMessage('You joined ${club.name} for free.');
        }
      }
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.userMessage);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not update club membership: $error');
    } finally {
      if (mounted) setState(() => _membershipAction = false);
    }
  }

  Future<void> _openSettings() async {
    final club = _club;
    if (club == null || !club.isOwner || _settingsOpen) return;
    final token = await widget.onRequireToken();
    if (token == null || !mounted) return;
    setState(() {
      _token = token;
      _settingsOpen = true;
    });
    try {
      final deleted = await showDialog<bool>(
        context: context,
        builder: (_) => _SocialClubSettingsDialog(
          api: widget.api,
          token: token,
          club: club,
        ),
      );
      if (!mounted) return;
      if (deleted == true) {
        Navigator.of(context).pop(true);
      } else {
        await _load();
      }
    } finally {
      if (mounted) setState(() => _settingsOpen = false);
    }
  }

  Future<void> _createPost() async {
    final club = _club;
    if (club == null || !club.isMember || _posting) return;
    final token = await widget.onRequireToken();
    if (token == null || !mounted) return;
    final draft = await showDialog<(String, List<String>)>(
      context: context,
      builder: (_) => _CreateSocialClubPostDialog(clubName: club.name),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _token = token;
      _posting = true;
    });
    try {
      await widget.api.social.createSocialPost(
        token: token,
        caption: draft.$1,
        images: draft.$2,
        clubId: club.id,
      );
      if (!mounted) return;
      _showMessage('Your post was shared with the club.');
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.userMessage);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not post to the club: $error');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message, localize: true)));
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Scaffold(
      appBar: AppBar(
        title: AppText(club?.name ?? 'Club', localize: true),
        actions: [
          if (club?.isOwner == true)
            IconButton(
              key: const ValueKey('social-club-settings'),
              tooltip: 'Club settings',
              onPressed: _settingsOpen ? null : _openSettings,
              icon: const Icon(Icons.more_vert_rounded),
            ),
        ],
      ),
      floatingActionButton: club?.isMember == true
          ? FloatingActionButton.extended(
              key: const ValueKey('social-club-post'),
              onPressed: _posting ? null : _createPost,
              icon: const Icon(Icons.edit_outlined),
              label: const AppText('Write a post', localize: true),
            )
          : null,
      body: _loading && club == null
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && club == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText('Could not load this club.', localize: true),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _load,
                    child: const AppText('Try again', localize: true),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 300) _loadMore();
                  return false;
                },
                child: ListView(
                  key: const ValueKey('social-club-detail-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    if (club != null) ...[
                      _ClubInfoCard(
                        club: club,
                        busy: _membershipAction,
                        onMembershipPressed: _toggleMembership,
                      ),
                      const SizedBox(height: 16),
                      const AppText(
                        'Club posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        localize: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_posts.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: AppText(
                          'No posts yet. Join the club and start the conversation.',
                          textAlign: TextAlign.center,
                          localize: true,
                        ),
                      ),
                    for (final post in _posts) ...[
                      _SocialClubPostCard(
                        post: post,
                        api: widget.api,
                        token: _token,
                        onRequireToken: widget.onRequireToken,
                        onOpenProfile: widget.onOpenProfile,
                        onPostChanged: _load,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SocialClubSettingsDialog extends StatefulWidget {
  const _SocialClubSettingsDialog({
    required this.api,
    required this.token,
    required this.club,
  });

  final AuthApi api;
  final String token;
  final SocialClub club;

  @override
  State<_SocialClubSettingsDialog> createState() =>
      _SocialClubSettingsDialogState();
}

class _SocialClubSettingsDialogState extends State<_SocialClubSettingsDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.club.name,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.club.description ?? '');
  late bool _requiresApproval = widget.club.requiresJoinApproval;
  List<Map<String, dynamic>> _requests = const [];
  String? _logo;
  String? _error;
  bool _loadingRequests = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loadingRequests = true;
      _error = null;
    });
    try {
      final requests = await widget.api.social.socialClubJoinRequests(
        token: widget.token,
        clubId: widget.club.id,
      );
      if (mounted) setState(() => _requests = requests);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not load requests: $error');
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null || !mounted) return;
      final logo = await _encodeClubPhoto(file);
      if (mounted) {
        setState(() {
          _logo = logo;
          _error = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not choose a logo: $error');
    }
  }

  Future<void> _toggleApproval(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.social.updateSocialClubJoinApproval(
        token: widget.token,
        clubId: widget.club.id,
        requiresApproval: value,
      );
      if (mounted) setState(() => _requiresApproval = value);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update join settings: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewRequest(int userId, {required bool approve}) async {
    try {
      await widget.api.social.reviewSocialClubJoinRequest(
        token: widget.token,
        clubId: widget.club.id,
        userId: userId,
        approve: approve,
      );
      if (mounted) {
        setState(() {
          _requests = _requests
              .where(
                (request) => (request['userId'] as num?)?.toInt() != userId,
              )
              .toList();
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update join request: $error');
      }
    }
  }

  Future<void> _saveDetails() async {
    if (_nameController.text.trim().length < 3) {
      setState(() => _error = 'Club names must be at least 3 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.social.updateSocialClub(
        token: widget.token,
        clubId: widget.club.id,
        name: _nameController.text,
        description: _descriptionController.text,
        logo: _logo,
      );
      if (mounted) Navigator.of(context).pop(false);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save club details: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteClub() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete this club?', localize: true),
        content: const AppText(
          'This permanently deletes the club, its members, and all club posts.',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel', localize: true),
          ),
          FilledButton(
            key: const ValueKey('social-club-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete club', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.api.social.deleteSocialClub(
        token: widget.token,
        clubId: widget.club.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not delete club: $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('social-club-settings-dialog'),
    title: const AppText('Club settings', localize: true),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: InkWell(
                key: const ValueKey('social-club-edit-logo'),
                customBorder: const CircleBorder(),
                onTap: _saving ? null : _pickLogo,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundImage: _logo != null
                          ? MemoryImage(base64Decode(_logo!.split(',').last))
                          : widget.club.logoUrl == null
                          ? null
                          : NetworkImage(widget.club.logoUrl!) as ImageProvider,
                      child: _logo == null && widget.club.logoUrl == null
                          ? const Icon(Icons.groups_2_outlined, size: 36)
                          : null,
                    ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 15,
                        child: Icon(Icons.camera_alt_outlined, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: AppText('Tap to change club logo', localize: true),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('social-club-edit-name'),
              controller: _nameController,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Club name'),
            ),
            TextField(
              key: const ValueKey('social-club-edit-description'),
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            SwitchListTile(
              key: const ValueKey('social-club-require-approval'),
              contentPadding: EdgeInsets.zero,
              value: _requiresApproval,
              onChanged: _saving ? null : _toggleApproval,
              title: const AppText('Approve new members', localize: true),
              subtitle: const AppText(
                'New join requests need your approval before members can post.',
                localize: true,
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: AppText(
                    'Join requests (${_requests.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    localize: true,
                  ),
                ),
                IconButton(
                  key: const ValueKey('social-club-requests-refresh'),
                  tooltip: 'Refresh join requests',
                  onPressed: _loadingRequests ? null : _loadRequests,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_loadingRequests)
              const Center(child: CircularProgressIndicator())
            else if (_requests.isEmpty)
              const AppText('No pending requests.', localize: true)
            else
              for (final request in _requests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${request['displayName'] ?? 'SpotGo user'}'),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        key: ValueKey(
                          'social-club-request-approve-${request['userId']}',
                        ),
                        tooltip: 'Approve request',
                        onPressed: () => _reviewRequest(
                          (request['userId'] as num).toInt(),
                          approve: true,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      IconButton(
                        key: ValueKey(
                          'social-club-request-reject-${request['userId']}',
                        ),
                        tooltip: 'Reject request',
                        onPressed: () => _reviewRequest(
                          (request['userId'] as num).toInt(),
                          approve: false,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    ],
                  ),
                ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('social-club-delete'),
                onPressed: _deleting || _saving ? null : _deleteClub,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const AppText('Delete club', localize: true),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving || _deleting ? null : () => Navigator.pop(context),
        child: const AppText('Close', localize: true),
      ),
      FilledButton(
        key: const ValueKey('social-club-edit-save'),
        onPressed: _saving || _deleting ? null : _saveDetails,
        child: const AppText('Save changes', localize: true),
      ),
    ],
  );
}

class _ClubSectionHeading extends StatelessWidget {
  const _ClubSectionHeading({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        AppText(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          localize: true,
        ),
      ],
    ),
  );
}

class _ClubAvatar extends StatelessWidget {
  const _ClubAvatar({required this.club, this.radius = 24});

  final SocialClub club;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final logoUrl = club.logoUrl;
    return CircleAvatar(
      radius: radius,
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                logoUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.groups_2_outlined, size: radius),
              ),
            )
          : Text(club.name.isEmpty ? 'C' : club.name[0].toUpperCase()),
    );
  }
}

class _ClubListTile extends StatelessWidget {
  const _ClubListTile({required this.club, required this.onTap});

  final SocialClub club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      key: ValueKey('social-club-${club.id}'),
      onTap: onTap,
      leading: _ClubAvatar(club: club),
      title: Text(club.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (club.description?.isNotEmpty == true)
            Text(
              club.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            '${club.memberCount} ${club.memberCount == 1 ? 'member' : 'members'} · '
            '${club.isMember ? 'Joined' : 'Free to join'}',
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _ClubInfoCard extends StatelessWidget {
  const _ClubInfoCard({
    required this.club,
    required this.busy,
    required this.onMembershipPressed,
  });

  final SocialClub club;
  final bool busy;
  final VoidCallback onMembershipPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ClubAvatar(club: club, radius: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('${club.memberCount} members · Free to join'),
                  ],
                ),
              ),
            ],
          ),
          if (club.description?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(club.description!),
          ],
          const SizedBox(height: 8),
          Text(
            'Created by ${club.ownerName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (club.isMember)
            Align(
              alignment: Alignment.centerRight,
              child: club.isOwner
                  ? const AppText(
                      'You created this club.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                      localize: true,
                    )
                  : TextButton(
                      key: const ValueKey('social-club-leave'),
                      onPressed: busy ? null : onMembershipPressed,
                      child: const AppText('Leave club', localize: true),
                    ),
            )
          else if (club.isPending)
            const SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                child: AppText('Join request pending', localize: true),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('social-club-join'),
                onPressed: busy ? null : onMembershipPressed,
                icon: const Icon(Icons.group_add_outlined),
                label: const AppText('Join for free', localize: true),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SocialClubPostCard extends StatelessWidget {
  const _SocialClubPostCard({
    required this.post,
    required this.api,
    required this.token,
    required this.onRequireToken,
    required this.onPostChanged,
    this.onOpenProfile,
  });

  final Map<String, dynamic> post;
  final AuthApi api;
  final String? token;
  final Future<String?> Function() onRequireToken;
  final Future<void> Function() onPostChanged;
  final Future<void> Function(int userId)? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final displayName = post['displayName'] as String? ?? 'SpotGo user';
    final images = post['images'] is List
        ? (post['images'] as List).whereType<String>().toList()
        : const <String>[];
    final caption = post['caption'] as String?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                displayName.isEmpty ? 'S' : displayName[0].toUpperCase(),
              ),
            ),
            title: Text(displayName),
            subtitle: Text(_clubRelativeDate(post['createdAt'])),
          ),
          if (caption?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(caption!),
            ),
          for (final image in images)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          SocialPostInteractionBar(
            post: post,
            api: api,
            token: token,
            onRequireToken: onRequireToken,
            onOpenProfile: onOpenProfile,
            onPostChanged: onPostChanged,
          ),
        ],
      ),
    );
  }
}

String _clubRelativeDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  final age = DateTime.now().difference(date);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  if (age.inDays < 7) return '${age.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
