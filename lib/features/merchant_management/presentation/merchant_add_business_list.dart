part of 'merchant_add_page.dart';

extension _MerchantAddBusinessList on MerchantAddPageState {
  List<Map<String, dynamic>> get _filteredBusinesses {
    return widget.businesses
        .where(
          (business) =>
              _hasCompleteNewsCard(business) &&
              _matchesBusinessFilters(business),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredNewsCardBusinesses {
    return widget.businesses.where(_matchesBusinessFilters).toList();
  }

  bool _matchesBusinessFilters(Map<String, dynamic> business) {
    final type =
        '${business['businessType'] ?? business['business_type'] ?? ''}';
    if (_selectedBusinessType != 'All' && type != _selectedBusinessType) {
      return false;
    }
    final query = _businessSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchableValues = [
      business['name'],
      type,
      business['category'],
      business['address'],
    ];
    return searchableValues.any(
      (value) => '${value ?? ''}'.toLowerCase().contains(query),
    );
  }

  bool _hasCompleteNewsCard(Map<String, dynamic> business) {
    final id = _businessId(business);
    if (id == null) return false;
    return _newsPosts.any((post) {
      final imageUrl =
          post['imageUrl'] ??
          post['image_url'] ??
          post['businessImageUrl'] ??
          business['imageUrl'] ??
          business['image_url'];
      final image = '$imageUrl'.trim();
      return _postBusinessId(post) == id &&
          '${post['status'] ?? ''}'.toLowerCase() == 'published' &&
          '${post['body'] ?? ''}'.trim().isNotEmpty &&
          '${post['title'] ?? ''}'.trim().isNotEmpty &&
          image.isNotEmpty &&
          image != 'null';
    });
  }

  Widget _businessFilterAndSearch() {
    const businessTypes = ['All', 'Sports', 'Event', 'Fitness & Wellness'];
    return Row(
      children: [
        SizedBox(
          width: 128,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedBusinessType,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: _addLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: _addLine),
              ),
            ),
            style: TextStyle(
              color: _addInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            items: [
              for (final type in businessTypes)
                DropdownMenuItem(
                  value: type,
                  child: AppText(
                    type == 'Fitness & Wellness' ? 'Fitness' : type,
                  ),
                ),
            ],
            onChanged: (type) {
              if (type != null) {
                _updateAddPageState(() => _selectedBusinessType = type);
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _businessSearchController,
              onChanged: (query) => _updateAddPageState(
                () => _businessSearchQuery = query.trim().toLowerCase(),
              ),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: appLanguageText(
                  'Search businesses',
                  'Search businesses',
                ),
                hintStyle: TextStyle(fontSize: 12, color: _addMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: _businessSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: appLanguageText(
                          'Clear search',
                          'Clear search',
                        ),
                        onPressed: () {
                          _businessSearchController.clear();
                          _updateAddPageState(() => _businessSearchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                        visualDensity: VisualDensity.compact,
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: _addLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: _addLine),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final id = _businessId(business);
    final enabled =
        business['enabled'] != false &&
        business['enabled'] != 0 &&
        business['enabled'] != '0';
    final image = _businessPrimaryImage(business);
    final businessLogo =
        business['businessLogoUrl'] ?? business['business_logo_url'];
    final name = business['name'] as String? ?? 'Unnamed business';
    final type = business['businessType'] as String? ?? 'Booking';
    final category = business['category'] as String? ?? '';
    final address = business['address'] as String? ?? '';
    final facility = business['facilityType'] as String? ?? '';
    final hours = business['hours'] as String? ?? '';
    final availability = business['availability'] as String? ?? '';
    final includedPlayerLimit =
        int.tryParse(
          '${business['includedPlayers'] ?? business['included_players'] ?? 0}',
        ) ??
        0;
    final extraPlayerFeeValue =
        business['additionalPlayerFee'] ?? business['additional_player_fee'];
    final extraPlayerFee = extraPlayerFeeValue is num
        ? extraPlayerFeeValue.toDouble()
        : double.tryParse('$extraPlayerFeeValue') ?? 0;
    final ratePeriods = _businessRatePeriods(business);
    final details = business['details'] as String? ?? '';
    final priceText = _formatPrice(
      type == 'Event'
          ? business['eventFee'] ??
                business['event_fee'] ??
                business['pricePerHour'] ??
                business['price_per_hour']
          : business['pricePerHour'] ??
                business['price_per_hour'] ??
                business['price'] ??
                business['hourlyRate'],
      hourly: type != 'Event',
    );
    final tags = _businessTags(
      business['tags'] ?? business['amenities'] ?? business['amenities_json'],
    );
    return Card(
      elevation: AppCardStyles.elevation,
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      shape: AppCardStyles.merchantShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppCardStyles.merchantImageHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image == null || image.isEmpty
                    ? ColoredBox(
                        color: AppColors.softOrange,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: _addOrange,
                        ),
                      )
                    : Image(image: _imageProvider(image)!, fit: BoxFit.cover),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.imageBottomFade,
                      ),
                    ),
                  ),
                ),
                if (businessLogo is String && businessLogo.trim().isNotEmpty)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image(
                          image:
                              _safeImageProvider(businessLogo) ??
                              const AssetImage('assets/court/pickle-court.jpg'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.storefront_rounded, color: _addMuted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _addInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (address.isNotEmpty)
                  _detail(Icons.location_on_outlined, address),
                if (facility.isNotEmpty)
                  _detail(Icons.business_outlined, 'Facility: $facility'),
                if (type == 'Sports' && category.isNotEmpty)
                  _detail(Icons.sports_rounded, 'Sport: $category'),
                if (type == 'Sports' && extraPlayerFee > 0)
                  _detail(
                    Icons.groups_rounded,
                    'Includes $includedPlayerLimit players; '
                    '\u{20B1} ${extraPlayerFee.toStringAsFixed(2)} '
                    'per extra player',
                  ),
                if (type == 'Event' && category.isNotEmpty)
                  _detail(Icons.celebration_outlined, 'Event type: $category'),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _detail(Icons.fitness_center_rounded, 'Class: $category'),
                if (type == 'Fitness & Wellness') _fitnessPlanSummary(business),
                if (hours.isNotEmpty)
                  _detail(Icons.access_time_rounded, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _detail(Icons.check_circle_outline, availability),
                if (ratePeriods.isNotEmpty)
                  _detail(
                    Icons.payments_outlined,
                    'Special rates: ${_formatRatePeriods(ratePeriods)}',
                  ),
                if (details.isNotEmpty) _detail(Icons.info_outline, details),
                const SizedBox(height: 6),
                _priceBox(
                  ratePeriods.isNotEmpty
                      ? 'See special rates above'
                      : priceText.isEmpty
                      ? 'Price not set'
                      : priceText,
                  label: type == 'Event' ? 'Event fee' : 'Price / hour',
                  hasRatePeriods: ratePeriods.isNotEmpty,
                ),
                const SizedBox(height: 6),
                AppText(
                  'Amenities',
                  style: TextStyle(
                    color: _addMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                if (tags.isEmpty)
                  AppText(
                    'No amenities listed',
                    style: TextStyle(color: _addMuted, fontSize: 12),
                    localize: true,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final tag in tags) _tag(null, tag)],
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: id == null
                            ? null
                            : () => _openForm(business),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const AppText('Edit', localize: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: id == null
                            ? null
                            : () => _toggleBusiness(business, enabled),
                        icon: Icon(
                          enabled
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 17,
                        ),
                        label: AppText(enabled ? 'Disable' : 'Enable'),
                        style: FilledButton.styleFrom(
                          backgroundColor: enabled
                              ? _addNavy
                              : AppColors.success,
                          foregroundColor: AppColors.contrastingForeground(
                            enabled ? _addNavy : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _confirmDeleteBusiness(id, name),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const AppText('Delete business', localize: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorText,
                      side: BorderSide(color: AppColors.errorBorder),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fitnessPlanSummary(Map<String, dynamic> business) {
    dynamic readList(String camelCase, String snakeCase) {
      final raw = business[camelCase] ?? business[snakeCase];
      if (raw is List) return raw;
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded;
        } on FormatException {
          return const [];
        }
      }
      return const [];
    }

    final categories = readList(
      'fitnessCategories',
      'fitness_categories_json',
    ).whereType<Map>().toList();
    final coaches = readList(
      'fitnessCoaches',
      'fitness_coaches_json',
    ).whereType<Map>().toList();
    if (categories.isEmpty && coaches.isEmpty) {
      return const SizedBox.shrink();
    }
    String money(dynamic value) {
      final amount = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return amount == null ? 'Not set' : '₱${amount.toStringAsFixed(2)}';
    }

    String yearlyOffer(Map item) => switch (item['yearlyDiscountType']) {
      'freeMonths' => ' · ${item['yearlyDiscountValue'] ?? ''} free month(s)',
      'percentage' => ' · ${item['yearlyDiscountValue'] ?? ''}% off yearly',
      _ => '',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: _addLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in categories) ...[
            AppText(
              '${item['category'] ?? 'Fitness'} · '
              'Session ${money(item['sessionPrice'])} · '
              'Monthly ${money(item['monthlyPrice'])} · '
              'Yearly ${money(item['yearlyPrice'])}'
              '${yearlyOffer(item)}',
              style: TextStyle(
                color: _addInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              localize: true,
            ),
            if (item != categories.last) const SizedBox(height: 6),
          ],
          if (coaches.isNotEmpty) ...[
            if (categories.isNotEmpty) const SizedBox(height: 6),
            for (final coach in coaches)
              AppText(
                'Coach ${coach['name'] ?? ''} · '
                '${money(coach['monthlyPrice'])} / month',
                style: TextStyle(color: _addMuted, fontSize: 11),
                localize: true,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleBusiness(
    Map<String, dynamic> business,
    bool enabled,
  ) async {
    final id = _businessId(business);
    if (id == null) {
      return;
    }
    try {
      final token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      await _api.setMerchantBusinessEnabled(
        token: token,
        id: id,
        enabled: !enabled,
      );
      await widget.onBusinessesChanged();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              'Could not update business status: $error',
              localize: true,
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteBusiness(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Delete business?', localize: true),
        content: AppText(
          'This will permanently delete "$name" and its venue details. '
          'This action cannot be undone.',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel', localize: true),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Delete', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      await _api.deleteMerchantBusiness(token: token, id: id);
      await widget.onBusinessesChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('"$name" was deleted.', localize: true)),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText('Could not delete business: $error', localize: true),
        ),
      );
    }
  }
}
