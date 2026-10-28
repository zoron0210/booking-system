import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'features/session/application/session_service.dart';
import 'features/social/presentation/social_home_palette.dart';
import 'features/social/presentation/social_notifications_page.dart';
import 'sports.dart';
import 'saved_items.dart';
import 'saved_icons.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'profile_dashboard.dart';
import 'public_user_profile.dart';
import 'reserve_dashboard.dart';
import 'reviews.dart';
import 'fitness_dashboard.dart';
import 'event_dashboard.dart';
import 'fitness_booking_page.dart';
import 'fitness_booking_calendar.dart';
import 'event_booking_page.dart';
import 'all_venues_page.dart';
import 'merchant_business_status.dart';
import 'app_card_styles.dart';
import 'app_bottom_navigation.dart';
import 'guest_access.dart';
import 'filter_panel_style.dart';
import 'sports_slot_configurations.dart';
import 'app_design_system.dart';
import 'rating_widgets.dart';
import 'skeleton_loader.dart';
import 'core/business_type.dart';
import 'app_preferences.dart';
import 'social_community_page.dart';

Color get _newsInk => AppColors.ink;
Color get _newsMuted => AppColors.muted;
Color get _newsOrange => AppColors.accent;
Color get _newsAccentForeground => AppColors.accentForeground;
Color get _newsPage => AppColors.page;
const _newsCardImageHeight = 160.0;

class _NewsImageCarousel extends StatefulWidget {
  const _NewsImageCarousel({required this.images, required this.imageProvider});

  final List<String> images;
  final ImageProvider<Object>? Function(String value) imageProvider;

  @override
  State<_NewsImageCarousel> createState() => _NewsImageCarouselState();
}

class _NewsImageCarouselState extends State<_NewsImageCarousel> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.images.length > 1 ? widget.images.length * 1000 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    return SizedBox(
      height: _newsCardImageHeight,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: multiple ? null : 1,
            onPageChanged: (page) {
              setState(() => _index = page % widget.images.length);
            },
            itemBuilder: (_, page) {
              final provider = widget.imageProvider(
                widget.images[page % widget.images.length],
              );
              return Image(
                image:
                    provider ??
                    const AssetImage('assets/court/pickle-court.jpg'),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.softOrange,
                  child: Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: _newsAccentForeground,
                      size: 52,
                    ),
                  ),
                ),
              );
            },
          ),
          if (multiple)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var dot = 0; dot < widget.images.length; dot++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: dot == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dot == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color get _venueCanvas => AppPreferences.instance.darkMode
    ? const Color(0xFF0B1326)
    : const Color(0xFFF5F6FA);
Color get _venueSurface =>
    AppPreferences.instance.darkMode ? const Color(0xFF131B2E) : Colors.white;
Color get _venueCard =>
    AppPreferences.instance.darkMode ? const Color(0xFF171F33) : Colors.white;
Color get _venueOutline => AppPreferences.instance.darkMode
    ? const Color(0xFF30394E)
    : const Color(0xFFD8DEEA);
const _venuePrimary = Color(0xFF5752E8);
Color get _venueMint => AppPreferences.instance.darkMode
    ? const Color(0xFF55DDA4)
    : const Color(0xFF087F5B);
Color get _venueText => AppPreferences.instance.darkMode
    ? const Color(0xFFF4F3FF)
    : const Color(0xFF182238);
