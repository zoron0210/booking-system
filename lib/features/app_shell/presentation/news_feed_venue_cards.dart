part of 'news_feed.dart';

extension _NewsFeedVenueCards on _NewsFeedPageState {
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
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. $_venueBookingActionLabel.',
      onTap: unavailable ? null : () => _openBookingType(post),
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
                          Semantics(
                            button: true,
                            label: isSaved
                                ? 'Remove saved venue'
                                : 'Save venue',
                            child: IconButton(
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
                                        'Review ${_venueRatingLabel(rating, reviewCount)} · ${_venueReviewCountLabel(reviewCount)}',
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
                          Semantics(
                            button: true,
                            label: hearted ? 'Remove heart' : 'Heart venue',
                            child: IconButton(
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
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: FilledButton.icon(
                          key: ValueKey(
                            'news-feed-list-book-${_venueIdentifier(post)}',
                          ),
                          onPressed: unavailable
                              ? null
                              : () => _openBookingType(post),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                          ),
                          label: AppText(
                            unavailable
                                ? 'Currently unavailable'
                                : _venueBookingActionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            localize: true,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
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
    final logo = _stringValue([
      post['businessLogoUrl'],
      post['business_logo_url'],
      business['businessLogoUrl'],
      business['business_logo_url'],
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
    final images = _imageListValue([
      post['imageUrls'],
      post['image_urls'],
      post['imageUrl'],
      post['image_url'],
      post['businessImageUrl'],
      post['business_image_url'],
      business['imageUrls'],
      business['image_urls'],
      business['imageUrl'],
      business['image_url'],
      post['images'],
      business['images'],
    ]);
    final businessId = int.tryParse('${post['businessId']}');
    final identifier = _venueIdentifier(post);
    final imageIndex = (_featuredImageIndexes[identifier] ?? 0).clamp(
      0,
      images.isEmpty ? 0 : images.length - 1,
    );
    final rating = _number(post['averageRating']);
    final reviewCount = _number(post['reviewCount']).toInt();
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final price = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final isSaved = _savedKeys.contains(_postSaveKey(post));
    final distance = _distanceLabel(post);
    final openToday = _isVenueOpenToday(post);
    final verified =
        post['isVerified'] == true ||
        post['verified'] == true ||
        business['isVerified'] == true ||
        business['verified'] == true;
    final location = [if (address.isNotEmpty) address, ?distance].join(' · ');

    return Semantics(
      key: ValueKey('news-feed-mini-$identifier'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. $_venueBookingActionLabel.',
      onTap: unavailable ? null : () => _openBookingType(post),
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
                    if (images.isEmpty)
                      _miniImageFallback()
                    else
                      _VenueImageCarousel(
                        images: images,
                        initialIndex: imageIndex,
                        dotKey: (index) => ValueKey(
                          'news-feed-listed-image-dot-$identifier-$index',
                        ),
                        onIndexChanged: (index) => _updateState(
                          () => _featuredImageIndexes[identifier] = index,
                        ),
                        imageBuilder: _miniImage,
                        activeDotColor: _venuePrimary,
                        dotBottom: 10,
                      ),
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
                    if (unavailable || openToday)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _availabilityImageTag(
                          unavailable ? 'Unavailable' : 'Open today',
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox(
                            key: ValueKey('news-feed-listed-logo-$identifier'),
                            width: 36,
                            height: 36,
                            child: logo.isEmpty
                                ? Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _venueSurface,
                                      border: Border.all(color: _venuePrimary),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: AppText(
                                      name
                                          .split(RegExp(r'\s+'))
                                          .where((part) => part.isNotEmpty)
                                          .take(2)
                                          .map((part) => part[0].toUpperCase())
                                          .join(),
                                      style: TextStyle(
                                        color: _venuePrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : _miniImage(logo),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            'Review ${_venueRatingLabel(rating, reviewCount)}',
                            style: TextStyle(
                              color: _venueText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              _venueReviewCountLabel(reviewCount),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton.icon(
                        key: ValueKey('news-feed-list-book-$identifier'),
                        onPressed: unavailable
                            ? null
                            : () => _openBookingType(post),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: AppText(
                          unavailable
                              ? 'Currently unavailable'
                              : _venueBookingActionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          localize: true,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
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
  }) => Semantics(
    button: true,
    label: tooltip,
    child: IconButton(
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
        color: selected
            ? selectedColor ?? const Color(0xFFFF6B82)
            : _venueMuted,
        size: 17,
      ),
    ),
  );

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
  }) {
    final titleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: AppText(
                title,
                style: AppTypography.sectionTitle.copyWith(color: _venueText),
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
      ],
    );
    final seeAllButton = IconButton(
      key: ValueKey(
        'news-feed-see-all-${title.toLowerCase().replaceAll(' ', '-')}',
      ),
      tooltip:
          'See all ${sectionPosts.length} ${sectionPosts.length == 1 ? 'venue' : 'venues'}',
      onPressed: () => _openAllVenues(title, sectionPosts),
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: _venueSurface,
        foregroundColor: _venueText,
        shape: const CircleBorder(),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppResponsive.compactPhone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleContent,
              Align(alignment: Alignment.centerRight, child: seeAllButton),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleContent),
            seeAllButton,
          ],
        );
      },
    );
  }

  void _openAllVenues(String title, List<Map<String, dynamic>> sectionPosts) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => AllVenuesPage(
          title: title,
          posts: sectionPosts,
          cardBuilder: _listedVenueCard,
          initialUserPosition: widget.initialUserPosition ?? _userPosition,
          categoryFilterLabel: widget.categoryFilterLabel,
          categoryAllLabel: _categoryAllLabel,
          facilityFilterLabel: widget.facilityFilterLabel,
          popularHeading: widget.businessType == 'Sports'
              ? 'Courts with the most hearts'
              : '${widget.pageTitle} venues with the most hearts',
          ratedHeading: widget.businessType == 'Sports'
              ? 'Courts with the highest ratings'
              : '${widget.pageTitle} venues with the highest ratings',
          visitedHeading: widget.businessType == 'Sports'
              ? 'Courts with the most completed visits'
              : '${widget.pageTitle} venues with the most completed visits',
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
    required String badgeLabel,
  }) => Padding(
    key: ValueKey('news-feed-$identifier-section'),
    padding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final legacyFeaturedLayout =
            BusinessTypeParser.parse(widget.businessType) ==
            BusinessType.unknown;
        final cardWidth = legacyFeaturedLayout
            ? constraints.maxWidth
            : ((constraints.maxWidth - 14) / 2).clamp(0.0, 320.0);
        final compactCards = !legacyFeaturedLayout && cardWidth < 200;
        final sectionHeight = legacyFeaturedLayout
            ? 430.0
            : compactCards
            ? 290.0
            : 326.0;
        return SizedBox(
          height: sectionHeight,
          child: ListView.separated(
            key: ValueKey('news-feed-$identifier-scroll'),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, index) => SizedBox(
              key: ValueKey(
                'news-feed-${identifier == 'popular' ? 'most-popular' : identifier}-card-${_venueIdentifier(posts[index])}',
              ),
              width: cardWidth,
              child: legacyFeaturedLayout
                  ? _featuredVenueCard(posts[index], section: identifier)
                  : _miniVenueCard(
                      posts[index],
                      section: identifier,
                      badgeLabel: badgeLabel,
                      compact: cardWidth < 200,
                    ),
            ),
          ),
        );
      },
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

  List<
    ({
      String city,
      List<Map<String, dynamic>> courts,
      List<Map<String, dynamic>> weekendCourts,
    })
  >
  _courtLocationGroups(List<Map<String, dynamic>> posts) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final labels = <String, String>{};
    for (final post in posts) {
      final city = _venueCityLabel(post);
      if (city.isEmpty) continue;
      final key = city.toLowerCase();
      labels.putIfAbsent(key, () => city);
      grouped.putIfAbsent(key, () => []).add(post);
    }

    final weekendDays = {DateTime.saturday, DateTime.sunday};
    final groups = grouped.entries.map((entry) {
      final courts = entry.value;
      final weekendCourts = courts.where((post) {
        final scheduledDays = _venueScheduledDays(post);
        return scheduledDays != null &&
            scheduledDays.intersection(weekendDays).isNotEmpty;
      }).toList();
      return (
        city: labels[entry.key]!,
        courts: courts,
        weekendCourts: weekendCourts,
      );
    }).toList()..sort((a, b) => a.city.compareTo(b.city));
    return groups;
  }

  String _venueCityLabel(Map<String, dynamic> post) {
    final business = post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : const <String, dynamic>{};
    final city = _stringValue([
      post['city'],
      post['municipality'],
      post['town'],
      business['city'],
      business['municipality'],
      business['town'],
    ]);
    if (city.isNotEmpty) return city;

    final address = _stringValue([
      post['address'],
      post['location'],
      business['address'],
      business['location'],
    ]);
    final segments = address
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return '';
    for (final segment in segments.reversed) {
      if (RegExp(
        r'\b(city|municipality|town)\b',
        caseSensitive: false,
      ).hasMatch(segment)) {
        return segment;
      }
    }
    return segments.last;
  }

  String _venueSectionSlug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  int _postVisitCount(Map<String, dynamic> post) {
    final businessValue = post['business'];
    final business = businessValue is Map
        ? Map<String, dynamic>.from(businessValue)
        : const <String, dynamic>{};
    final candidates = [
      post['visitCount'],
      post['visit_count'],
      post['completedVisitCount'],
      post['completed_visit_count'],
      business['visitCount'],
      business['visit_count'],
      business['completedVisitCount'],
      business['completed_visit_count'],
    ];
    for (final candidate in candidates) {
      if (candidate != null) return _number(candidate).toInt();
    }
    return 0;
  }

  String _postHeartKey(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    return businessId != null && businessId > 0 ? '$businessId' : '';
  }

  int _postHeartCount(Map<String, dynamic> post) =>
      _heartCounts[_postHeartKey(post)] ?? _number(post['heartCount']).toInt();
}
