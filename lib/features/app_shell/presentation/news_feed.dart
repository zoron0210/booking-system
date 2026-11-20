import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, listEquals;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:myapp/core/app_card_styles.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/skeleton_loader.dart';
import 'package:myapp/core/business_type.dart';
import 'package:myapp/core/scroll_aware_header.dart';
import 'package:myapp/features/app_shell/presentation/app_bottom_navigation.dart';
import 'package:myapp/features/app_shell/presentation/customer_navigation_scope.dart';
import 'package:myapp/features/app_shell/presentation/news_feed_image_carousel.dart';
import 'package:myapp/features/app_shell/presentation/reserve_dashboard.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/auth/presentation/guest_access.dart';
import 'package:myapp/features/bookings/presentation/customer_bookings_page.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/features/venues/presentation/all_venues_page.dart';
import 'package:myapp/features/bookings/presentation/event_booking_page.dart';
import 'package:myapp/core/filter_panel_style.dart';
import 'package:myapp/features/bookings/presentation/fitness_booking_calendar.dart';
import 'package:myapp/features/bookings/presentation/fitness_booking_page.dart';
import 'package:myapp/features/venues/domain/merchant_business_status.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';
import 'package:myapp/features/profile/presentation/profile_dashboard.dart';
import 'package:myapp/core/rating_widgets.dart';
import 'package:myapp/features/venues/presentation/reviews.dart';
import 'package:myapp/features/saved_items/data/saved_item_store.dart';
import 'package:myapp/features/saved_items/presentation/saved_icons.dart';
import 'package:myapp/features/bookings/presentation/sports_booking_page.dart';
import 'package:myapp/features/bookings/presentation/matchmaking_lobby_list_page.dart';
import 'package:myapp/features/bookings/domain/sports_slot_configurations.dart';

import 'customer_home_page.dart';

export 'customer_home_page.dart';

part 'news_feed_filters.dart';
part 'news_feed_map.dart';
part 'news_feed_venue_cards.dart';
part 'news_feed_featured_cards.dart';
part 'news_feed_mini_venue_cards.dart';
part 'news_feed_posts.dart';
part 'news_feed_images.dart';

