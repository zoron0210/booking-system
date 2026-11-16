part of 'news_feed.dart';

extension _NewsFeedFeaturedCards on _NewsFeedPageState {
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
    final visitCount = _postVisitCount(post);
    final price = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final isSaved = _savedKeys.contains(_postSaveKey(post));
    final openToday = _isVenueOpenToday(post);
    final availableLabel = openToday ? 'Open today' : '';
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
    final bookingLabel = _venueBookingActionLabel;

    return Semantics(
      key: ValueKey('news-feed-mini-$identifier'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. ${section == 'popular' ? 'Popular' : 'Highest rated'} venue. $bookingLabel.',
      onTap: unavailable ? null : () => _openBookingType(post),
      child: Material(
        key: ValueKey(cardKey),
        color: _venueCard,
        elevation: 3,
        shadowColor: _venuePrimary.withValues(alpha: .12),
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unavailable ? null : () => _openBookingType(post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    images.isEmpty
                        ? _miniImageFallback()
                        : _VenueImageCarousel(
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
                    if (section == 'popular')
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          key: ValueKey(
                            'news-feed-featured-highlight-$identifier',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFFD58A13),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              AppText(
                                'TOP PICK',
                                style: TextStyle(
                                  color: _venueText,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .6,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox(
                            key: ValueKey(
                              'news-feed-featured-logo-$identifier',
                            ),
                            width: 34,
                            height: 34,
                            child: logo.isEmpty
                                ? Container(
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
                                  )
                                : _miniImage(logo),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                                    _venueRatingLabel(rating, reviewCount),
                                    style: TextStyle(
                                      color: _venueText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: AppText(
                                      '(${_venueReviewCountLabel(reviewCount)})',
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
                        if (section == 'most-visited' || visitCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _venueSurface,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: Color(0xFF2AA6A6),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                AppText(
                                  _venueVisitCountLabel(visitCount),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _venueText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          localize: true,
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
    bool compact = false,
  }) => Semantics(
    button: true,
    label: tooltip,
    child: IconButton(
      key: ValueKey(legacyKey ?? key),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: BoxConstraints.tightFor(
        width: compact ? 40 : 36,
        height: compact ? 40 : 36,
      ),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: _venueCanvas.withValues(alpha: .92),
        foregroundColor: color,
        shape: const CircleBorder(),
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
        visualDensity: compact ? VisualDensity.compact : null,
      ),
      icon: Icon(icon, size: compact ? 15 : 18),
    ),
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
}
