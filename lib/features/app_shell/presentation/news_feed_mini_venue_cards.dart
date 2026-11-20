part of 'news_feed.dart';

extension _NewsFeedMiniVenueCards on _NewsFeedPageState {
  Widget _miniVenueCard(
    Map<String, dynamic> post, {
    required String section,
    required String badgeLabel,
    required bool compact,
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
    final logo = _stringValue([
      post['businessLogoUrl'],
      post['business_logo_url'],
      business['businessLogoUrl'],
      business['business_logo_url'],
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
    final address = _stringValue([
      post['address'],
      post['location'],
      business['address'],
      business['location'],
    ]);
    final identifier = _venueIdentifier(post);
    final idPrefix = section == 'popular' ? 'featured' : section;
    final compactPrefix = section == 'popular' ? 'popular' : section;
    final rating = _number(post['averageRating']);
    final reviewCount = _number(
      post['reviewCount'] ??
          post['review_count'] ??
          business['reviewCount'] ??
          business['review_count'],
    ).toInt();
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final visitCount = _postVisitCount(post);
    final priceLabel = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final todayStatus = compact ? _venueTodayStatus(post) : null;
    final distance = _distanceLabel(post);
    final imageIndex = (_featuredImageIndexes[identifier] ?? 0).clamp(
      0,
      images.isEmpty ? 0 : images.length - 1,
    );
    return Semantics(
      key: ValueKey('news-feed-mini-$identifier'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. $badgeLabel. $_venueBookingActionLabel.',
      onTap: unavailable ? null : () => _openBookingType(post),
      child: Material(
        key: ValueKey('news-feed-mini-card-surface-$identifier'),
        color: _venueCard,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: unavailable ? null : () => _openBookingType(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    key: compact
                        ? ValueKey('news-feed-$compactPrefix-image-$identifier')
                        : null,
                    height: compact ? 136 : 170,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (images.isEmpty)
                          _miniImageFallback()
                        else
                          _VenueImageCarousel(
                            images: images,
                            initialIndex: imageIndex,
                            dotKey: (index) => ValueKey(
                              'news-feed-$idPrefix-image-dot-$identifier-$index',
                            ),
                            onIndexChanged: (index) => _updateState(
                              () => _featuredImageIndexes[identifier] = index,
                            ),
                            imageBuilder: _miniImage,
                          ),
                        if (unavailable)
                          const ColoredBox(color: Color(0x55000000)),
                        Positioned(
                          top: 11,
                          left: 11,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _venueSurface.withValues(alpha: .96),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 11,
                                vertical: compact ? 5 : 7,
                              ),
                              child: AppText(
                                unavailable
                                    ? 'Unavailable'
                                    : compact && section == 'popular'
                                    ? 'Top pick'
                                    : badgeLabel,
                                style: TextStyle(
                                  color: unavailable
                                      ? const Color(0xFFD32F2F)
                                      : _venueText,
                                  fontSize: compact ? 9 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _featuredImageAction(
                                key: 'news-feed-$idPrefix-heart-$identifier',
                                legacyKey: 'news-feed-mini-heart-$identifier',
                                icon: hearted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                tooltip: hearted
                                    ? 'Remove heart'
                                    : 'Heart venue',
                                color: hearted ? Colors.red : _venueText,
                                onPressed: () => _toggleHeart(post),
                                compact: compact,
                              ),
                              SizedBox(width: compact ? 1 : 4),
                              _featuredImageAction(
                                key: 'news-feed-$idPrefix-save-$identifier',
                                legacyKey: section == 'popular'
                                    ? 'news-feed-featured-save-$identifier'
                                    : null,
                                icon: _savedKeys.contains(_postSaveKey(post))
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                tooltip: _savedKeys.contains(_postSaveKey(post))
                                    ? 'Remove saved venue'
                                    : 'Save venue',
                                color: _savedKeys.contains(_postSaveKey(post))
                                    ? _venuePrimary
                                    : _venueText,
                                onPressed: () => _toggleSaved(post),
                                compact: compact,
                              ),
                            ],
                          ),
                        ),
                        if (_isVenueOpenToday(post) && !unavailable && !compact)
                          Positioned(
                            left: 11,
                            bottom: 11,
                            child: _availabilityImageTag(
                              'Open today',
                              unavailable: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  key: compact
                      ? ValueKey('news-feed-$compactPrefix-details-$identifier')
                      : null,
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 0,
                    compact ? 8 : 0,
                    compact ? 10 : 0,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              key: ValueKey(
                                'news-feed-featured-logo-$identifier',
                              ),
                              width: compact ? 26 : 30,
                              height: compact ? 26 : 30,
                              child: logo.isEmpty
                                  ? Container(
                                      alignment: Alignment.center,
                                      color: _venueSurface,
                                      child: AppText(
                                        name
                                            .split(RegExp(r'\s+'))
                                            .where((part) => part.isNotEmpty)
                                            .take(2)
                                            .map(
                                              (part) => part[0].toUpperCase(),
                                            )
                                            .join(),
                                        style: TextStyle(
                                          color: _venuePrimary,
                                          fontSize: compact ? 8 : 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    )
                                  : _miniImage(logo),
                            ),
                          ),
                          SizedBox(width: compact ? 5 : 7),
                          Expanded(
                            child: AppText(
                              name,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _venueText,
                                fontSize: compact ? 12 : 14,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (compact) ...[
                            SizedBox(
                              width: 76,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFCB66),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: AppText(
                                      '${_venueRatingLabel(rating, reviewCount)} ($reviewCount)',
                                      key: ValueKey(
                                        'news-feed-$compactPrefix-rating-$identifier',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _venueText,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFCB66),
                              size: 15,
                            ),
                            const SizedBox(width: 2),
                            AppText(
                              _venueRatingLabel(rating, reviewCount),
                              style: TextStyle(
                                color: _venueText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: compact ? 5 : 4),
                      if (!compact)
                        Row(
                          children: [
                            if (priceLabel != 'Price not listed')
                              Flexible(
                                child: AppText(
                                  priceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (priceLabel != 'Price not listed' &&
                                category.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 3,
                                  color: _venueMuted,
                                ),
                              ),
                            if (category.isNotEmpty)
                              Expanded(
                                child: AppText(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            AppText(
                              '$heartCount',
                              key: ValueKey(
                                'news-feed-mini-heart-count-$identifier',
                              ),
                              style: TextStyle(
                                color: _venueMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (compact) ...[
                        const SizedBox(height: 4),
                        Row(
                          key: ValueKey(
                            'news-feed-$compactPrefix-category-price-$identifier',
                          ),
                          children: [
                            Expanded(
                              child: AppText(
                                category.isNotEmpty ? category : 'Venue',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _venueMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 76,
                              child: AppText(
                                priceLabel,
                                key: ValueKey(
                                  'news-feed-$compactPrefix-price-$identifier',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: _venuePrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (section == 'most-visited' || visitCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: _venueMint,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: AppText(
                                _venueVisitCountLabel(visitCount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _venueText,
                                  fontSize: compact ? 9 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (address.isNotEmpty || distance != null)
                        Padding(
                          key: compact
                              ? ValueKey(
                                  'news-feed-popular-location-heart-$identifier',
                                )
                              : null,
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              if (compact) ...[
                                Icon(
                                  Icons.location_on_outlined,
                                  color: _venueMuted,
                                  size: 11,
                                ),
                                const SizedBox(width: 2),
                              ],
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
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (compact) ...[
                                SizedBox(
                                  width: 76,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Color(0xFFE86D82),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      AppText(
                                        '$heartCount',
                                        key: ValueKey(
                                          'news-feed-mini-heart-count-$identifier',
                                        ),
                                        style: TextStyle(
                                          color: _venueMuted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (todayStatus != null && !unavailable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                todayStatus == 'Open today'
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                color: todayStatus == 'Open today'
                                    ? _venueMint
                                    : _venueMuted,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              AppText(
                                todayStatus,
                                style: TextStyle(
                                  color: todayStatus == 'Open today'
                                      ? _venueMint
                                      : _venueMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: compact ? 6 : 8),
                      SizedBox(
                        width: double.infinity,
                        height: compact ? 36 : 40,
                        child: FilledButton.icon(
                          key: ValueKey('news-feed-$idPrefix-book-$identifier'),
                          onPressed: unavailable
                              ? null
                              : () => _openBookingType(post),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                          ),
                          label: AppText(
                            unavailable
                                ? 'Currently unavailable'
                                : _venueBookingActionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            localize: true,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _venuePrimary,
                            foregroundColor: AppColors.contrastingForeground(
                              _venuePrimary,
                            ),
                            disabledBackgroundColor: _venueOutline,
                            disabledForegroundColor: _venueMuted,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 5 : 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
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

  Widget _miniImage(String value) =>
      _feedImage(value, fit: BoxFit.cover, fallback: _miniImageFallback());

  Widget _miniImageFallback() => ColoredBox(
    color: _venueSurface,
    child: Center(
      child: Icon(Icons.storefront_rounded, color: _venuePrimary, size: 30),
    ),
  );
}

class _VenueImageCarousel extends StatefulWidget {
  const _VenueImageCarousel({
    required this.images,
    required this.initialIndex,
    required this.dotKey,
    required this.onIndexChanged,
    required this.imageBuilder,
    this.activeDotColor = Colors.white,
    this.dotBottom = 11,
  });

  final List<String> images;
  final int initialIndex;
  final ValueKey<String> Function(int index) dotKey;
  final ValueChanged<int> onIndexChanged;
  final Widget Function(String image) imageBuilder;
  final Color activeDotColor;
  final double dotBottom;

  @override
  State<_VenueImageCarousel> createState() => _VenueImageCarouselState();
}

class _VenueImageCarouselState extends State<_VenueImageCarousel>
    with WidgetsBindingObserver {
  static const _changeInterval = Duration(seconds: 5);

  Timer? _timer;
  late final PageController _pageController;
  late int _index;
  var _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant _VenueImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.images, widget.images)) {
      _index = widget.initialIndex.clamp(0, widget.images.length - 1);
      if (_pageController.hasClients &&
          _pageController.page?.round() != _index) {
        _pageController.jumpToPage(_index);
      }
    }
    if (oldWidget.images.length != widget.images.length) {
      _timer?.cancel();
      _timer = null;
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (widget.images.length < 2 ||
        _timer != null ||
        (lifecycleState != null &&
            lifecycleState != AppLifecycleState.resumed)) {
      return;
    }
    _timer = Timer.periodic(_changeInterval, (_) {
      if (!mounted || !_tickerEnabled) return;
      _selectIndex((_index + 1) % widget.images.length);
    });
  }

  void _selectIndex(int index) {
    if (index == _index || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _startTimer();
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    widget.onIndexChanged(index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        clipBehavior: Clip.hardEdge,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) =>
            SizedBox.expand(child: widget.imageBuilder(widget.images[index])),
      ),
      if (widget.images.length > 1)
        Positioned(
          bottom: widget.dotBottom,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.images.length; index++) ...[
                if (index > 0) const SizedBox(width: 5),
                GestureDetector(
                  key: widget.dotKey(index),
                  onTap: () {
                    _restartTimer();
                    _selectIndex(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: index == _index ? 15 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _index
                          ? widget.activeDotColor
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
  );
}