Color get _newsInk => AppColors.ink;
Color get _newsMuted => AppColors.muted;
Color get _newsOrange => AppColors.accent;
Color get _newsAccentForeground => AppColors.accentForeground;
Color get _newsPage => AppColors.page;
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
Color get _venuePrimary => AppColors.accent;
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
    this.highestRatedSectionTitle = 'Highest rated',
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
  final _matchSearchController = TextEditingController();
  final _feedScrollController = ScrollController();
  final _sportsDiscoveryPageController = PageController();
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
  var _locationPromptHandled = false;
  var _courtMapExpanded = false;
  var _sportsDiscoveryTab = 0;
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

  void _updateState(VoidCallback update) => setState(update);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_locationPromptHandled) {
        _locationPromptHandled = true;
        _maybeRequestLocationForDiscovery();
      }
    });
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
    if (bookingTypeChanged) {
      _sportsDiscoveryTab = 0;
      if (_sportsDiscoveryPageController.hasClients) {
        _sportsDiscoveryPageController.jumpToPage(0);
      }
    }
    _savedKeys.clear();
    _heartedVenueKeys.clear();
    _heartUpdatesInProgress.clear();
    _heartCounts.clear();
    _userPosition = widget.initialUserPosition ?? _userPosition;
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
              'visitCount':
                  business['visitCount'] ?? business['visit_count'] ?? 0,
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
          'visitCount': business['visitCount'] ?? business['visit_count'] ?? 0,
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
    _matchSearchController.dispose();
    _feedScrollController.dispose();
    _sportsDiscoveryPageController.dispose();
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
          ),
    body: _courtMapExpanded && !widget.savedOnly
        ? Column(
            children: [
              _mainSearchBar(),
              Expanded(child: _courtLocationsMap()),
            ],
          )
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppResponsive.contentMaxWidthFor(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              child: ScrollAwareHeader(
                header: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.savedOnly) _mainSearchBar(),
                    if (!widget.savedOnly && _isSportsFeed)
                      _sportsDiscoveryTabs(),
                    if (!widget.savedOnly &&
                        !(_isSportsFeed && _sportsDiscoveryTab == 1) &&
                        (_isSportsFeed || _isEventFeed || _isFitnessFeed))
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _posts,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          return _sportTypeFilterBar(
                            _categoryOptions(snapshot.data!),
                          );
                        },
                      ),
                  ],
                ),
                body: _isSportsFeed
                    ? PageView(
                        key: const ValueKey('sports-discovery-pages'),
                        controller: _sportsDiscoveryPageController,
                        onPageChanged: (index) {
                          if (_sportsDiscoveryTab != index) {
                            setState(() => _sportsDiscoveryTab = index);
                          }
                        },
                        children: [
                          _venueFeedBody(),
                          MatchmakingLobbyListPage(
                            api: _api,
                            initialUserPosition: _userPosition,
                            searchQuery: _matchSearchController.text,
                          ),
                        ],
                      )
                    : _venueFeedBody(),
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

  Widget _sportsDiscoveryTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: SizedBox(
      width: double.infinity,
      child: Material(
        key: const ValueKey('sports-discovery-tabs'),
        color: _venueSurface,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity;
            if (velocity == null || velocity.abs() < 100) return;
            _selectSportsDiscoveryTab(velocity < 0 ? 1 : 0);
          },
          child: Row(
            children: [
              for (final (index, label, indicatorWidth) in [
                (0, 'Venues', 42.0),
                (1, 'Find Matches', 82.0),
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => _selectSportsDiscoveryTab(index),
                    child: SizedBox(
                      height: 48,
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: _sportsDiscoveryTab == index
                                      ? _venueText
                                      : _venueMuted,
                                  fontWeight: _sportsDiscoveryTab == index
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: indicatorWidth,
                            height: 3,
                            color: _sportsDiscoveryTab == index
                                ? _venuePrimary
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  void _selectSportsDiscoveryTab(int index) {
    if (_sportsDiscoveryTab == index) return;
    setState(() => _sportsDiscoveryTab = index);
    if (_sportsDiscoveryPageController.hasClients) {
      _sportsDiscoveryPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _venueFeedBody() => RefreshIndicator(
    key: _feedRefreshKey,
    onRefresh: _reload,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            key: const ValueKey('news-feed-loading-skeleton'),
            controller: _feedScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const SkeletonBlock(height: 18, width: 150),
              const SizedBox(height: 10),
              const SkeletonBlock(height: 230, borderRadius: 20),
              const SizedBox(height: 18),
              const SkeletonBlock(height: 18, width: 170),
              const SizedBox(height: 10),
              const SkeletonBlock(height: 122, borderRadius: 16),
              const SizedBox(height: 8),
              const SkeletonBlock(height: 122, borderRadius: 16),
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
              label: const AppText('Try again', localize: true),
            ),
          );
        }
        final posts = _filteredPosts(snapshot.data ?? const []);
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
                    key: const ValueKey('news-feed-clear-search-and-filters'),
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
        return widget.savedOnly ? _savedCardList(posts) : _feedContent(posts);
      },
    ),
  );

  Widget _mainSearchBar() => Container(
    key: const ValueKey('news-feed-search-container'),
    color: _venueCanvas,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: TextField(
      key: ValueKey(
        _sportsDiscoveryTab == 1
            ? 'news-feed-match-search'
            : 'news-feed-search',
      ),
      controller: _sportsDiscoveryTab == 1
          ? _matchSearchController
          : _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: _venueText, fontSize: 14),
      decoration: InputDecoration(
        hintText: _sportsDiscoveryTab == 1
            ? 'Search matches, sports, venues, or hosts'
            : appLanguageText(widget.searchHint, widget.searchHint),
        hintStyle: TextStyle(color: _venueMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIconConstraints: BoxConstraints(
          minWidth: _sportsDiscoveryTab == 1 ? 44 : 88,
          minHeight: 40,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_activeSearchController.text.isNotEmpty)
              IconButton(
                key: ValueKey(
                  _sportsDiscoveryTab == 1
                      ? 'news-feed-match-search-clear'
                      : 'news-feed-search-clear',
                ),
                tooltip: appLanguageText('Clear search', 'Clear search'),
                onPressed: () {
                  _activeSearchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            if (_sportsDiscoveryTab != 1) ...[
              _courtMapHeaderControl(),
              IconButton(
                key: const ValueKey('news-feed-open-filters'),
                tooltip: _activeFeedFilterCount == 0
                    ? 'Filter venues'
                    : 'Filter venues ($_activeFeedFilterCount active)',
                onPressed: _openSportsFilters,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
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
          ],
        ),
        filled: true,
        fillColor: _venueSurface,
        isDense: true,
        prefixIconColor: _venueMuted,
        suffixIconColor: _venueMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: _venuePrimary, width: 1.4),
        ),
      ),
    ),
  );

  TextEditingController get _activeSearchController =>
      _sportsDiscoveryTab == 1 ? _matchSearchController : _searchController;

  Widget _sportTypeFilterBar(List<String> sports) => Container(
    key: const ValueKey('news-feed-sport-filter-bar'),
    color: _venueCanvas,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  showCheckmark: false,
                  selected: _feedSport == sports[index],
                  onSelected: (_) => setState(() {
                    _feedSport = sports[index];
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -1,
                    vertical: -1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  avatar: Icon(
                    _categoryIcon(sports[index]),
                    size: 17,
                    color: _feedSport == sports[index]
                        ? Colors.white
                        : _venueMuted,
                  ),
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
        const SizedBox(height: 3),
        Divider(height: 1, color: _venueOutline.withValues(alpha: .65)),
      ],
    ),
  );

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value == _categoryAllLabel.toLowerCase()) return Icons.explore_rounded;
    if (value.contains('basket')) {
      return Icons.sports_basketball_rounded;
    }
    if (value.contains('volley')) return Icons.sports_volleyball_rounded;
    if (value.contains('tennis') || value.contains('badminton')) {
      return Icons.sports_tennis_rounded;
    }
    if (value.contains('swim')) return Icons.pool_rounded;
    if (value.contains('dance') || value.contains('yoga')) {
      return Icons.self_improvement_rounded;
    }
    if (value.contains('wedding') || value.contains('party')) {
      return Icons.celebration_rounded;
    }
    if (value.contains('gym') || value.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.category_rounded;
  }

  Widget _feedContent(List<Map<String, dynamic>> posts) {
    final uniquePosts = <String, Map<String, dynamic>>{};
    for (final post in posts) {
      uniquePosts.putIfAbsent(_venueIdentifier(post), () => post);
    }
    final catalogPosts = uniquePosts.values.toList();
    final popular = [...catalogPosts]
      ..sort((a, b) {
        final byHearts = _postHeartCount(b).compareTo(_postHeartCount(a));
        return byHearts != 0
            ? byHearts
            : '${a['businessName']}'.compareTo('${b['businessName']}');
      });
    final highestRated =
        catalogPosts
            .where(
              (post) =>
                  _number(post['reviewCount'] ?? post['review_count']) > 0,
            )
            .toList()
          ..sort((a, b) {
            final byRating = _number(b['averageRating'])
                .compareTo(_number(a['averageRating']));
            return byRating != 0
                ? byRating
                : '${a['businessName']}'.compareTo('${b['businessName']}');
          });
    final mostVisited =
        catalogPosts.where((post) => _postVisitCount(post) > 0).toList()
          ..sort((a, b) {
            final byVisits = _postVisitCount(b).compareTo(_postVisitCount(a));
            return byVisits != 0
                ? byVisits
                : '${a['businessName']}'.compareTo('${b['businessName']}');
          });
    final nearby = _userPosition == null
        ? const <Map<String, dynamic>>[]
        : _distanceSortedPosts(
            catalogPosts,
            radiusMeters: 10000,
          ).take(8).toList();
    final showCuratedSections = catalogPosts.length > 1;
    final List<Map<String, dynamic>> featured = showCuratedSections
        ? popular.take(8).toList()
        : <Map<String, dynamic>>[];
    final featuredIds = featured.map((post) => _venueIdentifier(post)).toSet();
    final rated = highestRated
        .where((post) => !featuredIds.contains(_venueIdentifier(post)))
        .take(8)
        .toList();
    final visited = mostVisited
        .where((post) => !featuredIds.contains(_venueIdentifier(post)))
        .take(8)
        .toList();
    final nearYou = nearby
        .where((post) => !featuredIds.contains(_venueIdentifier(post)))
        .toList();
    final courtLocations = _isSportsFeed && showCuratedSections
        ? _courtLocationGroups(catalogPosts)
        : const [];

    return ListView(
      key: const ValueKey('news-feed-content-list'),
      controller: _feedScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SizedBox(height: 18),
        if (showCuratedSections) ...[
          _sectionHeader(
            _popularSectionTitle,
            _popularSectionDescription,
            popular,
            featured: true,
          ),
          const SizedBox(height: 16),
          _horizontalVenues(
            featured,
            identifier: 'popular',
            badgeLabel: 'Popular pick',
          ),
        ],
        if (showCuratedSections && !_isSportsFeed && rated.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(
            widget.highestRatedSectionTitle,
            'Highest average review rating',
            rated,
            featured: true,
          ),
          const SizedBox(height: 16),
          _horizontalVenues(
            rated,
            identifier: widget.highestRatedSectionTitle
                .toLowerCase()
                .replaceAll(' ', '-'),
            badgeLabel: 'Top rated',
          ),
        ],
        if (showCuratedSections && visited.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(
            _mostVisitedSectionTitle,
            _mostVisitedSectionDescription,
            visited,
            featured: true,
          ),
          const SizedBox(height: 16),
          _horizontalVenues(
            visited,
            identifier: 'most-visited',
            badgeLabel: 'Most visited',
          ),
        ],
        if (_userPosition != null && nearYou.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(
            'Near you',
            'Closest venues by distance from your location',
            nearYou,
            featured: true,
          ),
          const SizedBox(height: 16),
          _horizontalVenues(
            nearYou,
            identifier: 'near-you',
            badgeLabel: 'Near you',
          ),
        ],
        for (final location in courtLocations) ...[
          if (location.weekendCourts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(
              'Availability in ${location.city} (Weekend)',
              'Courts scheduled to be available on Saturday or Sunday',
              location.weekendCourts,
            ),
            const SizedBox(height: 16),
            _horizontalVenues(
              location.weekendCourts,
              identifier: 'weekend-${_venueSectionSlug(location.city)}',
              badgeLabel: 'Weekend available',
            ),
          ],
          const SizedBox(height: 16),
          _sectionHeader(
            'Courts in ${location.city}',
            'All listed courts in ${location.city}',
            location.courts,
          ),
          const SizedBox(height: 16),
          _horizontalVenues(
            location.courts,
            identifier: 'city-${_venueSectionSlug(location.city)}',
            badgeLabel: 'Nearby court',
          ),
        ],
        const SizedBox(height: 16),
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
                    '(${posts.length} ${posts.length == 1 ? 'venue' : 'venues'})',
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
        const SizedBox(height: 16),
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

  String get _mostVisitedSectionTitle =>
      switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.sports => 'Most visited',
        BusinessType.event => 'Most visited event venues',
        BusinessType.fitness => 'Most visited fitness spaces',
        BusinessType.unknown => 'Most visited venues',
      };

  String get _mostVisitedSectionDescription =>
      switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.sports => 'Completed visits from customers',
        BusinessType.event => 'Completed bookings and event visits',
        BusinessType.fitness => 'Completed studio and wellness visits',
        BusinessType.unknown => 'Completed visits from customers',
      };

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
          (_feedAvailability == 'Open today'
              ? _isVenueOpenToday(post)
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

  bool _isVenueOpenToday(Map<String, dynamic> post) {
    return _venueTodayStatus(post) == 'Open today';
  }

  Set<int>? _venueScheduledDays(Map<String, dynamic> post) {
    if (_isMerchantDisabled(post)) return null;
    final business = post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : const <String, dynamic>{};
    final availability = _stringValue([
      post['availability'],
      business['availability'],
    ]);
    final hours = _stringValue([
      post['hours'],
      post['opening_hours'],
      post['openingHours'],
      business['hours'],
      business['opening_hours'],
      business['openingHours'],
    ]);
    final availableDays = _scheduledWeekdays(availability);
    final hoursDays = _scheduledWeekdays(
      hours,
      closedDaysMeanOtherDaysOpen: true,
    );
    return switch ((availableDays, hoursDays)) {
      (final available?, final scheduled?) => available.intersection(scheduled),
      (final available?, null) => available,
      (null, final scheduled?) => scheduled,
      (null, null) => null,
    };
  }

  String? _venueTodayStatus(Map<String, dynamic> post) {
    if (_isMerchantDisabled(post)) return null;
    final business = post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : const <String, dynamic>{};
    final availability = _stringValue([
      post['availability'],
      business['availability'],
    ]);
    final hours = _stringValue([
      post['hours'],
      post['opening_hours'],
      post['openingHours'],
      business['hours'],
      business['opening_hours'],
      business['openingHours'],
    ]);
    final scheduledDays = _venueScheduledDays(post);
    if (scheduledDays != null) {
      return scheduledDays.contains(DateTime.now().weekday)
          ? 'Open today'
          : 'Closed today';
    }

    final normalizedAvailability = availability.toLowerCase().trim();
    final normalizedHours = hours.toLowerCase().trim();
    final isAlwaysAvailable =
        normalizedAvailability == 'any' ||
        RegExp(r'\b(open daily|every day|daily|open 24 hours)\b')
            .hasMatch('$normalizedAvailability $normalizedHours');
    if (!isAlwaysAvailable) return null;
    if (fitnessVenueClosesSunday(hours) &&
        DateTime.now().weekday == DateTime.sunday) {
      return 'Closed today';
    }
    return 'Open today';
  }

  Set<int>? _scheduledWeekdays(
    String schedule, {
    bool closedDaysMeanOtherDaysOpen = false,
  }) {
    const weekdayAliases = <String, int>{
      'mon': DateTime.monday,
      'monday': DateTime.monday,
      'tue': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'tuesday': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'wednesday': DateTime.wednesday,
      'thu': DateTime.thursday,
      'thur': DateTime.thursday,
      'thurs': DateTime.thursday,
      'thursday': DateTime.thursday,
      'fri': DateTime.friday,
      'friday': DateTime.friday,
      'sat': DateTime.saturday,
      'saturday': DateTime.saturday,
      'sun': DateTime.sunday,
      'sunday': DateTime.sunday,
    };
    final weekdayPattern = RegExp(
      r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'tues|thur|thurs|mon|tue|wed|thu|fri|sat|sun)\b',
      caseSensitive: false,
    );
    final weekendPattern = RegExp(r'\bweekends?\b', caseSensitive: false);
    final openDays = <int>{};
    final closedDays = <int>{};
    var foundWeekday = false;

    for (final segment in schedule.split(RegExp(r'[,;\n]'))) {
      final matches = weekdayPattern.allMatches(segment).toList();
      final includesWeekend = weekendPattern.hasMatch(segment);
      if (matches.isEmpty && !includesWeekend) continue;
      foundWeekday = true;
      final isClosed = RegExp(
        r'\b(closed|close|off|unavailable)\b',
        caseSensitive: false,
      ).hasMatch(segment);
      var segmentDays = matches
          .map((match) => weekdayAliases[match.group(0)!.toLowerCase()])
          .whereType<int>()
          .toSet();
      if (includesWeekend) {
        segmentDays
          ..add(DateTime.saturday)
          ..add(DateTime.sunday);
      }

      if (matches.length >= 2) {
        final rangeText = segment.substring(
          matches.first.end,
          matches.last.start,
        );
        if (RegExp(
          r'[-–—]|\bto\b|\bthrough\b',
          caseSensitive: false,
        ).hasMatch(rangeText)) {
          final start = weekdayAliases[matches.first.group(0)!.toLowerCase()]!;
          final end = weekdayAliases[matches.last.group(0)!.toLowerCase()]!;
          segmentDays = <int>{};
          var day = start;
          while (true) {
            segmentDays.add(day);
            if (day == end) break;
            day = day % DateTime.daysPerWeek + 1;
          }
        }
      }

      if (isClosed) {
        closedDays.addAll(segmentDays);
      } else {
        openDays.addAll(segmentDays);
      }
    }
    if (!foundWeekday) return null;
    if (openDays.isEmpty &&
        closedDays.isNotEmpty &&
        closedDaysMeanOtherDaysOpen) {
      openDays.addAll(
        {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        }..removeAll(closedDays),
      );
    }
    openDays.removeAll(closedDays);
    return openDays;
  }

  List<Map<String, dynamic>> _distanceSortedPosts(
    List<Map<String, dynamic>> posts, {
    double radiusMeters = double.infinity,
  }) {
    final position = _userPosition;
    if (position == null) return const <Map<String, dynamic>>[];
    final ranked =
        posts
            .map((post) => MapEntry(post, _distanceFrom(position, post)))
            .where((entry) => entry.value.isFinite)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    if (radiusMeters.isFinite) {
      final filtered = ranked
          .where((entry) => entry.value <= radiusMeters)
          .map((entry) => entry.key)
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    return ranked.map((entry) => entry.key).toList();
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
    final navigation = CustomerNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.onDestinationSelected(index);
      return;
    }
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
}
