import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/core/app_text.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/social/presentation/social_home_palette.dart';
import 'package:myapp/features/social/presentation/social_community_page.dart';

const _searchHistoryKey = 'customer_home_social_search_history';
const _searchHistoryLimit = 8;

class HomeSearchPage extends StatefulWidget {
  const HomeSearchPage({
    super.key,
    required this.api,
    required this.token,
    required this.onOpenProfile,
    this.onRequireToken,
  });

  final AuthApi api;
  final String? token;
  final Future<void> Function(int userId) onOpenProfile;
  final Future<String?> Function()? onRequireToken;

  @override
  State<HomeSearchPage> createState() => _HomeSearchPageState();
}

class _HomeSearchPageState extends State<HomeSearchPage> {
  final _queryController = TextEditingController();
  List<String> _history = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _suggestedPosts = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loadingSuggestions = true;
  bool _searching = false;
  bool _hasSearched = false;
  Object? _suggestionError;
  Object? _searchError;
  Object? _historyError;
  var _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final history = preferences.getStringList(_searchHistoryKey) ?? [];
      if (mounted) setState(() => _history = history);
    } on Exception catch (error) {
      if (mounted) setState(() => _historyError = error);
    }
  }

  Future<void> _saveHistory(String query) async {
    final history = [
      query,
      ..._history.where((item) => item.toLowerCase() != query.toLowerCase()),
    ].take(_searchHistoryLimit).toList();
    setState(() {
      _history = history;
      _historyError = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(_searchHistoryKey, history);
      if (!saved && mounted) {
        setState(
          () => _historyError = StateError('Search history was not saved.'),
        );
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _historyError = error);
    }
  }

  Future<void> _clearHistory() async {
    setState(() {
      _history = [];
      _historyError = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(_searchHistoryKey, []);
      if (!saved && mounted) {
        setState(
          () => _historyError = StateError('Search history was not cleared.'),
        );
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _historyError = error);
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestionError = null;
    });
    try {
      final responses = await Future.wait([
        widget.api.social.searchSocialUsers(widget.token),
        widget.api.social.socialFeed(widget.token, allPublicPosts: true),
      ]);
      if (!mounted) return;
      setState(() {
        _suggestedUsers = responses[0];
        _suggestedPosts = responses[1];
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _suggestionError = error);
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _searchFor(String value) async {
    final query = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty) return;
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    final generation = ++_searchGeneration;
    setState(() {
      _hasSearched = true;
      _searching = true;
      _searchError = null;
    });
    await _saveHistory(query);
    try {
      final responses = await Future.wait([
        widget.api.social.searchSocialUsers(widget.token, query: query),
        widget.api.social.socialFeed(
          widget.token,
          allPublicPosts: true,
          query: query,
        ),
      ]);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _users = responses[0];
        _posts = responses[1];
      });
    } on Exception catch (error) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searchError = error);
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _refreshSearch() => _searchFor(_queryController.text);

  Widget _sectionTitle(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            title,
            style: TextStyle(
              color: SocialHomePalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _personTile(Map<String, dynamic> user, {bool suggestion = false}) {
    final userId = (user['id'] as num?)?.toInt();
    final avatar = user['avatarUrl'] as String?;
    final provider = avatar == null || avatar.isEmpty
        ? null
        : socialAvatarProvider(avatar);
    return ListTile(
      key: ValueKey('home-search-person-$userId'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CircleAvatar(
        backgroundImage: provider,
        child: provider == null
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
        suggestion
            ? 'Suggested person'
            : '${(user['followersCount'] as num?)?.toInt() ?? 0} followers',
        localize: true,
      ),
      onTap: userId == null ? null : () => widget.onOpenProfile(userId),
    );
  }

  Widget _historyTile(String query) => ListTile(
    key: ValueKey('home-search-history-$query'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
    leading: const Icon(Icons.history_rounded),
    title: AppText(query, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: IconButton(
      tooltip: 'Remove search',
      onPressed: () async {
        setState(() {
          _history.remove(query);
          _historyError = null;
        });
        try {
          final preferences = await SharedPreferences.getInstance();
          final saved = await preferences.setStringList(
            _searchHistoryKey,
            _history,
          );
          if (!saved && mounted) {
            setState(
              () =>
                  _historyError = StateError('Search history was not updated.'),
            );
          }
        } on Exception catch (error) {
          if (mounted) setState(() => _historyError = error);
        }
      },
      icon: const Icon(Icons.close_rounded, size: 18),
    ),
    onTap: () => _searchFor(query),
  );

  Widget _suggestions() {
    if (_loadingSuggestions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_suggestionError != null) {
      return Column(
        children: [
          AppText('Could not load suggestions: $_suggestionError'),
          TextButton(
            onPressed: _loadSuggestions,
            child: const AppText('Retry', localize: true),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_suggestedUsers.isNotEmpty) ...[
          _sectionTitle('Suggested people'),
          for (final user in _suggestedUsers.take(5))
            _personTile(user, suggestion: true),
        ],
        if (_suggestedPosts.isNotEmpty) ...[
          _sectionTitle('Suggested posts'),
          for (final post in _suggestedPosts.take(5))
            ListTile(
              key: ValueKey('home-search-suggested-post-${post['id']}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              leading: const Icon(Icons.article_outlined),
              title: AppText(
                '${post['caption'] ?? 'Sports experience'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: AppText(
                '${post['displayName'] ?? 'SpotGo user'}',
                localize: true,
              ),
              onTap: () => _searchFor('${post['caption'] ?? ''}'),
            ),
        ],
        if (_suggestedUsers.isEmpty && _suggestedPosts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: AppText(
              'Search for people by name or find posts by their caption.',
              textAlign: TextAlign.center,
              localize: true,
            ),
          ),
      ],
    );
  }

  Widget _searchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText('Search failed: $_searchError'),
            TextButton(
              onPressed: _refreshSearch,
              child: const AppText('Retry', localize: true),
            ),
          ],
        ),
      );
    }
    if (_users.isEmpty && _posts.isEmpty) {
      return const Center(
        child: AppText(
          'No people or posts match your search.',
          textAlign: TextAlign.center,
          localize: true,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (_users.isNotEmpty) ...[
          _sectionTitle('People (${_users.length})'),
          for (final user in _users) _personTile(user),
        ],
        if (_posts.isNotEmpty) ...[
          _sectionTitle('Posts (${_posts.length})'),
          for (final post in _posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SocialExperiencePostCard(
                post: post,
                onOpenPerson: () {
                  final userId = (post['userId'] as num?)?.toInt();
                  if (userId != null) widget.onOpenProfile(userId);
                },
                onFollow: null,
                api: widget.api,
                token: widget.token,
                onRequireToken: widget.onRequireToken,
                onOpenProfile: widget.onOpenProfile,
                onPostChanged: _refreshSearch,
                homeFeedStyle: true,
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: TextField(
        key: const ValueKey('customer-home-search-input'),
        controller: _queryController,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchFor,
        onChanged: (_) {
          if (_hasSearched) setState(() => _hasSearched = false);
          setState(() {});
        },
        decoration: const InputDecoration(
          hintText: 'Search people or posts',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      actions: [
        IconButton(
          key: const ValueKey('customer-home-search-submit'),
          tooltip: 'Search',
          onPressed: _searching
              ? null
              : () => _searchFor(_queryController.text),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    ),
    body: _hasSearched
        ? _searchResults()
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (_history.isNotEmpty) ...[
                _sectionTitle(
                  'Recent searches',
                  trailing: TextButton(
                    onPressed: _clearHistory,
                    child: const AppText('Clear', localize: true),
                  ),
                ),
                for (final query in _history) _historyTile(query),
              ],
              if (_historyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppText(
                    'Search history could not be updated: $_historyError',
                  ),
                ),
              _suggestions(),
            ],
          ),
  );
}
