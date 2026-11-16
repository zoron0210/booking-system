part of 'news_feed.dart';

extension _NewsFeedFilters on _NewsFeedPageState {
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
                                      _updateState(() {
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
                                              _updateState(
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
                                      _updateState(() => _feedArea = value);
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
                                            _updateState(
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
                                            _updateState(() {
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
                                            _updateState(
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
                                        'Open today',
                                        'Open 24 hours',
                                      ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-availability-$value',
                                          ),
                                          label: AppText(value),
                                          selected: _feedAvailability == value,
                                          onSelected: (_) {
                                            _updateState(
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
                                      _updateState(
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
                                      _updateState(
                                        () => _feedPriceSort = value,
                                      );
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
}
