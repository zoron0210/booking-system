import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:myapp/core/app_text.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/business_type.dart';
import 'package:myapp/core/skeleton_loader.dart';
import 'package:myapp/features/app_shell/presentation/app_bottom_navigation.dart';
import 'package:myapp/features/app_shell/presentation/customer_navigation_scope.dart';
import 'package:myapp/features/app_shell/presentation/event_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/fitness_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/auth/presentation/guest_access.dart';
import 'package:myapp/features/bookings/presentation/customer_bookings_page.dart';
import 'package:myapp/features/bookings/presentation/matchmaking_lobby_list_page.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';
import 'package:myapp/features/profile/presentation/profile_dashboard.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/features/social/presentation/home_search_page.dart';
import 'package:myapp/features/social/presentation/public_user_profile.dart';
import 'package:myapp/features/social/presentation/social_clubs_page.dart';
import 'package:myapp/features/social/presentation/social_community_page.dart';
import 'package:myapp/features/social/presentation/social_home_palette.dart';
import 'package:myapp/features/social/presentation/social_notifications_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.businessType,
    this.hideBottomNavigation = false,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String? businessType;
  final bool hideBottomNavigation;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  late final AuthApi _api;
  String? _token;
  int? _currentUserId;
  List<Map<String, dynamic>> _forYouPosts = [];
  List<Map<String, dynamic>> _followingPosts = [];
  Object? _forYouError;
  Object? _followingError;
  bool _loadingForYou = true;
  bool _loadingFollowing = true;
  bool _followingRequested = false;
  bool _posting = false;
  int _unreadSocialNotifications = 0;
  Object? _socialNotificationsError;
  int _selectedHomeFeed = 0;
  final _homeFeedPageController = PageController();

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _load();
  }

  @override
  void dispose() {
    _homeFeedPageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingForYou = true;
      _forYouError = null;
      if (_followingRequested) {
        _loadingFollowing = true;
        _followingError = null;
      }
    });
    try {
      final session = await AppSessionService.instance.load();
      if (!mounted) return;
      setState(() {
        if (_token != session.apiToken) {
          _currentUserId = null;
          _unreadSocialNotifications = 0;
          _socialNotificationsError = null;
          _followingRequested = false;
        }
        _token = session.apiToken;
      });
      await Future.wait([
        _loadForYou(session.apiToken),
        _loadSocialNotificationCount(session.apiToken),
      ]);
      if (_selectedHomeFeed == 1 &&
          session.apiToken != null &&
          session.apiToken!.isNotEmpty) {
        await _loadFollowing(session.apiToken);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _forYouError = error;
          if (_followingRequested) {
            _followingError = error;
          }
          _loadingForYou = false;
          if (_followingRequested) {
            _loadingFollowing = false;
          }
        });
      }
    }
  }

  Future<void> _loadForYou(String? token) async {
    setState(() {
      _loadingForYou = true;
      _forYouError = null;
    });
    try {
      final posts = await _api.social.socialFeed(token, allPublicPosts: true);
      if (mounted) setState(() => _forYouPosts = posts);
    } on Exception catch (error) {
      if (mounted) setState(() => _forYouError = error);
    } finally {
      if (mounted) setState(() => _loadingForYou = false);
    }
  }

  Future<void> _loadFollowing(String? token) async {
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _followingPosts = [];
          _followingRequested = false;
          _loadingFollowing = false;
        });
      }
      return;
    }
    setState(() {
      _followingRequested = true;
      _loadingFollowing = true;
      _followingError = null;
    });
    try {
      final posts = await _api.social.socialFeed(token, followingOnly: true);
      if (mounted) setState(() => _followingPosts = posts);
    } on Exception catch (error) {
      if (mounted) setState(() => _followingError = error);
    } finally {
      if (mounted) setState(() => _loadingFollowing = false);
    }
  }

  Future<void> _loadSocialNotificationCount(String? token) async {
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _unreadSocialNotifications = 0;
          _socialNotificationsError = null;
        });
      }
      return;
    }
    try {
      final response = await _api.social.socialNotifications(token);
      if (mounted) {
        setState(() {
          _unreadSocialNotifications =
              (response['unreadCount'] as num?)?.toInt() ?? 0;
          _socialNotificationsError = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _socialNotificationsError = error);
    }
  }

  Future<void> _openComposer() async {
    if (_posting) return;
    final token = await _requireSocialToken();
    if (token == null || !mounted) return;
    final draft = await showSocialPostComposer(
      context,
      api: _api,
      token: token,
    );
    if (draft == null || !mounted) return;
    setState(() => _posting = true);
    try {
      await _api.social.createSocialPost(
        token: token,
        caption: draft.caption,
        images: draft.images,
      );
      if (!mounted) return;
      _showSocialMessage('Your experience has been shared.');
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showSocialMessage(error.userMessage);
    } on Exception catch (error) {
      if (mounted) {
        _showSocialMessage('Could not share your experience: $error');
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<String?> _requireSocialToken() async {
    if (_token case final token? when token.isNotEmpty) return token;
    if (!await requireCustomerLogin(context) || !mounted) return null;
    final session = await AppSessionService.instance.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      _showSocialMessage('Sign in to continue.');
      return null;
    }
    setState(() {
      if (_token != token) _currentUserId = null;
      _token = token;
    });
    return token;
  }

  void _showSocialMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message, localize: true),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _signInToFollowing() async {
    if (!await requireCustomerLogin(context) || !mounted) return;
    final session = await AppSessionService.instance.load();
    if (!mounted) return;
    setState(() {
      if (_token != session.apiToken) _currentUserId = null;
      _token = session.apiToken;
    });
    _selectHomeFeed(1);
    await _loadFollowing(session.apiToken);
  }

  void _selectHomeFeed(int index) {
    if (index < 0 || index > 3) return;
    if (index == 1 && (_token == null || _token!.isEmpty)) {
      _signInToFollowing();
      return;
    }
    if (index == 1 &&
        !_followingRequested &&
        _token != null &&
        _token!.isNotEmpty) {
      _loadFollowing(_token);
    }
    if (_selectedHomeFeed != index) {
      setState(() => _selectedHomeFeed = index);
    }
    if (_homeFeedPageController.hasClients &&
        _homeFeedPageController.page?.round() != index) {
      _homeFeedPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openOwnProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDashboardPage(
          onLogout: widget.onLogout,
          api: _api,
          initialUserPosition: widget.initialUserPosition,
          businessType: widget.businessType,
        ),
      ),
    );
  }

  Future<void> _openHomeUserProfile(int? userId) async {
    if (userId == null) return;
    final token = _token;
    if (token != null && token.isNotEmpty) {
      try {
        var currentUserId = _currentUserId;
        if (currentUserId == null) {
          final response = await _api.me(token);
          currentUserId = int.tryParse(
            '${(response['user'] as Map<String, dynamic>?)?['id'] ?? ''}',
          );
          if (currentUserId == null) {
            throw const FormatException('The signed-in user ID is missing.');
          }
          _currentUserId = currentUserId;
        }
        if (!mounted) return;
        if (userId == currentUserId) {
          _openOwnProfile();
          return;
        }
      } on Exception catch (error) {
        if (mounted) {
          _showSocialMessage('Could not verify this profile: $error');
        }
        return;
      }
    }
    if (!mounted) return;
    await openPublicUserProfile(
      context: context,
      api: _api,
      token: token,
      userId: userId,
    );
  }

  List<Map<String, dynamic>> get _recentPlayers {
    final seen = <int>{};
    return _forYouPosts
        .where((post) {
          final userId = (post['userId'] as num?)?.toInt();
          return userId != null && seen.add(userId);
        })
        .take(8)
        .toList();
  }

  Widget _buildPlayerRail() {
    final players = _recentPlayers;
    return SizedBox(
      height: 104,
      child: ListView(
        key: const ValueKey('customer-home-player-rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        children: [
          _PlayerBubble(
            label: 'Post Match',
            tooltip: 'Share a match or matchday moment',
            isAdd: true,
            onTap: _openComposer,
          ),
          for (final player in players)
            _PlayerBubble(
              label: '${player['displayName'] ?? 'SpotGo player'}',
              tooltip:
                  'View ${player['displayName'] ?? 'SpotGo player'} profile',
              imageProvider: player['avatarUrl'] is String
                  ? socialAvatarProvider(player['avatarUrl'] as String)
                  : null,
              onTap: () => _openHomeUserProfile(
                int.tryParse('${player['userId'] ?? ''}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeFilters() => SizedBox(
    height: 58,
    child: ListView(
      key: const ValueKey('customer-home-feed-tabs'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      children: [
        _HomeFeedFilter(
          label: 'Latest',
          selected: _selectedHomeFeed == 0,
          onTap: () => _selectHomeFeed(0),
        ),
        _HomeFeedFilter(
          label: 'Following',
          selected: _selectedHomeFeed == 1,
          onTap: () => _selectHomeFeed(1),
        ),
        _HomeFeedFilter(
          label: 'Community',
          selected: _selectedHomeFeed == 2,
          onTap: () => _selectHomeFeed(2),
        ),
        _HomeFeedFilter(
          label: 'Find Match',
          selected: _selectedHomeFeed == 3,
          onTap: () => _selectHomeFeed(3),
        ),
      ],
    ),
  );

  Widget _buildCommunitySearchButton() => IconButton(
    key: const ValueKey('customer-home-search'),
    tooltip: 'Search people, posts, or clubs',
    onPressed: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeSearchPage(
          api: _api,
          token: _token,
          onRequireToken: _requireSocialToken,
          onOpenProfile: (userId) => _openHomeUserProfile(userId),
        ),
      ),
    ),
    icon: const Icon(Icons.search_rounded),
  );

  Future<void> _openSocialNotifications() async {
    var token = _token;
    if (token == null || token.isEmpty) {
      if (!await requireCustomerLogin(context) || !mounted) return;
      final session = await AppSessionService.instance.load();
      if (!mounted) return;
      token = session.apiToken;
      if (token == null || token.isEmpty) {
        _showSocialMessage('Sign in to view notifications.');
        return;
      }
      setState(() => _token = token);
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialNotificationsPage(
          api: _api,
          token: token!,
          onUnreadCountChanged: (count) {
            if (mounted) {
              setState(() => _unreadSocialNotifications = count);
            }
          },
        ),
      ),
    );
    if (mounted) await _loadSocialNotificationCount(token);
  }

  Widget _buildNotificationsButton(SocialHomeColors colors) => IconButton(
    key: const ValueKey('customer-home-notifications'),
    tooltip: _socialNotificationsError == null
        ? 'Notifications'
        : 'Notifications unavailable',
    onPressed: _openSocialNotifications,
    icon: Badge(
      isLabelVisible: _unreadSocialNotifications > 0,
      backgroundColor: colors.coral,
      textColor: Colors.white,
      label: Text(
        _unreadSocialNotifications > 99 ? '99+' : '$_unreadSocialNotifications',
      ),
      child: Icon(
        _unreadSocialNotifications > 0
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
      ),
    ),
  );

  Widget _buildFeed({
    required BuildContext context,
    required bool following,
    required List<Map<String, dynamic>> posts,
    required bool loading,
    required Object? error,
  }) {
    final colors = SocialHomeColors.of(context);
    if (following && (_token == null || _token!.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.people_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const AppText(
              'Follow people to see their experiences here.',
              textAlign: TextAlign.center,
              localize: true,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                key: const ValueKey('customer-home-following-sign-in'),
                onPressed: _signInToFollowing,
                child: const AppText('Sign in to continue', localize: true),
              ),
            ),
          ],
        ),
      );
    }
    if (loading && posts.isEmpty) {
      return const _CustomerFeedSkeleton();
    }
    if (error != null && posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'We couldn’t load experiences. Please try again.',
                textAlign: TextAlign.center,
                localize: true,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: ValueKey(
                  following
                      ? 'customer-home-following-retry'
                      : 'customer-home-for-you-retry',
                ),
                onPressed: () =>
                    following ? _loadFollowing(_token) : _loadForYou(_token),
                icon: const Icon(Icons.refresh_rounded),
                label: const AppText('Try again', localize: true),
              ),
            ],
          ),
        ),
      );
    }
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  following
                      ? Icons.people_outline_rounded
                      : Icons.dynamic_feed_outlined,
                  size: 42,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppText(
              following
                  ? 'People you follow haven’t shared experiences yet.'
                  : 'No experiences yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              localize: true,
            ),
            if (following) ...[
              const SizedBox(height: 8),
              Center(
                child: FilledButton.icon(
                  key: const ValueKey('customer-home-browse-for-you'),
                  onPressed: () => _selectHomeFeed(0),
                  icon: const Icon(Icons.explore_outlined),
                  label: const AppText('Browse Latest', localize: true),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const AppText(
                'Experiences from customers will show up here.',
                textAlign: TextAlign.center,
                localize: true,
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  key: const ValueKey('customer-home-explore-venues'),
                  onPressed: () => _onDestinationSelected(0),
                  icon: const Icon(Icons.sports_tennis_rounded),
                  label: const AppText('Explore sports venues', localize: true),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      key: ValueKey(
        following
            ? 'customer-home-following-feed'
            : 'customer-home-experience-feed',
      ),
      children: [
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SocialExperiencePostCard(
              post: post,
              onOpenPerson: () =>
                  _openHomeUserProfile(int.tryParse('${post['userId'] ?? ''}')),
              onFollow: null,
              api: _api,
              token: _token,
              onRequireToken: _requireSocialToken,
              onOpenProfile: (userId) => _openHomeUserProfile(userId),
              homeFeedStyle: true,
              onPostChanged: () {
                if (following) {
                  _loadFollowing(_token);
                } else {
                  _loadForYou(_token);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Column(
      children: [
        _buildHomeFilters(),
        Expanded(
          child: PageView(
            key: const ValueKey('customer-home-feed-pages'),
            controller: _homeFeedPageController,
            onPageChanged: (index) {
              if (_selectedHomeFeed != index) {
                setState(() => _selectedHomeFeed = index);
              }
            },
            children: [
              _buildHomeExperiencePage(context, following: false),
              _buildHomeExperiencePage(context, following: true),
              SocialClubsPage(
                key: const ValueKey('customer-home-community-page'),
                api: _api,
                token: _token,
                onRequireToken: _requireSocialToken,
                onOpenProfile: _openHomeUserProfile,
              ),
              MatchmakingLobbyListPage(
                key: const ValueKey('customer-home-find-match-page'),
                api: _api,
                initialUserPosition: widget.initialUserPosition,
                isActive: _selectedHomeFeed == 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeExperiencePage(
    BuildContext context, {
    required bool following,
  }) => RefreshIndicator(
    onRefresh: () => following ? _loadFollowing(_token) : _loadForYou(_token),
    child: ListView(
      key: ValueKey(
        following
            ? 'customer-home-following-timeline'
            : 'customer-home-timeline',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 104),
      children: [
        _buildPlayerRail(),
        _buildFeed(
          context: context,
          following: following,
          posts: following ? _followingPosts : _forYouPosts,
          loading: following ? _loadingFollowing : _loadingForYou,
          error: following ? _followingError : _forYouError,
        ),
      ],
    ),
  );

  ThemeData _homeTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SocialHomeColors.forBrightness(theme.colorScheme.brightness);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.coral,
        surface: colors.surface,
        onSurface: colors.text,
        onSurfaceVariant: colors.muted,
      ),
      extensions: [colors],
      scaffoldBackgroundColor: colors.canvas,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: colors.surfaceRaised,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerColor: colors.border,
    );
  }

  void _onDestinationSelected(int index) {
    final navigation = CustomerNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.onDestinationSelected(index);
      return;
    }
    final Widget? destination = switch (index) {
      0 => switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.event => EventDashboardPage(
          onLogout: widget.onLogout,
          api: _api,
          initialUserPosition: widget.initialUserPosition,
        ),
        BusinessType.fitness => FitnessDashboardPage(
          onLogout: widget.onLogout,
          api: _api,
          initialUserPosition: widget.initialUserPosition,
        ),
        _ => NewsFeedPage(
          onLogout: widget.onLogout,
          api: _api,
          initialUserPosition: widget.initialUserPosition,
          businessType: widget.businessType ?? 'Sports',
        ),
      },
      2 => MessagesDashboardPage(
        initialUserPosition: widget.initialUserPosition,
        api: _api,
        businessType: widget.businessType,
      ),
      3 => CustomerBookingsPage(
        onLogout: widget.onLogout,
        api: _api,
        initialUserPosition: widget.initialUserPosition,
        businessType: widget.businessType,
      ),
      4 => ProfileDashboardPage(
        onLogout: widget.onLogout,
        api: _api,
        initialUserPosition: widget.initialUserPosition,
        businessType: widget.businessType,
      ),
      _ => null,
    };
    if (destination == null) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final homeTheme = _homeTheme(context);
    return Theme(
      data: homeTheme,
      child: Builder(
        builder: (context) {
          final colors = SocialHomeColors.of(context);
          return Scaffold(
            backgroundColor: colors.canvas,
            appBar: AppBar(
              toolbarHeight: 60,
              titleSpacing: 16,
              title: Row(
                children: [
                  const SpotGoLogo(size: 28),
                  const SizedBox(width: 8),
                  AppText(
                    'SpotGO',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildCommunitySearchButton(),
                _buildNotificationsButton(colors),
                const SizedBox(width: 8),
              ],
            ),
            body: _buildTimeline(context),
            bottomNavigationBar: widget.hideBottomNavigation
                ? null
                : AppBottomNavigation(
                    selectedIndex: 5,
                    hideSavedDestination: true,
                    showHomeDestination: true,
                    onDestinationSelected: _onDestinationSelected,
                    onDestinationReselected: _load,
                  ),
          );
        },
      ),
    );
  }
}

class _CustomerFeedSkeleton extends StatelessWidget {
  const _CustomerFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading experiences',
      liveRegion: true,
      child: SkeletonPulse(
        child: Container(
          key: const ValueKey('customer-home-feed-skeleton'),
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SkeletonBlock(
                        width: 44,
                        height: 44,
                        borderRadius: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBlock(width: 142, height: 13),
                            SizedBox(height: 8),
                            SkeletonBlock(width: 86, height: 10),
                          ],
                        ),
                      ),
                      const SkeletonBlock(
                        width: 28,
                        height: 28,
                        borderRadius: 14,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: double.infinity, height: 12),
                      SizedBox(height: 7),
                      SkeletonBlock(width: 174, height: 12),
                    ],
                  ),
                ),
                const SkeletonBlock(height: 190, borderRadius: 0),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SkeletonBlock(width: 58, height: 22),
                      SizedBox(width: 12),
                      SkeletonBlock(width: 58, height: 22),
                      Spacer(),
                      SkeletonBlock(width: 74, height: 22),
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

class _PlayerBubble extends StatelessWidget {
  const _PlayerBubble({
    required this.label,
    this.tooltip,
    this.imageProvider,
    this.isAdd = false,
    required this.onTap,
  });

  final String label;
  final String? tooltip;
  final ImageProvider<Object>? imageProvider;
  final bool isAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    final bubble = SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAdd ? colors.muted : colors.primary,
                    width: isAdd ? 1.5 : 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: colors.surfaceRaised,
                  backgroundImage: imageProvider,
                  child: isAdd
                      ? Icon(Icons.add_rounded, color: colors.text, size: 24)
                      : imageProvider == null
                      ? Icon(
                          Icons.person_outline_rounded,
                          color: colors.muted,
                          size: 22,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 5),
              AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                localize: true,
              ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return bubble;
    return Tooltip(message: tooltip!, child: bubble);
  }
}

class _HomeFeedFilter extends StatelessWidget {
  const _HomeFeedFilter({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey('customer-home-filter-${label.toLowerCase()}'),
        label: AppText(label, localize: true),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary,
        backgroundColor: colors.surfaceRaised,
        side: BorderSide(color: selected ? colors.primary : colors.border),
        labelStyle: TextStyle(
          color: selected ? Colors.white : colors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