Color get _venueMuted => AppPreferences.instance.darkMode
    ? const Color(0xFFAAA9BA)
    : const Color(0xFF647089);

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({
    super.key,
    this.onLogout,
    this.savedOnly = false,
    this.hideAppBar = false,
    this.hideBottomNavigation = false,
    this.api,
    this.initialUserPosition,
    this.businessType = 'Sports',
    this.pageTitle = 'Sports Courts',
    this.savedItemType = 'sports',
    this.categoryNoun = 'sports',
    this.venueNoun = 'courts',
    this.searchHint = 'Search venues, categories, or news...',
    this.highestRatedSectionTitle = 'Highest rate',
    this.allVenuesHeading = 'All listed courts',
    this.categoryFilterLabel = 'Sport type',
    this.facilityFilterLabel = 'Court type',
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final bool savedOnly;
  final bool hideAppBar;
  final bool hideBottomNavigation;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String businessType;
  final String pageTitle;
  final String savedItemType;
  final String categoryNoun;
  final String venueNoun;
  final String searchHint;
  final String highestRatedSectionTitle;
  final String allVenuesHeading;
  final String categoryFilterLabel;
  final String facilityFilterLabel;

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  late final AuthApi _api;
  late final VenueCatalogRepository _venueCatalog;
  final _searchController = TextEditingController();
  final _feedScrollController = ScrollController();
  final _feedRefreshKey = GlobalKey<RefreshIndicatorState>();
  late Future<List<Map<String, dynamic>>> _posts;
  final Set<String> _savedKeys = <String>{};
  final Set<String> _heartedVenueKeys = <String>{};
  final Set<String> _heartUpdatesInProgress = <String>{};
  final Map<String, int> _heartCounts = <String, int>{};
  final MapController _courtMapController = MapController();
  final Map<String, int> _featuredImageIndexes = <String, int>{};
  late Future<List<VenueBusiness>> _businesses;
  var _feedGeneration = 0;
  var _courtMapExpanded = false;
  Position? _userPosition;
  var _locationLoading = false;
  String _feedArea = 'All areas';
  late String _feedSport;
  String _feedCourtType = 'All';
  String _feedAvailability = 'Any';
  String _feedPriceSort = 'Recommended';
  double? _feedMaxPrice;
  double? _feedMinimumRating;
  final Set<String> _feedAmenities = <String>{};

  String get _categoryAllLabel => widget.businessType.toLowerCase() == 'sports'
      ? 'All sports'
      : 'All types';
  bool get _isSportsFeed =>
      BusinessTypeParser.parse(widget.businessType) == BusinessType.sports;
  bool get _isEventFeed =>
      BusinessTypeParser.parse(widget.businessType) == BusinessType.event;
  bool get _isFitnessFeed =>
      BusinessTypeParser.parse(widget.businessType) == BusinessType.fitness;

  String get _facilityAllLabel => 'All';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _venueCatalog = VenueCatalogRepository(_api);
    _userPosition = widget.initialUserPosition;
    _feedSport = _categoryAllLabel;
    _businesses = _venueCatalog.customerBusinesses(
      includeDisabledEvents:
          BusinessTypeParser.parse(widget.businessType) == BusinessType.event,
    );
    _posts = _loadFeed();
    _loadSavedKeys();
  }

  @override
  void didUpdateWidget(covariant NewsFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bookingTypeChanged =
        BusinessTypeParser.parse(oldWidget.businessType) !=
        BusinessTypeParser.parse(widget.businessType);
    final savedTypeChanged =
        oldWidget.savedItemType.toLowerCase() !=
        widget.savedItemType.toLowerCase();
    if (!bookingTypeChanged && !savedTypeChanged) return;

    _feedGeneration++;
    _searchController.clear();
    _feedArea = 'All areas';
    _feedSport = _categoryAllLabel;
    _feedCourtType = _facilityAllLabel;
    _feedAvailability = 'Any';
    _feedPriceSort = 'Recommended';
    _feedMaxPrice = null;
    _feedMinimumRating = null;
    _feedAmenities.clear();
    _savedKeys.clear();
    _heartedVenueKeys.clear();
    _heartUpdatesInProgress.clear();
    _heartCounts.clear();
    if (bookingTypeChanged) _userPosition = widget.initialUserPosition;
    _businesses = _venueCatalog.customerBusinesses(
      includeDisabledEvents: _isEventFeed,
    );
    _posts = _loadFeed();
    _loadSavedKeys();
  }

  Future<List<Map<String, dynamic>>> _loadFeed() async {
    final generation = _feedGeneration;
    final businessType = widget.businessType;
    final businessesFuture = _businesses;
    final session = await AppSessionService.instance.load();
    final token = session.apiToken;
    final isEventFeed =
        BusinessTypeParser.parse(businessType) == BusinessType.event;
    final businesses = await businessesFuture;
    if (generation != _feedGeneration) return [];
    if (token == null || token.isEmpty) {
      final posts = businesses
          .map((businessModel) {
            final business = businessModel.toViewData();
            final businessId = businessModel.id;
            final eventTypes = _stringList(business['eventTypes']);
            final name = '${business['name'] ?? 'Venue'}';
            final enabled = !_isMerchantDisabled(business);
            final post = <String, dynamic>{
              ...business,
              'id': businessId,
              'businessId': businessId,
              'businessName': name,
              'businessType': business['businessType'] ?? businessType,
              'category': eventTypes.isEmpty
                  ? '${business['category'] ?? ''}'
                  : eventTypes.join(', '),
              'eventTypes': eventTypes,
              'address': business['address'] ?? '',
              'imageUrl': business['imageUrl'],
              'imageUrls': business['imageUrls'],
              'title': name,
              'body': '${business['details'] ?? ''}',
              'enabled': enabled,
              'businessEnabled': enabled,
              'business': business,
            };
            _heartCounts['$businessId'] = _number(business['heartCount'])
                .toInt();
            return post;
          })
          .where(
            (post) => _matchesBusinessType(post['businessType'], businessType),
          )
          .toList();
      if (widget.savedOnly) return [];
      return posts;
    }
    final feedPosts = isEventFeed
        ? <Map<String, dynamic>>[]
        : (await _api.venues.newsFeed(
            token,
            businessType: businessType,
          )).map((post) => post.toViewData()).toList();
    if (generation != _feedGeneration) return [];
    for (final post in feedPosts) {
      final key = _postHeartKey(post);
      if (key.isEmpty) continue;
      _heartCounts[key] = _number(post['heartCount']).toInt();
      if (post['heartedByMe'] == true ||
          post['heartedByMe'] == 1 ||
          post['heartedByMe'] == '1') {
        _heartedVenueKeys.add(key);
      } else {
        _heartedVenueKeys.remove(key);
      }
    }
    if (isEventFeed) {
      try {
        final heartedBusinessIds = await _api.venues.customerHeartedBusinessIds(
          token,
        );
        if (generation != _feedGeneration) return [];
        _heartedVenueKeys
          ..clear()
          ..addAll(heartedBusinessIds.map((id) => '$id'));
      } on AuthApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        debugPrint(
          'Event venue listings loaded without preloaded heart state because '
          'the backend does not provide /api/customer/venue-hearts.',
        );
      }
    }
    final enabledBusinessIds = businesses
        .where((business) => !_isMerchantDisabled(business.toViewData()))
        .map((business) => business.id)
        .toSet();
    final businessesById = {
      for (final business in businesses) business.id: business.toViewData(),
    };
    final posts = feedPosts
        .map((post) {
          final businessId = int.tryParse('${post['businessId'] ?? ''}');
          final business = businessId == null
              ? const <String, dynamic>{}
              : businessesById[businessId] ?? const <String, dynamic>{};
          final enabled =
              businessId != null &&
              enabledBusinessIds.contains(businessId) &&
              !_isMerchantDisabled(post);
          final eventTypes = _stringList(post['eventTypes']);
          final isEvent =
              BusinessTypeParser.parse(post['businessType']) ==
              BusinessType.event;
          return {
            ...business,
            ...post,
            'sportsSlots':
                post['sportsSlots'] ??
                post['sports_slots_json'] ??
                business['sportsSlots'] ??
                business['sports_slots_json'],
            'sportTypes':
                post['sportTypes'] ??
                post['sport_types'] ??
                business['sportTypes'] ??
                business['sport_types'],
            'business': post['business'] ?? business,
            if (isEvent && eventTypes.isNotEmpty)
              'category': eventTypes.join(', '),
            'eventTypes': eventTypes,
            'enabled': enabled,
            'businessEnabled': enabled,
          };
        })
        .where(
          (post) => _matchesBusinessType(post['businessType'], businessType),
        )
        .toList();
    if (generation != _feedGeneration) return [];
    if (isEventFeed) {
      final listedBusinessIds = posts
          .map((post) => int.tryParse('${post['businessId'] ?? ''}'))
          .whereType<int>()
          .toSet();
      for (final businessModel in businesses) {
        final business = businessModel.toViewData();
        if (BusinessTypeParser.parse(business['businessType']) !=
            BusinessType.event) {
          continue;
        }
        final businessId = int.tryParse('${business['id'] ?? ''}');
        if (businessId == null || listedBusinessIds.contains(businessId)) {
          continue;
        }
        final eventTypes = _stringList(business['eventTypes']);
        final name = '${business['name'] ?? 'Event venue'}';
        posts.add({
          ...business,
          'id': businessId,
          'businessId': businessId,
          'businessName': name,
          'businessType': 'Event',
          'category': eventTypes.isEmpty
              ? '${business['category'] ?? 'Event'}'
              : eventTypes.join(', '),
          'eventTypes': eventTypes,
          'address': business['address'] ?? '',
          'imageUrl': business['imageUrl'],
          'imageUrls': business['imageUrls'],
          'title': name,
          'body': '${business['details'] ?? ''}',
          'averageRating': business['averageRating'] ?? 0,
          'reviewCount': business['reviewCount'] ?? 0,
          'ratingUserCount': business['ratingUserCount'] ?? 0,
          'heartCount': business['heartCount'] ?? 0,
          'enabled':
              business['enabled'] != false &&
              business['enabled'] != 0 &&
              business['enabled'] != '0' &&
              business['enabled'] != 'false' &&
              business['enabled'] != 'FALSE',
          'businessEnabled':
              business['enabled'] != false &&
              business['enabled'] != 0 &&
              business['enabled'] != '0' &&
              business['enabled'] != 'false' &&
              business['enabled'] != 'FALSE',
        });
        final heartKey = _postHeartKey(posts.last);
        if (heartKey.isNotEmpty) {
          _heartCounts[heartKey] = _number(business['heartCount']).toInt();
          if (business.containsKey('heartedByMe')) {
            if (business['heartedByMe'] == true ||
                business['heartedByMe'] == 1 ||
                business['heartedByMe'] == '1') {
              _heartedVenueKeys.add(heartKey);
            } else {
              _heartedVenueKeys.remove(heartKey);
            }
          }
        }
        listedBusinessIds.add(businessId);
      }
    }
    if (!widget.savedOnly) return posts;
    final saved = await SavedItemStore.list(api: _api);
    final savedKeys = saved
        .where(
          (item) =>
              '${item['itemType'] ?? ''}'.toLowerCase() ==
              widget.savedItemType.toLowerCase(),
        )
        .map((item) => '${item['itemKey'] ?? ''}')
        .toSet();
    return posts
        .where(
          (post) =>
              savedKeys.contains('${post['businessId'] ?? ''}') ||
              savedKeys.contains('${post['businessName'] ?? ''}'),
        )
        .toList();
  }

  bool _matchesBusinessType(Object? value, String businessType) {
    final selectedType = BusinessTypeParser.parse(businessType);
    return selectedType != BusinessType.unknown &&
        BusinessTypeParser.parse(value) == selectedType;
  }

  Future<void> _reload() async {
    _businesses = _venueCatalog.customerBusinesses(
      includeDisabledEvents:
          BusinessTypeParser.parse(widget.businessType) == BusinessType.event,
    );
    final refreshed = _loadFeed();
    setState(() {
      _posts = refreshed;
    });
    await refreshed;
  }

  Future<void> _refreshAndScrollToTop() async {
    final refresh = _feedRefreshKey.currentState?.show();
    if (refresh != null) {
      await refresh;
    } else {
      await _reload();
    }
    if (!mounted) return;
    if (_feedScrollController.hasClients) {
      await _feedScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _loadSavedKeys() async {
    final generation = _feedGeneration;
    final savedItemType = widget.savedItemType.toLowerCase();
    try {
      final session = await AppSessionService.instance.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) return;
      final saved = await SavedItemStore.list(api: _api);
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where(
                  (item) =>
                      '${item['itemType'] ?? ''}'.toLowerCase() ==
                      savedItemType,
                )
                .map((item) => '${item['itemKey'] ?? ''}'),
          );
      });
    } on Exception {
      // The feed remains usable when saved items cannot be loaded.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.savedOnly ? _newsPage : _venueCanvas,
    appBar: widget.hideAppBar
        ? null
        : AppBar(
            backgroundColor: widget.savedOnly
                ? AppColors.surface
                : _venueCanvas,
            foregroundColor: widget.savedOnly ? _newsInk : _venueText,
            leading: IconButton(
              key: const ValueKey('news-feed-back'),
              tooltip: appLanguageText(
                'Back to reservations',
                'Back to reservations',
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ReserveDashboardPage(
                      initialSelection:
                          BusinessTypeParser.parse(widget.businessType)
                              .value
                              .isEmpty
                          ? widget.businessType
                          : BusinessTypeParser.parse(widget.businessType).value,
                      onLogout: widget.onLogout,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: widget.savedOnly
                    ? AppColors.page
                    : _venueSurface,
                foregroundColor: widget.savedOnly ? _newsInk : _venueText,
              ),
            ),
            title: widget.savedOnly
                ? AppText(
                    'Saved venues',
                    style: AppTypography.pageTitle.copyWith(color: _newsInk),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        'SpotGo',
                        style: TextStyle(
                          color: _venueText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      AppText(
                        widget.pageTitle,
                        style: TextStyle(
                          color: _venueMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
            titleSpacing: 4,
            actions: [
              if (!widget.savedOnly) _courtMapHeaderControl(),
              if (!widget.savedOnly)
                IconButton(
                  key: const ValueKey('news-feed-open-filters'),
                  tooltip: _activeFeedFilterCount == 0
                      ? 'Filter venues'
                      : 'Filter venues ($_activeFeedFilterCount active)',
                  onPressed: _openSportsFilters,
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: _venueSurface,
                    foregroundColor: _venueText,
                  ),
                  icon: Badge(
                    isLabelVisible: _activeFeedFilterCount > 0,
                    backgroundColor: _venuePrimary,
                    label: AppText('$_activeFeedFilterCount'),
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
            ],
          ),
    body: _courtMapExpanded && !widget.savedOnly
        ? _courtLocationsMap()
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppResponsive.contentMaxWidthFor(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              child: Column(
                children: [
                  if (!widget.savedOnly) _mainSearchBar(),
                  if (!widget.savedOnly && _isSportsFeed)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _posts,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return _sportTypeFilterBar(
                          _categoryOptions(snapshot.data!),
                        );
                      },
                    ),
                  if (!widget.savedOnly && _isSportsFeed) _quickFilterRow(),
                  Expanded(
                    child: RefreshIndicator(
                      key: _feedRefreshKey,
                      onRefresh: _reload,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _posts,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListView(
                              key: const ValueKey('news-feed-loading-skeleton'),
                              controller: _feedScrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              children: [
                                const SkeletonBlock(height: 18, width: 150),
                                const SizedBox(height: 10),
                                const SkeletonBlock(
                                  height: 230,
                                  borderRadius: 20,
                                ),
                                const SizedBox(height: 18),
                                const SkeletonBlock(height: 18, width: 170),
                                const SizedBox(height: 10),
                                const SkeletonBlock(
                                  height: 122,
                                  borderRadius: 16,
                                ),
                                const SizedBox(height: 8),
                                const SkeletonBlock(
                                  height: 122,
                                  borderRadius: 16,
                                ),
                              ],
                            );
                          }
                          if (snapshot.hasError) {
                            final error = snapshot.error;
                            return _message(
                              error is AuthApiException ? error.userMessage : 'We couldn’t load the latest updates. Please check your connection and try again.',
                              action: TextButton.icon(
                                key: const ValueKey('news-feed-retry'),
                                onPressed: () {
                                  setState(() {
                                    _posts = _loadFeed();
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const AppText(
                                  'Try again',
                                  localize: true,
                                ),
                              ),
                            );
                          }
                          final posts = _filteredPosts(
                            snapshot.data ?? const [],
                          );
                          if (posts.isEmpty) {
                            return _message(
                              widget.savedOnly
                                  ? snapshot.data?.isEmpty == true
                                        ? 'You have no saved venues yet.'
                                        : 'No saved venues match your filters or search.'
                                  : snapshot.data?.isEmpty == true
                                  ? 'No venue news has been posted yet.'
                                  : 'No ${widget.venueNoun} match your search.',
                              action: snapshot.data?.isNotEmpty == true
                                  ? TextButton.icon(
                                      key: const ValueKey(
                                        'news-feed-clear-search-and-filters',
                                      ),
                                      onPressed: _clearSearchAndFilters,
                                      icon: const Icon(Icons.filter_alt_off),
                                      label: const AppText(
                                        'Clear search and filters',
                                        localize: true,
                                      ),
                                    )
                                  : null,
                            );
                          }
                          return widget.savedOnly
                              ? _savedCardList(posts)
                              : _feedContent(posts);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    bottomNavigationBar:
        widget.hideBottomNavigation || (_courtMapExpanded && !widget.savedOnly)
        ? null
        : AppBottomNavigation(
            selectedIndex: widget.savedOnly ? 4 : 0,
            hideSavedDestination: true,
            showHomeDestination: true,
            venueDiscoveryStyle: !widget.savedOnly,
            onDestinationSelected: _onNavigationSelected,
            onDestinationReselected: _refreshAndScrollToTop,
          ),
  );

  Widget _savedCardList(List<Map<String, dynamic>> posts) => GridView.builder(
    key: const ValueKey('saved-venues-image-grid'),
    controller: _feedScrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
    ),
    itemCount: posts.length,
    itemBuilder: (context, index) {
      final post = posts[index];
      final images = _imageListValue([
        post['imageUrls'],
        post['image_urls'],
        post['images'],
        post['imageUrl'],
        post['image_url'],
        post['businessImageUrl'],
        post['business_image_url'],
        post['business'] is Map ? post['business']['imageUrls'] : null,
        post['business'] is Map ? post['business']['imageUrl'] : null,
      ]);
      final image = images.isEmpty
          ? _miniImageFallback()
          : _miniImage(images.first);
      final name = _stringValue([
        post['businessName'],
        post['name'],
        post['title'],
      ]);
      return Material(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('saved-venue-tile-${_venueIdentifier(post)}'),
          onTap: () => _openBookingType(post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Align(
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 22, 6, 6),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _openSportsFilters() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close venue filters',
      barrierColor: Colors.black54,
      transitionDuration: filterPanelTransitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _posts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? const <Map<String, dynamic>>[];
              final areas = _feedOptions(
                posts,
                (post) => '${post['address'] ?? ''}',
                'All areas',
              );
              final sports = _categoryOptions(posts);
              return Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  key: const ValueKey('filter-panel-surface'),
                  width: filterPanelWidth(context),
                  height: double.infinity,
                  child: Material(
                    color: AppColors.surface,
                    elevation: 24,
                    child: StatefulBuilder(
                      builder: (context, setSheetState) => SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: filterPanelHeaderPadding,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: AppText(
                                      'Filter venues',
                                      style: filterPanelTitleStyle,
                                      localize: true,
                                    ),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'news-feed-filter-reset',
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _feedArea = 'All areas';
                                        _feedSport = _categoryAllLabel;
                                        _feedCourtType = _facilityAllLabel;
                                        _feedAvailability = 'Any';
                                        _feedPriceSort = 'Recommended';
                                        _feedMaxPrice = null;
                                        _feedMinimumRating = null;
                                        _feedAmenities.clear();
                                        _userPosition = null;
                                      });
                                      setSheetState(() {});
                                    },
                                    child: const AppText(
                                      'Reset',
                                      localize: true,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'news-feed-filter-close',
                                    ),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Flexible(
                              child: ListView(
                                padding: filterPanelContentPadding,
                                children: [
                                  if (!_isSportsFeed) ...[
                                    _filterLabel(widget.categoryFilterLabel),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final value in sports)
                                          ChoiceChip(
                                            key: ValueKey(
                                              'news-feed-filter-sport-$value',
                                            ),
                                            label: AppText(value),
                                            selected: _feedSport == value,
                                            onSelected: (_) {
                                              setState(
                                                () => _feedSport = value,
                                              );
                                              setSheetState(() {});
                                            },
                                            selectedColor: _newsOrange,
                                            labelStyle: TextStyle(
                                              color: _feedSport == value
                                                  ? AppColors.onAccent
                                                  : _newsInk,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: filterPanelSectionSpacing,
                                    ),
                                  ],
                                  _filterLabel('Area / city'),
                                  OutlinedButton.icon(
                                    key: const ValueKey(
                                      'news-feed-use-my-location',
                                    ),
                                    onPressed: _locationLoading
                                        ? null
                                        : () => _useMyLocation(
                                            refreshSheet: () {
                                              if (dialogContext.mounted) {
                                                setSheetState(() {});
                                              }
                                            },
                                          ),
                                    icon: _locationLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            _userPosition == null
                                                ? Icons.my_location_rounded
                                                : Icons.location_on_rounded,
                                          ),
                                    label: AppText(
                                      _locationLoading
                                          ? 'Getting your location...'
                                          : _userPosition == null
                                          ? 'Use my location'
                                          : 'Using my location · nearest first',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _feedDropdown(
                                    identifier: 'area',
                                    value: _feedArea,
                                    values: areas,
                                    onChanged: (value) {
                                      setState(() => _feedArea = value);
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel(widget.facilityFilterLabel),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final value in [
                                        _facilityAllLabel,
                                        ..._feedOptions(
                                          posts,
                                          (post) =>
                                              '${post['facilityType'] ?? ''}',
                                          '',
                                        ).where((value) => value.isNotEmpty),
                                      ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-court-$value',
                                          ),
                                          label: AppText(value),
                                          selected: _feedCourtType == value,
                                          onSelected: (_) {
                                            setState(
                                              () => _feedCourtType = value,
                                            );
                                            setSheetState(() {});
                                          },
                                          selectedColor: _newsOrange,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Amenities'),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final value in const [
                                        'Parking',
                                        'Pet-friendly',
                                        'Restroom',
                                        'Shower',
                                        'Store',
                                        'Indoor / AC',
                                      ])
                                        FilterChip(
                                          key: ValueKey(
                                            'news-feed-filter-amenity-$value',
                                          ),
                                          label: AppText(value),
                                          selected: _feedAmenities.contains(
                                            value,
                                          ),
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _feedAmenities.add(value);
                                              } else {
                                                _feedAmenities.remove(value);
                                              }
                                            });
                                            setSheetState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Minimum rating'),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      for (final (label, rating)
                                          in const <(String, double?)>[
                                            ('Any rating', null),
                                            ('4.5+', 4.5),
                                          ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-rating-$label',
                                          ),
                                          label: AppText(label),
                                          selected:
                                              _feedMinimumRating == rating,
                                          onSelected: (_) {
                                            setState(
                                              () => _feedMinimumRating = rating,
                                            );
                                            setSheetState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Availability'),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final value in const [
                                        'Any',
                                        'Available today',
                                        'Open 24 hours',
                                      ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-availability-$value',
                                          ),
                                          label: AppText(value),
                                          selected: _feedAvailability == value,
                                          onSelected: (_) {
                                            setState(
                                              () => _feedAvailability = value,
                                            );
                                            setSheetState(() {});
                                          },
                                          selectedColor: _newsOrange,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Price (\u{20B1} / hour)'),
                                  Slider(
                                    key: const ValueKey(
                                      'news-feed-filter-price',
                                    ),
                                    value:
                                        _feedMaxPrice ??
                                        venueFilterPriceMaximum(posts),
                                    min: 0,
                                    max: venueFilterPriceMaximum(posts),
                                    divisions:
                                        (venueFilterPriceMaximum(posts) / 50)
                                            .round(),
                                    label: _feedMaxPrice == null
                                        ? '${venueFilterPriceMaximum(posts).round()}+'
                                        : _feedMaxPrice!.round().toString(),
                                    onChanged: (value) {
                                      setState(
                                        () => _feedMaxPrice =
                                            value >=
                                                venueFilterPriceMaximum(posts)
                                            ? null
                                            : value,
                                      );
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Sort price'),
                                  _feedDropdown(
                                    identifier: 'price-sort',
                                    value: _feedPriceSort,
                                    values: const [
                                      'Recommended',
                                      'Lowest to highest',
                                      'Highest to lowest',
                                    ],
                                    onChanged: (value) {
                                      setState(() => _feedPriceSort = value);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: filterPanelFooterPadding,
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  key: const ValueKey('news-feed-filter-apply'),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  style: filterPanelApplyButtonStyle(context),
                                  child: AppText(
                                    'Show ${_filteredPosts(posts).length} venues',
                                    localize: true,
                                  ),
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
            },
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          ),
    );
  }

  int get _activeFeedFilterCount =>
      (_feedArea == 'All areas' ? 0 : 1) +
      (_feedSport == _categoryAllLabel ? 0 : 1) +
      (_feedCourtType == _facilityAllLabel ? 0 : 1) +
      (_feedAvailability == 'Any' ? 0 : 1) +
      (_feedPriceSort == 'Recommended' ? 0 : 1) +
      (_feedMaxPrice == null ? 0 : 1) +
      (_feedMinimumRating == null ? 0 : 1) +
      _feedAmenities.length +
      (_userPosition == null ? 0 : 1);

  List<String> _feedOptions(
    List<Map<String, dynamic>> posts,
    String Function(Map<String, dynamic>) selector,
    String allLabel,
  ) {
    final values =
        posts
            .map(selector)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [allLabel, ...values];
  }

  List<String> _categoryOptions(List<Map<String, dynamic>> posts) {
    final values =
        posts
            .expand(venueFilterCategories)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [_categoryAllLabel, ...values];
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return [value.trim()];
      }
      return [value.trim()];
    }
    return const [];
  }

  Widget _filterLabel(String text) => Padding(
    key: ValueKey('news-feed-filter-label-${text.toLowerCase()}'),
    padding: const EdgeInsets.only(bottom: 6),
    child: AppText(text.toUpperCase(), style: filterPanelSectionLabelStyle),
  );

  Widget _feedDropdown({
    required String identifier,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('news-feed-filter-$identifier'),
    initialValue: values.contains(value) ? value : values.first,
    items: values
        .map((item) => DropdownMenuItem(value: item, child: AppText(item)))
        .toList(),
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
    ),
  );

  Widget _subtitleInfoButton({
    required String key,
    required String title,
    required String subtitle,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: appLanguageText('About $title', 'About $title'),
    visualDensity: VisualDensity.compact,
    alignment: Alignment.bottomCenter,
    padding: AppSpacing.buttonPadding,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    icon: Icon(Icons.info_outline_rounded, size: 18, color: _venueMuted),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(title),
        content: AppText(subtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const AppText('Got it', localize: true),
          ),
        ],
      ),
    ),
  );

  Widget _courtMapHeaderControl() => IconButton(
    key: const ValueKey('news-feed-toggle-court-map'),
    tooltip: _courtMapExpanded
        ? 'Hide ${widget.venueNoun == 'courts' ? 'court' : 'venue'} map'
        : 'Show ${widget.venueNoun} on map',
    onPressed: () => setState(() => _courtMapExpanded = !_courtMapExpanded),
    icon: AnimatedRotation(
      turns: _courtMapExpanded ? .5 : 0,
      duration: const Duration(milliseconds: 180),
      child: const Icon(Icons.map_outlined),
    ),
    style: IconButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: _venueSurface,
      foregroundColor: _courtMapExpanded ? _venuePrimary : _venueText,
    ),
  );

  Widget _courtLocationsMap() => FutureBuilder<List<VenueBusiness>>(
    future: _businesses,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          key: const ValueKey('news-feed-map-loading-skeleton'),
          color: AppColors.surfaceVariant,
          child: const Center(
            child: SkeletonBlock(width: 220, height: 150, borderRadius: 18),
          ),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'We couldn’t load venue locations right now. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _newsMuted, fontSize: 13),
                  localize: true,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const AppText('Try again', localize: true),
                ),
              ],
            ),
          ),
        );
      }

      final courts = (snapshot.data ?? const <VenueBusiness>[])
          .map((business) => business.toViewData())
          .where(
            (business) => _matchesBusinessType(
              business['businessType'] ?? business['business_type'],
              widget.businessType,
            ),
          )
          .toList();
      final pinnedCourts = <({Map<String, dynamic> business, LatLng point})>[];
      final courtsWithoutPin = <Map<String, dynamic>>[];
      for (final court in courts) {
        final latitude = _mapCoordinate(court['latitude'] ?? court['lat']);
        final longitude = _mapCoordinate(court['longitude'] ?? court['lng']);
        if (latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          pinnedCourts.add((
            business: court,
            point: LatLng(latitude, longitude),
          ));
        } else {
          courtsWithoutPin.add(court);
        }
      }

      final uniquePoints = pinnedCourts.map((court) => court.point).toSet();
      final center = uniquePoints.isEmpty
          ? _userPosition == null
                ? const LatLng(10.3157, 123.8854)
                : LatLng(_userPosition!.latitude, _userPosition!.longitude)
          : LatLng(
              uniquePoints
                      .map((point) => point.latitude)
                      .reduce((a, b) => a + b) /
                  uniquePoints.length,
              uniquePoints
                      .map((point) => point.longitude)
                      .reduce((a, b) => a + b) /
                  uniquePoints.length,
            );
      final uniquePointsList = uniquePoints.toList();

      return Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _courtMapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: uniquePointsList.length > 1 ? 5 : 13,
              onMapReady: () {
                if (uniquePointsList.length > 1) {
                  _courtMapController.fitCamera(
                    CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(uniquePointsList),
                      padding: const EdgeInsets.all(48),
                    ),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(markers: pinnedCourts.map(_courtMapMarker).toList()),
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                      ),
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: AppText(
                  '${pinnedCourts.length} ${widget.venueNoun} on map'
                  '${courtsWithoutPin.isEmpty ? '' : ' · ${courtsWithoutPin.length} need pins'}',
                  style: TextStyle(
                    color: _newsInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  double? _mapCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Marker _courtMapMarker(
    ({Map<String, dynamic> business, LatLng point}) court,
  ) => Marker(
    point: court.point,
    width: 40,
    height: 42,
    child: GestureDetector(
      onTap: () => _openCourtMapLocation(court.business, court.point),
      child: Icon(Icons.location_on, color: _newsAccentForeground, size: 34),
    ),
  );

  Future<void> _openCourtMapLocation(
    Map<String, dynamic> business,
    LatLng point,
  ) async {
    final name = '${business['name'] ?? business['businessName'] ?? 'Venue'}'
        .trim();
    final category = '${business['category'] ?? business['businessType'] ?? ''}'
        .trim();
    final address = '${business['address'] ?? ''}'.trim();
    final price = _priceLabel(business);
    final rating = _number(business['averageRating']);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              name.isEmpty ? 'Venue' : name,
              style: AppTypography.sectionTitle.copyWith(color: _newsInk),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 6),
              AppText(
                category,
                style: TextStyle(
                  color: _venueMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: _newsAccentForeground,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AppText(
                      address,
                      style: TextStyle(
                        color: _venueText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (price != 'Price not listed')
                  _mapDetailChip(Icons.sell_outlined, price),
                if (rating > 0)
                  _mapDetailChip(
                    Icons.star_rounded,
                    '${rating.toStringAsFixed(1)} rating',
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _launchCourtMapDirections(name, point);
                },
                icon: const Icon(Icons.directions_outlined),
                label: const AppText('Get directions', localize: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapDetailChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _newsAccentForeground),
        const SizedBox(width: 6),
        AppText(
          label,
          style: TextStyle(
            color: _venueText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Future<void> _launchCourtMapDirections(String name, LatLng point) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${point.latitude},${point.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            'Could not open map directions for $name.',
            localize: true,
          ),
        ),
      );
    }
  }

  Future<void> _useMyLocation({required VoidCallback refreshSheet}) async {
    setState(() => _locationLoading = true);
    refreshSheet();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Location services are off. Turn them on to find nearby ${widget.venueNoun}.',
          actionLabel: 'Location settings',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage(
          'Location permission was denied. Allow location access to sort ${widget.venueNoun} by distance.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is blocked. Enable it in app settings to find nearby ${widget.venueNoun}.',
          actionLabel: 'App settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _userPosition = position);
      refreshSheet();
      _showLocationMessage(
        '${widget.venueNoun[0].toUpperCase()}${widget.venueNoun.substring(1)} are now ordered nearest to your location.',
      );
    } on Exception catch (error) {
      _showLocationMessage('Could not get your location: $error');
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
        refreshSheet();
      }
    }
  }

  void _showLocationMessage(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: () async {
                  final opened = await onAction();
                  if (!opened && mounted) {
                    _showLocationMessage('Could not open $actionLabel.');
                  }
                },
              ),
      ),
    );
  }

  Widget _mainSearchBar() => Container(
    key: const ValueKey('news-feed-search-container'),
    color: _venueCanvas,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
    child: TextField(
      key: const ValueKey('news-feed-search'),
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: _venueText, fontSize: 14),
      decoration: InputDecoration(
        hintText: appLanguageText(widget.searchHint, widget.searchHint),
        hintStyle: TextStyle(color: _venueMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('news-feed-search-clear'),
                tooltip: appLanguageText('Clear search', 'Clear search'),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        filled: true,
        fillColor: _venueSurface,
        isDense: true,
        prefixIconColor: _venueMuted,
        suffixIconColor: _venueMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _venueOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _venueOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _venuePrimary, width: 1.4),
        ),
      ),
    ),
  );

  Widget _sportTypeFilterBar(List<String> sports) => Container(
    key: const ValueKey('news-feed-sport-filter-bar'),
    color: _venueCanvas,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          widget.categoryFilterLabel.toUpperCase(),
          style: TextStyle(
            color: _venueMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          key: const ValueKey('news-feed-sport-filter-scroll'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < sports.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                ChoiceChip(
                  key: ValueKey('news-feed-filter-sport-${sports[index]}'),
                  label: AppText(sports[index]),
                  selected: _feedSport == sports[index],
                  onSelected: (_) => setState(() {
                    _feedSport = sports[index];
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  selectedColor: _venuePrimary,
                  backgroundColor: _venueSurface,
                  side: BorderSide(
                    color: _feedSport == sports[index]
                        ? _venuePrimary
                        : _venueOutline,
                  ),
                  labelStyle: TextStyle(
                    color: _feedSport == sports[index]
                        ? Colors.white
                        : _venueMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _feedContent(List<Map<String, dynamic>> posts) {
    final popular = [...posts]
      ..sort((a, b) {
        final byHearts = _postHeartCount(b).compareTo(_postHeartCount(a));
        return byHearts != 0
            ? byHearts
            : '${a['businessName']}'.compareTo('${b['businessName']}');
      });
    final highestRated =
        posts.where((post) => _number(post['reviewCount']) > 0).toList()
          ..sort((a, b) {
            final byRating = _number(b['averageRating'])
                .compareTo(_number(a['averageRating']));
            return byRating != 0
                ? byRating
                : '${a['businessName']}'.compareTo('${b['businessName']}');
          });
    final featured = popular.take(1).toList();
    final rated = highestRated.take(6).toList();

    return ListView(
      key: const ValueKey('news-feed-content-list'),
      controller: _feedScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SizedBox(height: 18),
        if (_isEventFeed || _isFitnessFeed) ...[
          _bookingTypeHomeIntro(),
          const SizedBox(height: 20),
        ],
        _sectionHeader(
          _popularSectionTitle,
          _popularSectionDescription,
          popular,
          featured: true,
        ),
        if (featured.isEmpty)
          Padding(
            key: ValueKey('news-feed-most-popular-empty'),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AppText(
              'No popular venues available yet.',
              style: TextStyle(
                color: _venueMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              localize: true,
            ),
          )
        else
          _featuredVenueCard(featured.first, section: 'popular'),
        if (!_isSportsFeed) ...[
          const SizedBox(height: 20),
          _sectionHeader(
            widget.highestRatedSectionTitle,
            'Highest average review rating',
            highestRated,
            featured: true,
          ),
          if (rated.isEmpty)
            Padding(
              key: const ValueKey('news-feed-highest-rated-empty'),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: AppText(
                'No highest-rated venues available yet.',
                style: TextStyle(
                  color: _venueMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            )
          else
            _horizontalVenues(
              rated,
              identifier: widget.highestRatedSectionTitle
                  .toLowerCase()
                  .replaceAll(' ', '-'),
              featured: true,
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: AppText(
                      widget.allVenuesHeading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionTitle.copyWith(
                        color: _venueText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AppText(
                    '(${posts.length} venues)',
                    style: TextStyle(
                      color: _venueMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    localize: true,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('news-feed-all-venues-sort'),
              tooltip: 'Sort venues',
              initialValue: _feedPriceSort,
              onSelected: (value) => setState(() => _feedPriceSort = value),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'Recommended',
                  child: AppText('Recommended'),
                ),
                PopupMenuItem(
                  value: 'Lowest to highest',
                  child: AppText('Price: low to high'),
                ),
                PopupMenuItem(
                  value: 'Highest to lowest',
                  child: AppText('Price: high to low'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 17, color: _venueMuted),
                    const SizedBox(width: 3),
                    AppText(
                      _feedPriceSort == 'Lowest to highest'
                          ? 'Price: low to high'
                          : _feedPriceSort == 'Highest to lowest'
                          ? 'Price: high to low'
                          : 'Recommended',
                      style: TextStyle(
                        color: _venueMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: _venueMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final post in posts) ...[
          _listedVenueCard(post),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String get _popularSectionTitle =>
      switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.sports => 'Most popular',
        BusinessType.event => 'Popular event venues',
        BusinessType.fitness => 'Popular fitness spaces',
        BusinessType.unknown => 'Popular venues',
      };

  String get _popularSectionDescription =>
      switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.sports => 'Most hearts from users',
        BusinessType.event => 'Spaces with the most hearts from users',
        BusinessType.fitness => 'Studios and wellness spaces users love',
        BusinessType.unknown => 'Venues users love',
      };

  Widget _bookingTypeHomeIntro() {
    final isEvent = _isEventFeed;
    final accent = isEvent ? const Color(0xFFFFC56E) : const Color(0xFF61D8B0);
    final icon = isEvent
        ? Icons.celebration_rounded
        : Icons.self_improvement_rounded;
    final title = isEvent
        ? 'Find a space for your next event'
        : 'Find a space for your next workout';
    final description = isEvent
        ? 'Explore event venues for celebrations, gatherings, and special occasions.'
        : 'Explore fitness studios and wellness spaces for your routine.';
    final typeKey = isEvent ? 'event' : 'fitness';

    return Container(
      key: ValueKey('news-feed-booking-type-intro-$typeKey'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: .18), _venueSurface],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: TextStyle(
                    color: _venueText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  description,
                  style: TextStyle(
                    color: _venueMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFilterRow() => SingleChildScrollView(
    key: const ValueKey('news-feed-quick-filters'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _quickFilter(
          key: 'news-feed-quick-filter-available',
          label: 'Available today',
          icon: Icons.schedule_rounded,
          selected: _feedAvailability == 'Available today',
          onTap: () => setState(
            () => _feedAvailability = _feedAvailability == 'Available today'
                ? 'Any'
                : 'Available today',
          ),
        ),
        const SizedBox(width: 8),
        _quickFilter(
          key: 'news-feed-quick-filter-rating',
          label: '4.5+',
          icon: Icons.star_rounded,
          selected: _feedMinimumRating != null,
          onTap: () => setState(
            () => _feedMinimumRating = _feedMinimumRating == null ? 4.5 : null,
          ),
        ),
        const SizedBox(width: 8),
        _quickFilter(
          key: 'news-feed-quick-filter-indoor',
          label: 'Indoor / AC',
          icon: Icons.ac_unit_rounded,
          selected: _feedAmenities.contains('Indoor / AC'),
          onTap: () => setState(() {
            if (!_feedAmenities.add('Indoor / AC')) {
              _feedAmenities.remove('Indoor / AC');
            }
          }),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  Widget _quickFilter({
    required String key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => Material(
    color: selected ? _venuePrimary : _venueSurface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      key: ValueKey(key),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _venuePrimary : _venueOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : _venueMuted),
            const SizedBox(width: 6),
            AppText(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _venueMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _featuredVenueCard(
    Map<String, dynamic> post, {
    required String section,
  }) {
    final businessValue = post['business'];
    final business = businessValue is Map
        ? Map<String, dynamic>.from(businessValue)
        : const <String, dynamic>{};
    final images = _imageListValue([
      post['imageUrls'],
      post['image_urls'],
      post['imageUrl'],
      post['image_url'],
      post['businessImageUrl'],
      post['business_image_url'],
      post['images'],
      business['imageUrls'],
      business['image_urls'],
      business['imageUrl'],
      business['image_url'],
      business['images'],
    ]);
    final name = _stringValue([
      post['businessName'],
      post['name'],
      business['name'],
      business['businessName'],
      'Venue',
    ]);
    final address = _stringValue([
      post['address'],
      post['location'],
      business['address'],
      business['location'],
    ]);
    final category = _stringValue([
      post['category'],
      post['sportTypes'],
      post['eventTypes'],
      post['facilityType'],
      business['category'],
      business['sportTypes'],
      business['eventTypes'],
      business['facilityType'],
    ]);
    final identifier = _venueIdentifier(post);
    final idPrefix = section == 'popular' ? 'featured' : section;
    final distance = _distanceLabel(post);
    final rating = _number(post['averageRating']);
    final reviewCount = _number(post['reviewCount']).toInt();
    final price = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final isSaved = _savedKeys.contains(_postSaveKey(post));
    final availableToday = _isVenueAvailableToday(post);
    final slots = _venueAvailableSlotLabels(post, business);
    final availableLabel = slots.isNotEmpty
        ? 'Available · ${slots.first}'
        : availableToday
        ? 'Available today'
        : '';
    final verified =
        post['isVerified'] == true ||
        post['verified'] == true ||
        business['isVerified'] == true ||
        business['verified'] == true;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final imageIndex = (_featuredImageIndexes[identifier] ?? 0).clamp(
      0,
      images.isEmpty ? 0 : images.length - 1,
    );
    final cardKey = section == 'popular'
        ? 'news-feed-most-popular-card-$identifier'
        : 'news-feed-$section-card-$identifier';
    final bookingLabel = _isSportsFeed
        ? 'Instant Book Court'
        : _isEventFeed
        ? 'Book this venue'
        : 'Book a session';

    return Semantics(
      key: ValueKey('news-feed-mini-$identifier'),
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. ${section == 'popular' ? 'Popular' : 'Highest rated'} venue. Open venue details.',
      child: Material(
        key: ValueKey(cardKey),
        color: _venueCard,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unavailable ? null : () => _openBookingType(post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 205,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    images.isEmpty
                        ? _miniImageFallback()
                        : _miniImage(images[imageIndex]),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x7208111F),
                            Color(0x0008111F),
                            Color(0x0008111F),
                            Color(0x6608111F),
                          ],
                          stops: [0, .26, .68, 1],
                        ),
                      ),
                    ),
                    if (unavailable) const ColoredBox(color: Color(0x55000000)),
                    if (category.isNotEmpty)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _venueImageTag(category),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _featuredImageAction(
                            key: 'news-feed-$idPrefix-heart-$identifier',
                            legacyKey: section == 'popular'
                                ? 'news-feed-mini-heart-$identifier'
                                : null,
                            icon: hearted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            tooltip: hearted ? 'Remove heart' : 'Heart venue',
                            color: hearted
                                ? const Color(0xFFFF6B82)
                                : _venueText,
                            onPressed: () => _toggleHeart(post),
                          ),
                          const SizedBox(width: 6),
                          _featuredImageAction(
                            key: 'news-feed-$idPrefix-save-$identifier',
                            legacyKey: section == 'popular'
                                ? 'news-feed-featured-save-$identifier'
                                : null,
                            icon: isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            tooltip: isSaved
                                ? 'Remove saved venue'
                                : 'Save venue',
                            color: isSaved ? _venuePrimary : _venueText,
                            onPressed: () => _toggleSaved(post),
                          ),
                        ],
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var index = 0;
                              index < images.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 5),
                              GestureDetector(
                                key: ValueKey(
                                  'news-feed-$idPrefix-image-dot-$identifier-$index',
                                ),
                                onTap: () => setState(
                                  () =>
                                      _featuredImageIndexes[identifier] = index,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: index == imageIndex ? 15 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: index == imageIndex
                                        ? _venuePrimary
                                        : Colors.white70,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _venueSurface,
                            border: Border.all(color: _venuePrimary),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: AppText(
                            initials,
                            style: TextStyle(
                              color: _venuePrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: AppText(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueText,
                                    fontSize: 15,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF42B8E9),
                                  size: 15,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (price != 'Price not listed') ...[
                          const SizedBox(width: 8),
                          AppText(
                            price,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _venueMint,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (address.isNotEmpty || distance != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: _venueMuted,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: AppText(
                              [
                                if (address.isNotEmpty) address,
                                ?distance,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: ValueKey(
                              'news-feed-$idPrefix-reviews-$identifier',
                            ),
                            onTap: int.tryParse('${post['businessId']}') == null
                                ? null
                                : () => _showReviews(
                                    post,
                                    int.parse('${post['businessId']}'),
                                  ),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _venueSurface,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFCB66),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 3),
                                  AppText(
                                    rating == 0
                                        ? 'New'
                                        : rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: _venueText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: AppText(
                                      '($reviewCount reviews)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _venueMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (unavailable)
                          Flexible(
                            child: _featuredStatusPill(
                              'Unavailable',
                              const Color(0xFFD14343),
                            ),
                          )
                        else if (availableLabel.isNotEmpty)
                          Flexible(
                            child: _featuredStatusPill(
                              availableLabel,
                              _venueMint,
                            ),
                          ),
                        const SizedBox(width: 6),
                        AppText(
                          '$heartCount',
                          key: ValueKey(
                            section == 'popular'
                                ? 'news-feed-mini-heart-count-$identifier'
                                : 'news-feed-$idPrefix-heart-count-$identifier',
                          ),
                          style: TextStyle(
                            color: _venueMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton.icon(
                        key: ValueKey('news-feed-$idPrefix-book-$identifier'),
                        onPressed: unavailable
                            ? null
                            : () => _openBookingType(post),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: AppText(
                          unavailable ? 'Currently unavailable' : bookingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _venuePrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _venueOutline,
                          disabledForegroundColor: _venueMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredImageAction({
    required String key,
    String? legacyKey,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) => IconButton(
    key: ValueKey(legacyKey ?? key),
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      backgroundColor: _venueCanvas.withValues(alpha: .92),
      foregroundColor: color,
      shape: const CircleBorder(),
    ),
    icon: Icon(icon, size: 18),
  );

  Widget _featuredStatusPill(String label, Color color) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: AppText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _listedVenueCard(Map<String, dynamic> post) {
    if (_isSportsFeed || _isEventFeed || _isFitnessFeed) {
      return _referenceVenueCard(post);
    }

    final businessValue = post['business'];
    final business = businessValue is Map
        ? Map<String, dynamic>.from(businessValue)
        : const <String, dynamic>{};
    final name = _stringValue([
      post['businessName'],
      post['name'],
      business['name'],
      business['businessName'],
      'Venue',
    ]);
    final address = _stringValue([
      post['address'],
      post['location'],
      business['address'],
      business['location'],
    ]);
    final category = _stringValue([
      post['category'],
      post['facilityType'],
      business['category'],
      business['facilityType'],
    ]);
    final image = _miniVenueImageUrl(post, business);
    final businessId = int.tryParse('${post['businessId']}');
    final rating = _number(post['averageRating']);
    final reviewCount = _number(post['reviewCount']).toInt();
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final price = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final saveKey = _postSaveKey(post);
    final isSaved = _savedKeys.contains(saveKey);

    return Semantics(
      key: ValueKey('news-feed-mini-${_venueIdentifier(post)}'),
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. Open venue details.',
      child: Material(
        key: ValueKey('news-feed-card-${_venueIdentifier(post)}'),
        color: _venueCard,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unavailable ? null : () => _openBookingType(post),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    key: ValueKey('news-feed-image-${_venueIdentifier(post)}'),
                    width: 96,
                    height: 102,
                    child: image.isEmpty
                        ? _miniImageFallback()
                        : _miniImage(image),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _venueText,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey(
                              'news-feed-save-${_venueIdentifier(post)}',
                            ),
                            tooltip: isSaved
                                ? 'Remove saved venue'
                                : 'Save venue',
                            onPressed: () => _toggleSaved(post),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: isSaved ? _venuePrimary : _venueMuted,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      if (category.isNotEmpty || address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (category.isNotEmpty)
                              Flexible(
                                child: AppText(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (category.isNotEmpty && address.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 3,
                                  color: _venueMuted,
                                ),
                              ),
                            if (address.isNotEmpty) ...[
                              Icon(
                                Icons.location_on_outlined,
                                color: _venueMuted,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Expanded(
                              child: AppText(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _venueMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              key: ValueKey(
                                'news-feed-reviews-${_venueIdentifier(post)}',
                              ),
                              onTap: businessId == null
                                  ? null
                                  : () => _showReviews(post, businessId),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFCB66),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: AppText(
                                        '${rating == 0 ? 'New' : rating.toStringAsFixed(1)} · $reviewCount Reviews',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _venueText,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            key: ValueKey(
                              'news-feed-heart-${_venueIdentifier(post)}',
                            ),
                            tooltip: hearted ? 'Remove heart' : 'Heart venue',
                            onPressed: () => _toggleHeart(post),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              hearted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: hearted
                                  ? const Color(0xFFFF6B82)
                                  : _venueMuted,
                              size: 15,
                            ),
                          ),
                          AppText(
                            '$heartCount',
                            key: ValueKey(
                              'news-feed-heart-count-${_venueIdentifier(post)}',
                            ),
                            style: TextStyle(
                              color: _venueMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (price != 'Price not listed') ...[
                        const SizedBox(height: 3),
                        AppText(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _venueMint,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (unavailable) ...[
                        const SizedBox(height: 4),
                        const AppText(
                          'UNAVAILABLE · Booking disabled',
                          style: TextStyle(
                            color: Color(0xFFFF7B7B),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
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
        ),
      ),
    );
  }

  Widget _referenceVenueCard(Map<String, dynamic> post) {
    final businessValue = post['business'];
    final business = businessValue is Map
        ? Map<String, dynamic>.from(businessValue)
        : const <String, dynamic>{};
    final name = _stringValue([
      post['businessName'],
      post['name'],
      business['name'],
      business['businessName'],
      'Venue',
    ]);
    final address = _stringValue([
      post['address'],
      post['location'],
      business['address'],
      business['location'],
    ]);
    final category = _stringValue([
      post['category'],
      business['category'],
      post['sportTypes'],
      business['sportTypes'],
    ]);
    final facility = _stringValue([
      post['facilityType'],
      business['facilityType'],
    ]);
    final image = _miniVenueImageUrl(post, business);
    final businessId = int.tryParse('${post['businessId']}');
    final identifier = _venueIdentifier(post);
    final rating = _number(post['averageRating']);
    final reviewCount = _number(post['reviewCount']).toInt();
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final price = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final isSaved = _savedKeys.contains(_postSaveKey(post));
    final distance = _distanceLabel(post);
    final availableToday = _isVenueAvailableToday(post);
    final slots = _venueAvailableSlotLabels(post, business);
    final verified =
        post['isVerified'] == true ||
        post['verified'] == true ||
        business['isVerified'] == true ||
        business['verified'] == true;
    final location = [if (address.isNotEmpty) address, ?distance].join(' · ');

    return Semantics(
      key: ValueKey('news-feed-mini-$identifier'),
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. Open venue details.',
      child: Material(
        key: ValueKey('news-feed-card-$identifier'),
        color: _venueCard,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unavailable ? null : () => _openBookingType(post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: ValueKey('news-feed-image-$identifier'),
                height: 174,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isEmpty ? _miniImageFallback() : _miniImage(image),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xA908111F),
                            Color(0x0008111F),
                            Color(0x0008111F),
                            Color(0xB808111F),
                          ],
                          stops: [0, .35, .58, 1],
                        ),
                      ),
                    ),
                    if (category.isNotEmpty || facility.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            if (category.isNotEmpty) _venueImageTag(category),
                            if (facility.isNotEmpty)
                              _venueImageTag(
                                facility.toLowerCase().contains('indoor') ||
                                        facility.toLowerCase().contains('a/c')
                                    ? 'Indoor AC'
                                    : facility,
                              ),
                          ],
                        ),
                      ),
                    if (unavailable || availableToday)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _availabilityImageTag(
                          unavailable ? 'Unavailable' : 'Available Today',
                          unavailable: unavailable,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: AppText(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF42B8E9),
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (price != 'Price not listed') ...[
                          const SizedBox(width: 8),
                          AppText(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _venueMint,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      key: ValueKey('news-feed-reviews-$identifier'),
                      onTap: businessId == null
                          ? null
                          : () => _showReviews(post, businessId),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFCB66),
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          AppText(
                            rating == 0 ? 'New' : rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: _venueText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              '$reviewCount Reviews',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: _venueMuted,
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: AppText(
                            location.isEmpty ? 'Location not listed' : location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _venueMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _venueActionButton(
                          key: 'news-feed-heart-$identifier',
                          icon: hearted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          selected: hearted,
                          tooltip: hearted ? 'Remove heart' : 'Heart venue',
                          onPressed: () => _toggleHeart(post),
                        ),
                        const SizedBox(width: 4),
                        AppText(
                          '$heartCount',
                          key: ValueKey('news-feed-heart-count-$identifier'),
                          style: TextStyle(
                            color: _venueMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _venueActionButton(
                          key: 'news-feed-save-$identifier',
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          selected: isSaved,
                          selectedColor: _venuePrimary,
                          tooltip: isSaved
                              ? 'Remove saved venue'
                              : 'Save venue',
                          onPressed: () => _toggleSaved(post),
                        ),
                      ],
                    ),
                    if (unavailable) ...[
                      const SizedBox(height: 8),
                      const AppText(
                        'UNAVAILABLE · Booking disabled',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
                      ),
                    ],
                    if (slots.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: _venueMint,
                          ),
                          const SizedBox(width: 5),
                          AppText(
                            'Slots:',
                            style: TextStyle(
                              color: _venueMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              key: ValueKey(
                                'news-feed-available-slots-$identifier',
                              ),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (
                                    var index = 0;
                                    index < slots.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const SizedBox(width: 6),
                                    _venueSlotChip(slots[index]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _venueImageTag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xD908111F),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _availabilityImageTag(String label, {required bool unavailable}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE608111F),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 7,
                color: unavailable ? const Color(0xFFFF7777) : _venueMint,
              ),
              const SizedBox(width: 5),
              AppText(
                label,
                style: TextStyle(
                  color: unavailable ? const Color(0xFFFFAAAA) : _venueMint,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _venueActionButton({
    required String key,
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onPressed,
    Color? selectedColor,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      backgroundColor: _venueSurface,
      side: BorderSide(color: _venueOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    icon: Icon(
      icon,
      color: selected ? selectedColor ?? const Color(0xFFFF6B82) : _venueMuted,
      size: 17,
    ),
  );

  Widget _venueSlotChip(String label) => DecoratedBox(
    key: ValueKey('news-feed-available-slot-$label'),
    decoration: BoxDecoration(
      color: _venueSurface,
      border: Border.all(color: _venueOutline),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        label,
        style: TextStyle(
          color: _venueText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  List<String> _venueAvailableSlotLabels(
    Map<String, dynamic> post,
    Map<String, dynamic> business,
  ) {
    final rawSlots =
        post['availableSlots'] ??
        post['available_slots'] ??
        post['timeSlots'] ??
        post['time_slots'] ??
        business['availableSlots'] ??
        business['available_slots'] ??
        business['timeSlots'] ??
        business['time_slots'];
    if (rawSlots is! List) return const [];
    return rawSlots
        .map((slot) {
          if (slot is String) return slot.trim();
          if (slot is! Map) return '';
          return _stringValue([
            slot['label'],
            slot['time'],
            slot['startTime'],
            slot['start_time'],
            slot['start'],
          ]);
        })
        .where((slot) => slot.isNotEmpty)
        .take(5)
        .toList();
  }

  Widget _venueBadge(String label, Color color) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: AppText(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    ),
  );

  Widget _sectionHeader(
    String title,
    String subtitle,
    List<Map<String, dynamic>> sectionPosts, {
    bool featured = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AppText(
                    title,
                    style: AppTypography.sectionTitle.copyWith(
                      color: _venueText,
                    ),
                  ),
                ),
                if (featured) ...[
                  const SizedBox(width: 6),
                  _venueBadge('Featured', _venuePrimary),
                ],
                _subtitleInfoButton(
                  key:
                      'news-feed-section-info-${title.toLowerCase().replaceAll(' ', '-')}',
                  title: title,
                  subtitle: subtitle,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
      TextButton.icon(
        key: ValueKey(
          'news-feed-see-all-${title.toLowerCase().replaceAll(' ', '-')}',
        ),
        onPressed: () => _openAllVenues(title, sectionPosts),
        icon: const Icon(Icons.chevron_right_rounded, size: 17),
        label: AppText('See all (${sectionPosts.length})', localize: true),
        style: TextButton.styleFrom(
          foregroundColor: _venuePrimary,
          padding: AppSpacing.buttonPadding,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  void _openAllVenues(String title, List<Map<String, dynamic>> sectionPosts) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => AllVenuesPage(
          title: title,
          posts: sectionPosts,
          cardBuilder: _postCard,
          initialUserPosition: _userPosition,
          categoryFilterLabel: widget.categoryFilterLabel,
          categoryAllLabel: _categoryAllLabel,
          facilityFilterLabel: widget.facilityFilterLabel,
          popularHeading: widget.businessType == 'Sports'
              ? 'Courts with the most hearts'
              : '${widget.pageTitle} venues with the most hearts',
          ratedHeading: widget.businessType == 'Sports'
              ? 'Courts with the highest ratings'
              : '${widget.pageTitle} venues with the highest ratings',
          searchHint: widget.businessType.toLowerCase() == 'sports'
              ? 'Search venues, sports, or areas...'
              : 'Search venues, ${widget.categoryNoun}, or areas...',
          collectionDescription: widget.businessType == 'Sports'
              ? 'Browse every venue in this collection.'
              : 'Browse all ${widget.venueNoun} in this collection.',
          priceFilterLabel: widget.businessType.trim().toLowerCase() == 'event'
              ? 'Price (\u{20B1} / event)'
              : 'Price (\u{20B1} / hour)',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
      ),
    );
  }

  Widget _horizontalVenues(
    List<Map<String, dynamic>> posts, {
    required String identifier,
    bool featured = false,
  }) => Padding(
    key: ValueKey('news-feed-$identifier-section'),
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: featured
          ? 406
          : MediaQuery.sizeOf(context).width >= 600
          ? 222
          : 196,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = featured
              ? constraints.maxWidth
              : constraints.maxWidth >= 600
              ? 280.0
              : (constraints.maxWidth - 6) / 2;
          return ListView.separated(
            key: ValueKey('news-feed-$identifier-scroll'),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, index) => SizedBox(
              key: ValueKey(
                'news-feed-$identifier-${featured ? 'slide' : 'card'}-${_venueIdentifier(posts[index])}',
              ),
              width: cardWidth,
              child: featured
                  ? _featuredVenueCard(posts[index], section: identifier)
                  : _miniVenueCard(posts[index]),
            ),
          );
        },
      ),
    ),
  );

  String _venueIdentifier(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    if (businessId != null && businessId > 0) return 'business-$businessId';
    final name = '${post['businessName'] ?? ''}'
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return name.isEmpty ? 'unknown' : name;
  }

  String _postHeartKey(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    return businessId != null && businessId > 0 ? '$businessId' : '';
  }

  int _postHeartCount(Map<String, dynamic> post) =>
      _heartCounts[_postHeartKey(post)] ?? _number(post['heartCount']).toInt();

  bool _isHearted(Map<String, dynamic> post) {
    final key = _postHeartKey(post);
    return key.isNotEmpty
        ? _heartedVenueKeys.contains(key)
        : post['heartedByMe'] == true;
  }

  void _applyHeartState(Map<String, dynamic> post, bool hearted, int count) {
    final key = _postHeartKey(post);
    if (key.isEmpty) return;
    _heartCounts[key] = count;
    if (hearted) {
      _heartedVenueKeys.add(key);
    } else {
      _heartedVenueKeys.remove(key);
    }
    post['heartCount'] = count;
    post['heartedByMe'] = hearted;
  }

  Future<void> _toggleHeart(Map<String, dynamic> post) async {
    if (!await requireCustomerLogin(context)) return;
    final businessId = int.tryParse('${post['businessId']}');
    if (businessId == null || businessId <= 0) return;
    final wasHearted = _isHearted(post);
    final key = '$businessId';
    if (!_heartUpdatesInProgress.add(key)) return;
    final previousCount = _postHeartCount(post);
    final nextHearted = !wasHearted;
    final nextCount = (previousCount + (nextHearted ? 1 : -1)).clamp(
      0,
      0x7fffffff,
    );
    setState(() => _applyHeartState(post, nextHearted, nextCount));
    try {
      final token = (await AppSessionService.instance.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Your session has expired. Please log in again.',
          401,
        );
      }
      final result = await _api.venues.setBusinessHearted(
        token: token,
        businessId: businessId,
        hearted: nextHearted,
      );
      if (!mounted) return;
      setState(
        () => _applyHeartState(post, result.heartedByMe, result.heartCount),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _applyHeartState(post, wasHearted, previousCount));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText('Could not update heart: $error', localize: true),
        ),
      );
    } finally {
      _heartUpdatesInProgress.remove(key);
    }
  }

  Widget _miniVenueCard(Map<String, dynamic> post) {
    final businessValue = post['business'];
    final business = businessValue is Map
        ? Map<String, dynamic>.from(businessValue)
        : const <String, dynamic>{};
    final image = _miniVenueImageUrl(post, business);
    final name = '${post['businessName'] ?? 'Venue'}';
    final category = '${post['category'] ?? ''}';
    final rating = _number(post['averageRating']);
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final priceLabel = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final availability = '${post['availability'] ?? ''}'.toLowerCase();
    final isOpen =
        availability.contains('open') || availability.contains('available');
    return Semantics(
      key: ValueKey('news-feed-mini-${_venueIdentifier(post)}'),
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. Open venue details.',
      child: AbsorbPointer(
        absorbing: unavailable,
        child: SizedBox(
          width: double.infinity,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: unavailable ? null : () => _openBookingType(post),
            child: Ink(
              decoration: BoxDecoration(
                color: _venueCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _venueOutline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).width >= 600
                          ? 104
                          : 94,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          image.isEmpty
                              ? _miniImageFallback()
                              : _miniImage(image),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 14,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppGradients.imageBottomFade,
                                ),
                              ),
                            ),
                          ),
                          if (unavailable)
                            const ColoredBox(color: Color(0x55000000)),
                          if (unavailable)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: _miniBadge(
                                'Unavailable',
                                const Color(0xFFD32F2F),
                              ),
                            )
                          else if (isOpen)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: _miniBadge(
                                'Available',
                                const Color(0xDD15803D),
                              ),
                            ),
                          if (category.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: _miniBadge(
                                category,
                                const Color(0xCC101B33),
                              ),
                            ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: _venueSurface.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(18),
                              child: GestureDetector(
                                key: ValueKey(
                                  'news-feed-mini-heart-${_venueIdentifier(post)}',
                                ),
                                onTap: () => _toggleHeart(post),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _venueSurface.withValues(alpha: .95),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hearted
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 14,
                                        color: hearted
                                            ? Colors.red
                                            : _venueMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      AppText(
                                        '$heartCount',
                                        key: ValueKey(
                                          'news-feed-mini-heart-count-${_venueIdentifier(post)}',
                                        ),
                                        style: TextStyle(
                                          color: _venueText,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        localize: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _venueText,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            AppRatingStars(rating: rating, size: 12),
                            AppText(
                              rating == 0 ? 'New' : rating.toStringAsFixed(1),
                              localize: true,
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AppText(
                              '(${_number(post['reviewCount']).toInt()})',
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 10,
                              ),
                              localize: true,
                            ),
                          ],
                        ),
                        if (_distanceLabel(post) case final distance?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AppText(
                              distance,
                              localize: true,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (unavailable) ...[
                          const SizedBox(height: 6),
                          const AppText(
                            'UNAVAILABLE · Booking disabled',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                            localize: true,
                          ),
                        ] else if (priceLabel != 'Price not listed') ...[
                          const SizedBox(height: 6),
                          AppText(
                            priceLabel,
                            localize: true,
                            style: TextStyle(
                              color: _venueText,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
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

  String _miniVenueImageUrl(
    Map<String, dynamic> post,
    Map<String, dynamic> business,
  ) {
    final images = _imageListValue([
      post['imageUrl'],
      post['image_url'],
      post['businessImageUrl'],
      post['business_image_url'],
      post['imageUrls'],
      post['image_urls'],
      business['imageUrl'],
      business['image_url'],
      business['imageUrls'],
      business['image_urls'],
      post['images'],
      business['images'],
    ]);
    return images.isEmpty ? '' : images.first;
  }

  Widget _miniBadge(String text, Color background) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: AppText(
        text,
        localize: true,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _miniImage(String value) => Image(
    image:
        _imageProvider(value) ??
        const AssetImage('assets/court/pickle-court.jpg'),
    fit: BoxFit.cover,
    filterQuality: FilterQuality.high,
    errorBuilder: (_, _, _) => _miniImageFallback(),
  );

  Widget _miniImageFallback() => ColoredBox(
    color: _venueSurface,
    child: Center(
      child: Icon(Icons.storefront_rounded, color: _venuePrimary, size: 30),
    ),
  );

  String? _distanceLabel(Map<String, dynamic> post) {
    final position = _userPosition;
    if (position == null) return null;
    final latitude = _mapCoordinate(post['latitude'] ?? post['lat']);
    final longitude = _mapCoordinate(post['longitude'] ?? post['lng']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final distanceKm =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        ) /
        1000;
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  List<Map<String, dynamic>> _filteredPosts(List<Map<String, dynamic>> posts) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = posts.where((post) {
      final address = '${post['address'] ?? ''}'.toLowerCase();
      final matchesArea =
          _feedArea == 'All areas' || address.contains(_feedArea.toLowerCase());
      final categories = venueFilterCategories(post)
          .map((value) => value.toLowerCase())
          .toList();
      final matchesSport =
          _feedSport == _categoryAllLabel ||
          categories.contains(_feedSport.toLowerCase());
      final facility = '${post['facilityType'] ?? ''}';
      final hours = '${post['hours'] ?? post['opening_hours'] ?? ''}';
      final availability = '${post['availability'] ?? ''}';
      final normalizedAvailability = availability.toLowerCase();
      final normalizedHours = hours.toLowerCase();
      final price = venueFilterPrice(post);
      final rawAmenities = '${post['tags'] ?? post['amenities'] ?? ''}'
          .toLowerCase();
      final searchableFacility = '$facility $rawAmenities'.toLowerCase();
      final matchesCourt =
          _feedCourtType == _facilityAllLabel ||
          facility.toLowerCase() == _feedCourtType.toLowerCase();
      final matchesAvailability =
          _feedAvailability == 'Any' ||
          (_feedAvailability == 'Available today'
              ? _isVenueAvailableToday(post)
              : normalizedHours.contains('open 24 hours') ||
                    normalizedAvailability.contains('open 24 hours'));
      final matchesPrice = _feedMaxPrice == null || price <= _feedMaxPrice!;
      final matchesRating =
          _feedMinimumRating == null ||
          _number(post['averageRating']) >= _feedMinimumRating!;
      final hasIndoorFacility =
          searchableFacility.contains('indoor') ||
          searchableFacility.contains('air condition') ||
          searchableFacility.contains('a/c') ||
          RegExp(r'\bac\b').hasMatch(searchableFacility);
      final matchesAmenities = _feedAmenities.every(
        (amenity) => amenity == 'Indoor / AC'
            ? hasIndoorFacility
            : rawAmenities.contains(amenity.toLowerCase()),
      );
      final searchable = [
        post['businessName'],
        post['businessType'],
        post['category'],
        ...venueFilterCategories(post),
        ..._stringList(post['eventTypes']),
        post['title'],
        post['body'],
        post['address'],
        post['facilityType'],
        post['hours'],
        post['availability'],
        post['tags'],
        post['amenities'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return matchesArea &&
          matchesSport &&
          matchesCourt &&
          matchesAvailability &&
          matchesPrice &&
          matchesRating &&
          matchesAmenities &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    if (_feedPriceSort == 'Lowest to highest') {
      filtered.sort((a, b) => _venuePrice(a).compareTo(_venuePrice(b)));
    } else if (_feedPriceSort == 'Highest to lowest') {
      filtered.sort((a, b) => _venuePrice(b).compareTo(_venuePrice(a)));
    } else if (_userPosition case final position?) {
      filtered.sort(
        (a, b) =>
            _distanceFrom(position, a).compareTo(_distanceFrom(position, b)),
      );
    }
    return filtered;
  }

  double _venuePrice(Map<String, dynamic> post) => venueFilterPrice(post);

  bool _isVenueAvailableToday(Map<String, dynamic> post) {
    if (_isMerchantDisabled(post)) return false;
    final availability = '${post['availability'] ?? ''}';
    final availableWeekdays = fitnessAvailableWeekdays(availability);
    if (availableWeekdays != null) {
      return availableWeekdays.contains(DateTime.now().weekday);
    }

    final normalizedAvailability = availability.toLowerCase();
    final normalizedHours = '${post['hours'] ?? post['opening_hours'] ?? ''}'
        .toLowerCase();
    return normalizedAvailability.contains('available') ||
        normalizedAvailability.contains('open') ||
        normalizedHours.contains('open');
  }

  double _distanceFrom(Position position, Map<String, dynamic> post) {
    final latitude = _mapCoordinate(post['latitude'] ?? post['lat']);
    final longitude = _mapCoordinate(post['longitude'] ?? post['lng']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }

  void _onNavigationSelected(int index) async {
    if (index == 0) {
      if (widget.savedOnly) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NewsFeedPage(
              onLogout: widget.onLogout,
              api: _api,
              initialUserPosition: _userPosition,
              businessType: widget.businessType,
              pageTitle: widget.pageTitle,
              savedItemType: widget.savedItemType,
              categoryNoun: widget.categoryNoun,
              venueNoun: widget.venueNoun,
              searchHint: widget.searchHint,
              highestRatedSectionTitle: widget.highestRatedSectionTitle,
              allVenuesHeading: widget.allVenuesHeading,
              categoryFilterLabel: widget.categoryFilterLabel,
              facilityFilterLabel: widget.facilityFilterLabel,
            ),
          ),
        );
      }
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewsFeedPage(
            onLogout: widget.onLogout,
            savedOnly: true,
            api: _api,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
            pageTitle: widget.pageTitle,
            savedItemType: widget.savedItemType,
            categoryNoun: widget.categoryNoun,
            venueNoun: widget.venueNoun,
            searchHint: widget.searchHint,
            highestRatedSectionTitle: widget.highestRatedSectionTitle,
            allVenuesHeading: widget.allVenuesHeading,
            categoryFilterLabel: widget.categoryFilterLabel,
            facilityFilterLabel: widget.facilityFilterLabel,
          ),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesDashboardPage(
            initialUserPosition: _userPosition,
            api: _api,
            businessType: widget.businessType,
          ),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerBookingsPage(
            onLogout: widget.onLogout,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
          ),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDashboardPage(
            onLogout: widget.onLogout,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
          ),
        ),
      );
    } else if (index == 5) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CustomerHomePage(
            onLogout: widget.onLogout,
            api: _api,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
          ),
        ),
      );
    }
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _feedArea = 'All areas';
      _feedSport = _categoryAllLabel;
      _feedCourtType = _facilityAllLabel;
      _feedAvailability = 'Any';
      _feedPriceSort = 'Recommended';
      _feedMaxPrice = null;
      _feedMinimumRating = null;
      _feedAmenities.clear();
      _userPosition = null;
    });
  }

  Widget _message(String text, {Widget? action}) => ListView(
    controller: _feedScrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
    children: [
      Icon(
        Icons.explore_outlined,
        size: 52,
        color: widget.savedOnly ? _newsAccentForeground : _venuePrimary,
      ),
      const SizedBox(height: 6),
      Center(
        child: AppText(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.savedOnly ? _newsInk : _venueText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
      if (action != null) ...[
        const SizedBox(height: 12),
        Center(child: action),
      ],
    ],
  );

  Widget _postCard(Map<String, dynamic> post) {
    final image = post['imageUrl'] as String?;
    final images = _imageListValue([
      post['imageUrls'],
      post['images'],
      post['imageUrl'],
    ]);
    final rating = _number(post['averageRating']);
    final reviews = _number(post['reviewCount']).toInt();
    final ratedUsers = _number(post['ratingUserCount']).toInt();
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}';
    final saveKey = '${businessId ?? businessName}';
    final isSaved = _savedKeys.contains(saveKey);
    final isHearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final type = '${post['businessType'] ?? ''}';
    final categories = venueFilterCategories(post);
    final address = '${post['address'] ?? ''}';
    final body = '${post['body'] ?? ''}';
    final priceLabel = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final secondaryAction = unavailable
        ? OutlinedButton.icon(
            key: ValueKey('news-feed-contact-owner-${_venueIdentifier(post)}'),
            onPressed: () => _contactOwner(post),
            icon: const Icon(Icons.message_outlined, size: 16),
            label: const AppText('Contact owner', localize: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: _newsInk,
              padding: AppSpacing.buttonPadding,
              side: BorderSide(color: AppColors.border),
            ),
          )
        : OutlinedButton.icon(
            key: ValueKey('news-feed-visit-${_venueIdentifier(post)}'),
            onPressed: _visitUrl(post).isEmpty ? null : () => _visitVenue(post),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const AppText('Visit', localize: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: _newsInk,
              padding: AppSpacing.buttonPadding,
              side: BorderSide(color: AppColors.border),
            ),
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Card(
          key: ValueKey('news-feed-card-${_venueIdentifier(post)}'),
          clipBehavior: Clip.antiAlias,
          elevation: AppCardStyles.elevation,
          margin: EdgeInsets.zero,
          shape: AppCardStyles.marketplaceShape,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    key: ValueKey('news-feed-image-${_venueIdentifier(post)}'),
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).width >= 600
                        ? 220
                        : _newsCardImageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        images.isNotEmpty
                            ? _NewsImageCarousel(
                                images: images,
                                imageProvider: _imageProvider,
                              )
                            : image != null && image.isNotEmpty
                            ? _image(image)
                            : _imageFallback(),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 18,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppGradients.imageBottomFade,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey(
                            'news-feed-save-${_venueIdentifier(post)}',
                          ),
                          onPressed: () => _toggleSaved(post),
                          tooltip: appLanguageText(
                            isSaved ? 'Remove from Saved' : 'Save venue',
                            isSaved ? 'Remove from Saved' : 'Save venue',
                            languageCode: Localizations.localeOf(context)
                                .languageCode,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 38,
                            height: 38,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface.withValues(
                              alpha: .94,
                            ),
                            foregroundColor: isSaved
                                ? _newsAccentForeground
                                : _newsInk,
                          ),
                          icon: Icon(
                            isSaved ? savedItemSelectedIcon : savedItemIcon,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 38,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey(
                                  'news-feed-heart-${_venueIdentifier(post)}',
                                ),
                                onPressed: () => _toggleHeart(post),
                                tooltip: appLanguageText(
                                  isHearted ? 'Remove heart' : 'Heart venue',
                                  isHearted ? 'Remove heart' : 'Heart venue',
                                  languageCode: Localizations.localeOf(context)
                                      .languageCode,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 38,
                                  height: 38,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surface.withValues(
                                    alpha: .94,
                                  ),
                                  foregroundColor: isHearted
                                      ? Colors.red
                                      : _newsInk,
                                ),
                                icon: Icon(
                                  isHearted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 3),
                              DecoratedBox(
                                key: ValueKey(
                                  'news-feed-heart-count-${_venueIdentifier(post)}',
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: .94,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  child: AppText(
                                    '$heartCount',
                                    style: TextStyle(
                                      color: _newsMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    localize: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _newsInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _priceTag(priceLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: address.isEmpty
                              ? const SizedBox.shrink()
                              : Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: _newsMuted,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: AppText(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _newsMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    if (_distanceLabel(post) case final distance?) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            color: _newsAccentForeground,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          AppText(
                            distance,
                            style: TextStyle(
                              color: _newsMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    AppText(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _newsMuted,
                        height: 1.45,
                        fontSize: 13,
                      ),
                    ),
                    if (categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: DecoratedBox(
                          key: ValueKey(
                            'news-feed-sport-badge-${_venueIdentifier(post)}',
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: AppText(
                              categories.join(', '),
                              localize: true,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _newsInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (unavailable) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.softOrangeAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _newsOrange.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: _newsAccentForeground,
                              size: 19,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppText(
                                'This court is currently unavailable. Booking cannot proceed.',
                                style: TextStyle(
                                  color: _newsInk,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                localize: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        AppRatingStars(rating: rating, size: 16),
                        AppText(
                          rating == 0 ? 'New' : rating.toStringAsFixed(1),
                          localize: true,
                          style: TextStyle(
                            color: _newsInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        AppText(
                          rating == 0
                              ? 'No ratings yet'
                              : '$reviews ${reviews == 1 ? 'review' : 'reviews'} · '
                                    '$ratedUsers rated',
                          localize: true,
                          style: TextStyle(color: _newsMuted, fontSize: 12),
                        ),
                        TextButton.icon(
                          key: ValueKey(
                            'news-feed-reviews-${_venueIdentifier(post)}',
                          ),
                          onPressed: businessId == null
                              ? null
                              : () => _showReviews(post, businessId),
                          icon: const Icon(
                            Icons.rate_review_outlined,
                            size: 16,
                          ),
                          label: AppText(
                            type.trim().toLowerCase() == 'event'
                                ? 'Review'
                                : 'Reviews',
                            localize: true,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _newsInk,
                            padding: AppSpacing.buttonPadding,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: secondaryAction),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton.icon(
                            key: ValueKey(
                              'news-feed-explore-${_venueIdentifier(post)}',
                            ),
                            onPressed: unavailable
                                ? null
                                : () => _openBookingType(post),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                            label: const AppText(
                              'Explore venue',
                              localize: true,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _newsOrange,
                              foregroundColor: AppColors.onAccent,
                              padding: AppSpacing.buttonPadding,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isMerchantDisabled(Map<String, dynamic> post) {
    return isMerchantBusinessDisabled(post);
  }

  String _priceLabel(Map<String, dynamic> post) {
    final business = post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : const <String, dynamic>{};
    final businessType =
        '${post['businessType'] ?? business['businessType'] ?? ''}'
            .toLowerCase();
    final isEvent = businessType.contains('event');

    double? parseAmount(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final match = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(value);
        if (match != null) {
          return double.tryParse(match.group(0)!.replaceAll(',', ''));
        }
      }
      return null;
    }

    final price =
        [
              post['pricePerHour'],
              post['price_per_hour'],
              post['eventFee'],
              post['event_fee'],
              post['price'],
              business['pricePerHour'],
              business['price_per_hour'],
              business['eventFee'],
              business['event_fee'],
              business['price'],
            ]
            .map(parseAmount)
            .whereType<double>()
            .firstWhere((amount) => amount > 0, orElse: () => 0);
    if (price > 0) {
      return '\u{20B1} ${price.toStringAsFixed(0)} / ${isEvent ? 'event' : 'hr'}';
    }

    final rawPeriods = post['ratePeriods'] ?? post['rate_periods'];
    if (rawPeriods is List) {
      final rates = rawPeriods
          .whereType<Map>()
          .map(
            (period) => parseAmount(
              period['pricePerHour'] ??
                  period['price_per_hour'] ??
                  period['price'],
            ),
          )
          .whereType<double>()
          .where((amount) => amount > 0)
          .toList();
      if (rates.isNotEmpty) {
        rates.sort();
        return 'From \u{20B1} ${rates.first.toStringAsFixed(0)} / hr';
      }
    }

    return 'Price not listed';
  }

  Widget _priceTag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _newsAccentForeground.withValues(alpha: .28)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, color: _newsAccentForeground, size: 15),
          const SizedBox(width: 6),
          AppText(
            label,
            style: TextStyle(
              color: _newsInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _contactOwner(Map<String, dynamic> post) async {
    if (!await requireCustomerLogin(context)) return;
    try {
      final session = await AppSessionService.instance.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final businessKey = '${post['businessId'] ?? post['businessName'] ?? ''}';
      final response = await _api.messageOwner(
        token: token,
        businessKey: businessKey,
      );
      final owner = response['owner'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (owner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'This merchant is not available for messages yet.',
              localize: true,
            ),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesDashboardPage(
            owner: owner,
            businessTitle: '${post['businessName'] ?? 'Venue'}',
            initialUserPosition: _userPosition,
            api: _api,
            businessType: widget.businessType == 'Fitness' ? 'Fitness' : null,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            'Could not contact the owner: $error',
            localize: true,
          ),
        ),
      );
    }
  }

  Future<void> _toggleSaved(Map<String, dynamic> post) async {
    if (!await requireCustomerLogin(context)) return;
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}'.trim();
    final key = '${businessId ?? businessName}';
    if (key.isEmpty) return;
    final currentlySaved = _savedKeys.contains(key);
    setState(() {
      if (currentlySaved) {
        _savedKeys.remove(key);
        if (widget.savedOnly) {
          _posts = _posts.then(
            (posts) =>
                posts.where((item) => _postSaveKey(item) != key).toList(),
          );
        }
      } else {
        _savedKeys.add(key);
      }
    });
    try {
      if (currentlySaved) {
        await SavedItemStore.remove(widget.savedItemType, key, api: _api);
      } else {
        await SavedItemStore.save(
          type: widget.savedItemType,
          key: key,
          title: businessName,
          subtitle: '${post['address'] ?? ''}',
          imageUrl: '${post['imageUrl'] ?? ''}',
          api: _api,
        );
      }
      if (currentlySaved && widget.savedOnly && mounted) {
        _reload();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              currentlySaved ? 'Removed from Saved.' : 'Saved to your venues.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        if (currentlySaved) {
          _savedKeys.add(key);
          if (widget.savedOnly) {
            _posts = _loadFeed();
          }
        } else {
          _savedKeys.remove(key);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText('Could not update Saved: $error', localize: true),
        ),
      );
    }
  }

  String _postSaveKey(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}'.trim();
    return '${businessId ?? businessName}';
  }

  String _visitUrl(Map<String, dynamic> post) =>
      '${post['visitUrl'] ?? post['visit_url'] ?? ''}'.trim();

  Future<void> _visitVenue(Map<String, dynamic> post) async {
    final value = _visitUrl(post);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'The venue link could not be opened.',
              localize: true,
            ),
          ),
        );
      }
    }
  }

  Widget _imageFallback() => SizedBox(
    height: _newsCardImageHeight,
    width: double.infinity,
    child: ColoredBox(
      color: AppColors.softOrange,
      child: Icon(
        Icons.storefront_rounded,
        size: 52,
        color: _newsAccentForeground,
      ),
    ),
  );

  Widget _image(String value) {
    final provider = _imageProvider(value);
    if (provider == null) return _imageFallback();
    return Image(
      image: provider,
      height: _newsCardImageHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _imageFallback(),
    );
  }

  ImageProvider<Object>? _imageProvider(String value) {
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator <= 0 || separator >= value.length - 1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    return NetworkImage(value);
  }

  Future<void> _openBookingType(Map<String, dynamic> post) async {
    try {
      final businessValue = post['business'];
      final business = businessValue is Map
          ? Map<String, dynamic>.from(businessValue)
          : const <String, dynamic>{};
      final businessId = int.tryParse(
        '${post['businessId'] ?? business['id'] ?? ''}',
      );
      final locallyDisabled = _isMerchantDisabled(post);
      final availableBusinesses = locallyDisabled || businessId == null
          ? <VenueBusiness>[]
          : await _venueCatalog.customerBusinesses();
      if (!mounted) return;
      final matchingBusinesses = availableBusinesses
          .where((item) => item.id == businessId)
          .toList();
      final publishedBusiness = matchingBusinesses.isEmpty
          ? null
          : matchingBusinesses.first.toViewData();

      if (publishedBusiness == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText(
                'This venue is currently unavailable and cannot be booked.',
                localize: true,
              ),
            ),
          );
        }
        return;
      }
      final selectedType = BusinessTypeParser.parse(widget.businessType);
      final businessType = BusinessTypeParser.parse(
        publishedBusiness['businessType'] ??
            post['businessType'] ??
            post['type'],
      );
      if (selectedType == BusinessType.unknown ||
          businessType != selectedType) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'This venue does not belong to the selected booking category.',
              localize: true,
            ),
          ),
        );
        return;
      }
      final venue = _toSportsVenue(
        {
          ...post,
          ...publishedBusiness,
          'businessName': publishedBusiness['name'] ?? post['businessName'],
          'category': post['category'] ?? publishedBusiness['category'],
          'includedPlayers': publishedBusiness['includedPlayers'],
          'additionalPlayerFee': publishedBusiness['additionalPlayerFee'],
          'averageRating': post['averageRating'],
          'reviewCount': post['reviewCount'],
          'ratingUserCount': post['ratingUserCount'],
          'heartCount': post['heartCount'],
          'business': publishedBusiness,
        },
        fitness: businessType == BusinessType.fitness,
        event: businessType == BusinessType.event,
      );
      if (!mounted) return;

      if (businessType == BusinessType.event) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SportsVenueDetailPage(
              venue: venue,
              savedItemType: 'event',
              api: _api,
              amenitiesHeading: 'EVENT AMENITIES',
              isEvent: true,
              primaryActionLabel: 'Reserve event',
              onRequireLogin: requireCustomerLogin,
              onReserve: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: AppColors.surface,
                builder: (_) => EventBookingPage(
                  business: publishedBusiness,
                  api: _api,
                  asCheckoutSheet: true,
                ),
              ),
            ),
          ),
        );
        return;
      }

      if (businessType == BusinessType.fitness) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SportsVenueDetailPage(
              venue: venue,
              savedItemType: 'fitness',
              api: _api,
              amenitiesHeading: 'FITNESS AMENITIES',
              onRequireLogin: requireCustomerLogin,
              onReserve: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  backgroundColor: AppColors.surface,
                  builder: (_) => FitnessBookingPage(
                    business: publishedBusiness,
                    api: _api,
                    onLogout: widget.onLogout,
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      if (businessType != BusinessType.sports) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'This venue has no business type.',
              localize: true,
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SportsDashboardPage(
            onLogout: widget.onLogout,
            initialVenue: venue,
            api: _api,
            onRequireLogin: requireCustomerLogin,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText('Could not open venue page: $error', localize: true),
        ),
      );
    }
  }

  // Retained for compatibility with older venue-post payloads.
  // ignore: unused_element
  SportsVenue _toSportsVenue(
    Map<String, dynamic> post, {
    bool fitness = false,
    bool event = false,
  }) {
    final business = post['business'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(post['business'] as Map)
        : post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : <String, dynamic>{};
    final businessName = _stringValue([
      post['businessName'],
      business['name'],
      business['businessName'],
    ]);
    final category = _stringValue([post['category'], business['category']]);
    final eventTypes = _stringListValue([
      post['eventTypes'],
      post['event_types_json'],
      business['eventTypes'],
      business['event_types_json'],
    ]);
    final type = _stringValue([
      post['businessType'],
      business['businessType'],
      post['facilityType'],
      business['facilityType'],
    ]);
    final address = _stringValue([
      post['address'],
      business['address'],
      post['location'],
      business['location'],
    ]);
    final ownerName = _stringValue([
      post['ownerName'],
      business['ownerName'],
      post['merchantName'],
      business['merchantName'],
      post['ownerFirstName'],
      business['ownerFirstName'],
      post['ownerLastName'],
      business['ownerLastName'],
      business['merchant'],
    ]);
    final hours = _stringValue([
      post['hours'],
      post['opening_hours'],
      business['hours'],
      post['openingHours'],
      business['openingHours'],
      post['opening_hours'],
    ]);
    final availability = _stringValue([
      post['availability'],
      business['availability'],
      post['availabilityStatus'],
      business['availabilityStatus'],
    ]);
    final fitnessCategories = _stringMapList(
      business['fitnessCategories'] ?? business['fitness_categories_json'],
    );
    final fitnessCoaches = _stringMapList(
      business['fitnessCoaches'] ?? business['fitness_coaches_json'],
    );
    final fitnessRates = <String>[];
    var fitnessHeadlinePrice = 0.0;
    var fitnessHeadlineLabel = '';
    if (fitness) {
      for (final item in fitnessCategories) {
        final categoryName = _stringValue([item['category']]);
        if (categoryName.isEmpty) continue;
        for (final (plan, label, unit) in const [
          ('session', 'Session', 'session'),
          ('monthly', 'Monthly', 'month'),
          ('yearly', 'Yearly', 'year'),
        ]) {
          var amount = _number(item['${plan}Price']);
          if (plan == 'yearly') {
            final discountType = item['yearlyDiscountType'];
            final discountValue = _number(item['yearlyDiscountValue']);
            if (discountType == 'freeMonths') {
              amount = (amount - _number(item['monthlyPrice']) * discountValue)
                  .clamp(0, double.infinity);
            } else if (discountType == 'percentage') {
              amount *= (1 - discountValue / 100).clamp(0, 1);
            }
          }
          if (amount <= 0) continue;
          fitnessRates.add(
            '$categoryName · $label|\u{20B1} ${amount.toStringAsFixed(2)} / $unit',
          );
          if (fitnessHeadlinePrice == 0) {
            fitnessHeadlinePrice = amount;
            fitnessHeadlineLabel = unit;
          }
        }
      }
      for (final coach in fitnessCoaches) {
        final coachName = _stringValue([coach['name']]);
        final price = _number(coach['monthlyPrice']);
        if (coachName.isNotEmpty && price > 0) {
          fitnessRates.add(
            'Coach $coachName|\u{20B1} ${price.toStringAsFixed(2)} / month',
          );
        }
      }
    }
    final priceRaw = fitness && fitnessHeadlinePrice > 0
        ? fitnessHeadlinePrice
        : _firstNonEmpty([
            if (event) ...[
              post['eventFee'],
              business['eventFee'],
              post['event_fee'],
              business['event_fee'],
            ],
            post['pricePerHour'],
            business['pricePerHour'],
            post['price_per_hour'],
            business['price_per_hour'],
            post['price'],
            business['price'],
            post['hourlyRate'],
            business['hourlyRate'],
          ]);
    final priceText = priceRaw == null || '$priceRaw'.trim().isEmpty
        ? ''
        : fitness && fitnessHeadlinePrice > 0
        ? '\u{20B1} ${fitnessHeadlinePrice.toStringAsFixed(2)} / $fitnessHeadlineLabel'
        : event
        ? '\u{20B1} ${_number(priceRaw).toStringAsFixed(2)} / event'
        : (priceRaw is num
              ? '\u{20B1} ${priceRaw.toStringAsFixed(0)} / hour'
              : priceRaw.toString().startsWith('\u{20B1}')
              ? priceRaw.toString()
              : '\u{20B1} $priceRaw / hour');
    final image = _stringValue([
      post['imageUrl'],
      business['imageUrl'],
      post['image'],
      business['image'],
    ]);
    final images = _stringListValue([
      post['imageUrls'],
      post['businessImageUrl'],
      business['imageUrls'],
      post['images'],
      business['images'],
      post['imageUrl'],
      business['imageUrl'],
    ]);
    final tags = _stringListValue([
      post['tags'],
      post['amenities'],
      business['tags'],
      post['amenities'],
      business['amenities'],
    ]);
    final rawPeriods = post['ratePeriods'];
    final rateLabels = <String>[];
    if (rawPeriods is List) {
      for (final item in rawPeriods.whereType<Map>()) {
        final start = item['start'] ?? item['start_time'] ?? '';
        final end = item['end'] ?? item['end_time'] ?? '';
        final amount = item['pricePerHour'] ?? item['price_per_hour'];
        if ('$amount'.trim().isNotEmpty && '$amount' != 'null') {
          rateLabels.add(
            '$start - $end|\u{20B1} ${double.tryParse('$amount')?.toStringAsFixed(0) ?? amount} / hr',
          );
        }
      }
    }
    final parsedPrice = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0;
    final totalSlots =
        int.tryParse('${post['slotCount'] ?? business['slotCount'] ?? 1}') ?? 1;
    final rawSportsSlots =
        post['sportsSlots'] ??
        business['sportsSlots'] ??
        post['sports_slots_json'] ??
        business['sports_slots_json'];
    final sportsSlots = normalizeSportsSlotConfigurations(
      raw: rawSportsSlots,
      legacySportTypes: category,
      legacyPrice: parsedPrice,
      totalSlots: totalSlots,
      includedPlayers: _number(
        post['includedPlayers'] ??
            business['includedPlayers'] ??
            post['included_players'] ??
            business['included_players'],
      ).toInt(),
      additionalPlayerFee: _number(
        post['additionalPlayerFee'] ??
            business['additionalPlayerFee'] ??
            post['additional_player_fee'] ??
            business['additional_player_fee'],
      ),
    );
    final sportRateLabels = sportsSlots.map((sport) {
      final rate = (sport['pricePerHour'] as num).toDouble();
      final included = (sport['includedPlayers'] as num).toInt();
      final extraFee = (sport['additionalPlayerFee'] as num).toDouble();
      final playerFee = included > 0 && extraFee > 0
          ? ' · $included included · \u{20B1} ${extraFee.toStringAsFixed(2)} / extra player'
          : '';
      return '${sport['sportType']}: \u{20B1} ${rate.toStringAsFixed(2)} / hr / '
          '${sport['fullStudio'] == true ? 'whole studio' : 'per slot'}'
          '$playerFee';
    }).toList();
    final maxSportPrice = sportsSlots
        .map((sport) => (sport['pricePerHour'] as num).toDouble())
        .fold<double>(parsedPrice, (maximum, value) {
          return value > maximum ? value : maximum;
        });
    final venueId =
        int.tryParse('${post['businessId'] ?? business['id'] ?? 0}') ?? 0;

    return (
      id: venueId,
      name: businessName,
      sport: event
          ? (eventTypes.isEmpty ? category : eventTypes.join(', '))
          : fitness
          ? fitnessCategories
                .map((item) => _stringValue([item['category']]))
                .where((item) => item.isNotEmpty)
                .join(', ')
          : sportsSlots.map((item) => item['sportType']).join(', '),
      address: address,
      ownerName: ownerName,
      type: event
          ? _stringValue([
              post['facilityType'],
              business['facilityType'],
              business['facility_type'],
            ])
          : type,
      courts: fitness
          ? _stringValue([business['facilityType'], business['facility_type']])
          : '',
      hours: hours,
      availability: availability,
      details: _stringValue([
        post['details'],
        post['business_details'],
        business['details'],
      ]),
      image: image,
      images: images,
      priceDay: priceText,
      priceNight: priceText,
      priceLines: fitness && fitnessRates.isNotEmpty
          ? fitnessRates
          : sportRateLabels.isNotEmpty
          ? sportRateLabels
          : priceText.isEmpty
          ? const <String>[]
          : <String>[priceText],
      maxPrice: fitness && fitnessHeadlinePrice > 0
          ? fitnessHeadlinePrice
          : maxSportPrice,
      averageRating: _number(post['averageRating']),
      reviewCount: _number(post['reviewCount']).toInt(),
      ratingUserCount: _number(post['ratingUserCount']).toInt(),
      includedPlayers:
          int.tryParse(
            '${post['includedPlayers'] ?? business['includedPlayers'] ?? post['included_players'] ?? business['included_players'] ?? 0}',
          ) ??
          0,
      additionalPlayerFee:
          double.tryParse(
            '${post['additionalPlayerFee'] ?? business['additionalPlayerFee'] ?? post['additional_player_fee'] ?? business['additional_player_fee'] ?? 0}',
          ) ??
          0,
      totalSlots: totalSlots,
      sportsSlots: sportsSlots,
      tags: tags,
      rateLabels: fitness && fitnessRates.isNotEmpty
          ? fitnessRates
          : event && priceText.isNotEmpty
          ? [priceText]
          : sportRateLabels.isNotEmpty
          ? sportRateLabels
          : rateLabels,
      latitude: 0,
      longitude: 0,
      distanceLabel: _distanceLabel(post) ?? '',
      heartCount: _postHeartCount(post),
      visitUrl: _stringValue([
        post['visitUrl'],
        business['visitUrl'],
        post['visit_url'],
        business['visit_url'],
      ]),
      merchantEmail: _stringValue([
        post['merchantEmail'],
        business['merchantEmail'],
        post['ownerEmail'],
        business['ownerEmail'],
        post['merchant_email'],
        business['merchant_email'],
        post['owner_email'],
        business['owner_email'],
      ]),
      merchantPhone: _stringValue([
        post['merchantPhone'],
        business['merchantPhone'],
        post['ownerPhone'],
        business['ownerPhone'],
        post['merchant_phone'],
        business['merchant_phone'],
        post['owner_phone'],
        business['owner_phone'],
      ]),
      merchantAvatarUrl: _stringValue([
        post['merchantAvatarUrl'],
        business['merchantAvatarUrl'],
        post['ownerAvatarUrl'],
        business['ownerAvatarUrl'],
        post['merchant_avatar_url'],
        business['merchant_avatar_url'],
        post['owner_avatar_url'],
        business['owner_avatar_url'],
      ]),
    );
  }

  String _stringValue(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num || value is bool) return value.toString();
      if (value is Map) {
        final map = value;
        final candidate = _stringValue([
          map['ownerName'],
          map['merchantName'],
          map['name'],
          map['businessName'],
          map['firstName'],
          map['lastName'],
        ]);
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _stringMapList(Object? value) {
    dynamic decoded = value;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  dynamic _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value;
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        return _firstNonEmpty([
          value['pricePerHour'],
          value['price_per_hour'],
          value['hourlyRate'],
          value['price'],
        ]);
      }
    }
    return null;
  }

  List<String> _stringListValue(List<dynamic> values) {
    final output = <String>[];
    for (final value in values) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          output.add(trimmed);
        }
        continue;
      }
      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            output.add(item.trim());
          } else if (item is Map) {
            final nested = _stringValue([
              item['name'],
              item['label'],
              item['value'],
            ]);
            if (nested.isNotEmpty) output.add(nested);
          }
        }
      }
      if (value is Map) {
        final nested = _stringValue([
          value['name'],
          value['label'],
          value['value'],
          value['title'],
          value['tag'],
        ]);
        if (nested.isNotEmpty) output.add(nested);
      }
    }
    return output.toSet().toList();
  }

  List<String> _imageListValue(List<dynamic> values) {
    for (final value in values) {
      final parsed = <String>[];
      if (value is List) {
        parsed.addAll(
          value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty && item != 'null'),
        );
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              parsed.addAll(
                decoded
                    .whereType<String>()
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty && item != 'null'),
              );
            }
          } on FormatException {
            continue;
          }
        } else if (trimmed.isNotEmpty && trimmed != 'null') {
          parsed.add(trimmed);
        }
      }
      if (parsed.isNotEmpty) return parsed.toSet().toList();
    }
    return const [];
  }

  Future<void> _showReviews(Map<String, dynamic> post, int businessId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ReviewsSheet(
          api: _api,
          businessId: businessId,
          businessName: '${post['businessName'] ?? ''}',
          isEvent:
              BusinessTypeParser.parse(post['businessType']) ==
              BusinessType.event,
          onSubmitted: (average, reviewCount, ratedUsers) {
            setState(() {
              post['averageRating'] = average;
              post['reviewCount'] = reviewCount;
              post['ratingUserCount'] = ratedUsers;
            });
          },
        ),
      );

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
}

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.businessType,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String? businessType;

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
  bool _posting = false;
  int _unreadSocialNotifications = 0;
  Object? _socialNotificationsError;
  int _selectedHomeFeed = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingForYou = true;
      _loadingFollowing = true;
      _forYouError = null;
      _followingError = null;
    });
    try {
      final session = await AppSessionService.instance.load();
      if (!mounted) return;
      setState(() {
        if (_token != session.apiToken) {
          _currentUserId = null;
          _unreadSocialNotifications = 0;
          _socialNotificationsError = null;
        }
        _token = session.apiToken;
      });
      await Future.wait([
        _loadForYou(session.apiToken),
        _loadFollowing(session.apiToken),
        _loadSocialNotificationCount(session.apiToken),
      ]);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _forYouError = error;
          _followingError = error;
          _loadingForYou = false;
          _loadingFollowing = false;
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
      final posts = await _api.socialFeed(token, allPublicPosts: true);
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
          _loadingFollowing = false;
        });
      }
      return;
    }
    setState(() {
      _loadingFollowing = true;
      _followingError = null;
    });
    try {
      final posts = await _api.socialFeed(token, followingOnly: true);
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
      final response = await _api.socialNotifications(token);
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
      await _api.createSocialPost(
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
      _selectedHomeFeed = 1;
    });
    await _loadFollowing(session.apiToken);
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
      height: 112,
      child: ListView(
        key: const ValueKey('customer-home-player-rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        children: [
          _PlayerBubble(label: 'Post Match', isAdd: true, onTap: _openComposer),
          for (final player in players)
            _PlayerBubble(
              label: '${player['displayName'] ?? 'SpotGo player'}',
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

  Widget _buildComposerCard(SocialHomeColors colors) => Container(
    key: const ValueKey('customer-home-composer'),
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            InkWell(
              key: const ValueKey('customer-home-own-profile'),
              onTap: _openOwnProfile,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: colors.surfaceRaised,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 19,
                  color: colors.muted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                key: const ValueKey('customer-home-composer-prompt'),
                borderRadius: BorderRadius.circular(8),
                onTap: _openComposer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AppText(
                    'Share your session, drop an invite, or post a highlight',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    localize: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _HomeComposerAction(
              key: const ValueKey('customer-home-add'),
              icon: Icons.photo_camera_outlined,
              label: 'Photo',
              color: colors.mint,
              onTap: _openComposer,
            ),
            const SizedBox(width: 6),
            _HomeComposerAction(
              icon: Icons.location_on_outlined,
              label: 'Venue',
              color: const Color(0xFFA5A5FF),
              onTap: () => _onDestinationSelected(0),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildHomeFilters() => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 5),
      children: [
        _HomeFeedFilter(
          label: 'For You',
          selected: _selectedHomeFeed == 0,
          onTap: () => setState(() => _selectedHomeFeed = 0),
        ),
        _HomeFeedFilter(
          label: 'Following',
          selected: _selectedHomeFeed == 1,
          onTap: () => setState(() => _selectedHomeFeed = 1),
        ),
      ],
    ),
  );

  Widget _buildCommunitySearchButton() => IconButton(
    tooltip: 'Search players',
    onPressed: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SocialCommunityPage(api: _api)),
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
                  onPressed: () => setState(() => _selectedHomeFeed = 0),
                  icon: const Icon(Icons.explore_outlined),
                  label: const AppText('Browse For You', localize: true),
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
    final following = _selectedHomeFeed == 1;
    return RefreshIndicator(
      onRefresh: () => following ? _loadFollowing(_token) : _loadForYou(_token),
      child: ListView(
        key: const ValueKey('customer-home-timeline'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          _buildPlayerRail(),
          _buildComposerCard(SocialHomeColors.of(context)),
          _buildHomeFilters(),
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
  }

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
              toolbarHeight: 56,
              titleSpacing: 14,
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
            bottomNavigationBar: AppBottomNavigation(
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
    this.imageProvider,
    this.isAdd = false,
    required this.onTap,
  });

  final String label;
  final ImageProvider<Object>? imageProvider;
  final bool isAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    return SizedBox(
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
  }
}

class _HomeComposerAction extends StatelessWidget {
  const _HomeComposerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SocialHomeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                localize: true,
              ),
            ],
          ),
        ),
      ),
    );
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
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
