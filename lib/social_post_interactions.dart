import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'social_message_tools.dart';
import 'features/social/presentation/social_home_palette.dart';

class SocialPostInteractionBar extends StatefulWidget {
  const SocialPostInteractionBar({
    super.key,
    required this.post,
    required this.api,
    this.token,
    this.onRequireToken,
    this.onPostChanged,
    this.compact = false,
    this.showSave = true,
  });

  final Map<String, dynamic> post;
  final AuthApi api;
  final String? token;
  final Future<String?> Function()? onRequireToken;
  final VoidCallback? onPostChanged;
  final bool compact;
  final bool showSave;

  @override
  State<SocialPostInteractionBar> createState() =>
      _SocialPostInteractionBarState();
}

class _SocialPostInteractionBarState extends State<SocialPostInteractionBar> {
  bool _saving = false;

  bool _active(String field) {
    final value = widget.post[field];
    return value == true || value == 1 || value == '1';
  }

  Future<String?> _token() async {
    final current = widget.token;
    if (current != null && current.isNotEmpty) return current;
    return widget.onRequireToken?.call();
  }

  Future<void> _toggle({required bool like}) async {
    if (_saving) return;
    final id = (widget.post['id'] as num?)?.toInt();
    if (id == null) return;
    final token = await _token();
    if (token == null || !mounted) return;
    final field = like ? 'isLiked' : 'isSaved';
    final countField = like ? 'likeCount' : null;
    final previous = _active(field);
    final count = (widget.post['likeCount'] as num?)?.toInt() ?? 0;
    setState(() {
      _saving = true;
      widget.post[field] = !previous;
      if (countField != null) {
        widget.post[countField] = count + (previous ? -1 : 1);
      }
    });
    try {
      if (like) {
        await widget.api.setSocialPostLiked(
          token: token,
          postId: id,
          liked: !previous,
        );
      } else {
        await widget.api.setSocialPostSaved(
          token: token,
          postId: id,
          saved: !previous,
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        widget.post[field] = previous;
        if (countField != null) widget.post[countField] = count;
      });
      _showMessage('Could not update this post: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _comments() async {
    final id = (widget.post['id'] as num?)?.toInt();
    if (id == null) return;
    final token = await _token();
    if (token == null || !mounted) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          SocialPostCommentsSheet(api: widget.api, token: token, postId: id),
    );
    if (added == true && mounted) widget.onPostChanged?.call();
  }

  Future<void> _share() async {
    final id = (widget.post['id'] as num?)?.toInt();
    if (id == null) return;
    final token = await _token();
    if (token == null || !mounted) return;
    final shared = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SocialPostShareSheet(
        api: widget.api,
        token: token,
        post: widget.post,
      ),
    );
    if (shared == true && mounted) {
      _showMessage('Experience shared in your messages.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text, localize: true)));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(widget.compact ? 8 : 8, 2, 8, 0),
        child: Row(
          children: [
            IconButton(
              key: ValueKey('social-post-like-${widget.post['id']}'),
              tooltip: 'Like',
              visualDensity: widget.compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              onPressed: _saving ? null : () => _toggle(like: true),
              icon: Icon(
                _active('isLiked')
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _active('isLiked') ? SocialHomePalette.coral : null,
              ),
            ),
            if (widget.compact) AppText('${widget.post['likeCount'] ?? 0}'),
            IconButton(
              key: ValueKey('social-post-comment-${widget.post['id']}'),
              tooltip: 'Comment',
              visualDensity: widget.compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              onPressed: _comments,
              icon: const Icon(Icons.mode_comment_outlined),
            ),
            if (widget.compact) AppText('${widget.post['commentCount'] ?? 0}'),
            IconButton(
              key: ValueKey('social-post-share-${widget.post['id']}'),
              tooltip: 'Share',
              visualDensity: widget.compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
            ),
            if (widget.showSave) ...[
              const Spacer(),
              IconButton(
                key: ValueKey('social-post-save-${widget.post['id']}'),
                tooltip: 'Save',
                visualDensity: widget.compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                onPressed: _saving ? null : () => _toggle(like: false),
                icon: Icon(
                  _active('isSaved')
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
      if (!widget.compact)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: AppText(
            '${widget.post['likeCount'] ?? 0} likes  ·  ${widget.post['commentCount'] ?? 0} comments',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

class SocialPostShareSheet extends StatefulWidget {
  const SocialPostShareSheet({
    super.key,
    required this.api,
    required this.token,
    required this.post,
  });

  final AuthApi api;
  final String token;
  final Map<String, dynamic> post;

  @override
  State<SocialPostShareSheet> createState() => _SocialPostShareSheetState();
}

class _SocialPostShareSheetState extends State<SocialPostShareSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  int _searchVersion = 0;
  int? _sendingTo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final version = ++_searchVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.api.searchSocialUsers(
        widget.token,
        query: _searchController.text,
      );
      if (!mounted || version != _searchVersion) return;
      setState(() => _users = users);
    } on Exception catch (error) {
      if (mounted && version == _searchVersion) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendTo(Map<String, dynamic> user) async {
    final recipientId = (user['id'] as num?)?.toInt();
    if (recipientId == null || _sendingTo != null) return;
    setState(() => _sendingTo = recipientId);
    final postId = (widget.post['id'] as num?)?.toInt();
    final author = '${widget.post['displayName'] ?? 'SpotGo user'}';
    final caption = '${widget.post['caption'] ?? ''}'.trim();
    final body = [
      'Shared an experience by $author',
      if (caption.isNotEmpty) caption,
      if (postId != null) 'SpotGo post #$postId',
    ].join('\n\n');
    try {
      final conversationId = await widget.api.openConversation(
        token: widget.token,
        recipientId: recipientId,
      );
      await widget.api.sendConversationMessage(
        token: widget.token,
        conversationId: conversationId,
        body: body,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _sendingTo = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Could not share this experience: $error')),
        );
      }
    }
  }

  Future<void> _shareExternally() async {
    final id = widget.post['id'];
    final caption = '${widget.post['caption'] ?? ''}'.trim();
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'SpotGo experience',
          text: [
            'SpotGo experience #$id',
            if (caption.isNotEmpty) caption,
          ].join('\n\n'),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Could not open the share menu: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Share experience',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('social-post-share-external'),
                onPressed: _shareExternally,
                icon: const Icon(Icons.ios_share_rounded),
                label: const AppText('More options', localize: true),
              ),
            ],
          ),
          TextField(
            key: const ValueKey('social-share-people-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadUsers(),
            decoration: InputDecoration(
              hintText: 'Search people',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search people',
                onPressed: _loading ? null : _loadUsers,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText('Could not load people: $_error'),
                        TextButton(
                          onPressed: _loadUsers,
                          child: const AppText('Retry', localize: true),
                        ),
                      ],
                    ),
                  )
                : _users.isEmpty
                ? const Center(
                    child: AppText('No people found.', localize: true),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final id = (user['id'] as num?)?.toInt();
                      return ListTile(
                        key: ValueKey('social-share-user-$id'),
                        leading: CircleAvatar(
                          child: const Icon(Icons.person_outline_rounded),
                        ),
                        title: AppText(
                          '${user['displayName'] ?? 'SpotGo user'}',
                        ),
                        trailing: _sendingTo == id
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        onTap: _sendingTo == null ? () => _sendTo(user) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class SocialPostCommentsSheet extends StatefulWidget {
  const SocialPostCommentsSheet({
    super.key,
    required this.api,
    required this.token,
    required this.postId,
  });

  final AuthApi api;
  final String token;
  final int postId;

  @override
  State<SocialPostCommentsSheet> createState() =>
      _SocialPostCommentsSheetState();
}

class _SocialPostCommentsSheetState extends State<SocialPostCommentsSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  String? _gifUrl;
  bool _loading = true;
  bool _sending = false;
  bool _addedComment = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await widget.api.socialPostComments(
        token: widget.token,
        postId: widget.postId,
      );
      if (mounted) setState(() => _comments = comments);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_sending || (text.isEmpty && _gifUrl == null)) return;
    setState(() => _sending = true);
    try {
      await widget.api.createSocialPostComment(
        token: widget.token,
        postId: widget.postId,
        text: text,
        gifUrl: _gifUrl,
      );
      _controller.clear();
      setState(() {
        _gifUrl = null;
        _addedComment = true;
      });
      await _load();
    } on Exception catch (error) {
      if (mounted) _showError('Could not post comment: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addEmoji() async {
    final emoji = await showSocialEmojiPicker(context);
    if (emoji == null || !mounted) return;
    final value = _controller.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    final text = value.text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _addGif() async {
    final gif = await showTenorGifPicker(
      context,
      api: widget.api,
      token: widget.token,
    );
    final url = gif?['url'];
    if (mounted && url is String) setState(() => _gifUrl = url);
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(text, localize: true)));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      12 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, _addedComment),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText('Could not load comments: $_error'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _comments.isEmpty
                ? const Center(child: AppText('No comments yet.'))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final gif = comment['gifUrl'];
                      return ListTile(
                        title: Text(
                          '${comment['displayName'] ?? 'SpotGo user'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ('${comment['text'] ?? ''}'.isNotEmpty)
                              Text('${comment['text']}'),
                            if (gif is String)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Image.network(gif, height: 120),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_gifUrl case final gif?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  Image.network(gif, height: 90),
                  IconButton(
                    onPressed: () => setState(() => _gifUrl = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Add emoji',
                onPressed: _addEmoji,
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              IconButton(
                tooltip: 'Add GIF',
                onPressed: _addGif,
                icon: const Icon(Icons.gif_box_outlined),
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('social-comment-input'),
                  controller: _controller,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('social-comment-send'),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
