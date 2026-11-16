part of 'news_feed.dart';

extension _NewsFeedPosts on _NewsFeedPageState {
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
    final hasRating = rating > 0 && reviews > 0;
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
    final imageHeight = MediaQuery.sizeOf(context).width >= 600
        ? 220.0
        : NewsFeedImageCarousel.cardHeight;
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
                    height: imageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        images.isNotEmpty
                            ? NewsFeedImageCarousel(
                                images: images,
                                height: imageHeight,
                                imageBuilder: (value) => _feedImage(
                                  value,
                                  height: imageHeight,
                                  fit: BoxFit.cover,
                                  fallback: _imageFallback(),
                                ),
                              )
                            : image != null && image.isNotEmpty
                            ? _image(image, height: imageHeight)
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
                        Semantics(
                          button: true,
                          label: isSaved ? 'Remove from Saved' : 'Save venue',
                          child: IconButton(
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
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 38,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                button: true,
                                label: isHearted ? 'Remove heart' : 'Heart venue',
                                child: IconButton(
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
                        AppRatingStars(
                          rating: hasRating ? rating : 0,
                          size: 16,
                        ),
                        AppText(
                          hasRating ? rating.toStringAsFixed(1) : 'New',
                          localize: true,
                          style: TextStyle(
                            color: _newsInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        AppText(
                          !hasRating
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
                            label: AppText(
                              _venueBookingActionLabel,
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
    final businessType = BusinessTypeParser.parse(
      post['businessType'] ?? business['businessType'] ?? widget.businessType,
    );
    if (businessType == BusinessType.fitness) {
      final fitnessPrice = _fitnessPriceLabel(post, business);
      if (fitnessPrice != null) return fitnessPrice;
    }
    final isEvent = businessType == BusinessType.event;

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

  String? _fitnessPriceLabel(
    Map<String, dynamic> post,
    Map<String, dynamic> business,
  ) {
    final categories = _stringMapList(
      post['fitnessCategories'] ??
          post['fitness_categories_json'] ??
          business['fitnessCategories'] ??
          business['fitness_categories_json'],
    );
    for (final item in categories) {
      for (final (plan, unit) in const [
        ('session', 'session'),
        ('monthly', 'month'),
        ('yearly', 'year'),
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
        if (amount > 0) {
          return '\u{20B1} ${amount.toStringAsFixed(2)} / $unit';
        }
      }
    }

    final coaches = _stringMapList(
      post['fitnessCoaches'] ??
          post['fitness_coaches_json'] ??
          business['fitnessCoaches'] ??
          business['fitness_coaches_json'],
    );
    for (final coach in coaches) {
      final amount = _number(coach['monthlyPrice']);
      if (amount > 0) {
        return '\u{20B1} ${amount.toStringAsFixed(2)} / month';
      }
    }
    return null;
  }

  String get _venueBookingActionLabel =>
      switch (BusinessTypeParser.parse(widget.businessType)) {
        BusinessType.sports => 'Check availability',
        BusinessType.event => 'View event options',
        BusinessType.fitness => 'View sessions',
        BusinessType.unknown => 'View venue & times',
      };

  String _venueRatingLabel(double rating, int reviewCount) =>
      rating > 0 && reviewCount > 0 ? rating.toStringAsFixed(1) : 'New';

  String _venueReviewCountLabel(int reviewCount) =>
      '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}';

  String _venueVisitCountLabel(int visitCount) =>
      '$visitCount completed ${visitCount == 1 ? 'visit' : 'visits'}';

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
      final response = await _api.messaging.messageOwner(
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
    _updateState(() {
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
      _updateState(() {
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
    height: NewsFeedImageCarousel.cardHeight,
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

  Widget _image(String value, {required double height}) => _feedImage(
    value,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    fallback: _imageFallback(),
  );

  Widget _feedImage(
    String value, {
    double? width,
    double? height,
    required BoxFit fit,
    required Widget fallback,
  }) {
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator <= 0 || separator >= value.length - 1) return fallback;
      return _AsyncBase64Image(
        encodedData: value.substring(separator + 1),
        width: width,
        height: height,
        fit: fit,
        placeholder: _imageLoadingPlaceholder(),
        fallback: fallback,
      );
    }

    final provider = _imageProvider(value);
    if (provider == null) return fallback;
    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      loadingBuilder: (_, child, progress) => child,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _imageLoadingPlaceholder() => SkeletonPulse(
    child: SizedBox.expand(child: ColoredBox(color: AppColors.surfaceVariant)),
  );

  ImageProvider<Object>? _imageProvider(String value) {
    if (value.startsWith('data:image/')) return null;
    return CachedNetworkImageProvider(value);
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
      final rawBusinessType =
          post['businessType'] ??
          business['businessType'] ??
          post['type'] ??
          business['type'] ??
          widget.businessType;
      final selectedType = BusinessTypeParser.parse(widget.businessType);
      final directBusinessType = BusinessTypeParser.parse(rawBusinessType);
      if (selectedType != BusinessType.unknown &&
          directBusinessType != BusinessType.unknown &&
          directBusinessType != selectedType) {
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

      final fallbackBusiness = {
        'id': businessId,
        'name': post['businessName'] ?? post['name'] ?? 'Venue',
        'businessType': rawBusinessType,
        'category': post['category'],
        'address': post['address'],
        'facilityType': post['facilityType'],
        'latitude': post['latitude'],
        'longitude': post['longitude'],
      };
      final publishedBusinessData = publishedBusiness ?? fallbackBusiness;
      final businessType = BusinessTypeParser.parse(
        publishedBusinessData['businessType'] ??
            rawBusinessType ??
            widget.businessType,
      );
      if (selectedType != BusinessType.unknown &&
          businessType != BusinessType.unknown &&
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
          ...publishedBusinessData,
          'businessName': publishedBusinessData['name'] ?? post['businessName'],
          'category': post['category'] ?? publishedBusinessData['category'],
          'includedPlayers': publishedBusinessData['includedPlayers'],
          'additionalPlayerFee': publishedBusinessData['additionalPlayerFee'],
          'averageRating': post['averageRating'],
          'reviewCount': post['reviewCount'],
          'ratingUserCount': post['ratingUserCount'],
          'heartCount': post['heartCount'],
          'business': publishedBusinessData,
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
                  business: publishedBusinessData,
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
                    business: publishedBusinessData,
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
            primaryActionLabel: 'Choose date & time',
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
      businessLogoUrl: _stringValue([
        post['businessLogoUrl'],
        business['businessLogoUrl'],
        post['business_logo_url'],
        business['business_logo_url'],
      ]),
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
            _updateState(() {
              post['averageRating'] = average;
              post['reviewCount'] = reviewCount;
              post['ratingUserCount'] = ratedUsers;
            });
          },
        ),
      );

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
}
