part of 'merchant_dashboard.dart';

extension _MerchantDashboardBusinessCards on _MerchantDashboardPageState {
  Widget _merchantBusinessCard(Map<String, dynamic> business) {
    final images = _businessImages(business);
    final name = _businessText(business, ['name']) ?? 'Unnamed venue';
    final type =
        _businessText(business, ['businessType', 'business_type']) ?? 'Booking';
    final category = _businessText(business, ['category']) ?? '';
    final address = _businessText(business, ['address']) ?? '';
    final facility =
        _businessText(business, ['facilityType', 'facility_type']) ?? '';
    final details = _businessText(business, ['details']) ?? '';
    final hours = _businessValue(business, ['hours', 'openingHours']);
    final availability = _businessValue(business, ['availability']);
    final courts = _businessValue(business, ['courts', 'courtCount']);
    final price = _hourlyPrice(business);
    final ratePeriods = _businessRatePeriods(business);
    final sessions = _businessValue(business, ['sessions', 'session']);
    final tags = _businessTags(business);

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
                images.isEmpty
                    ? ColoredBox(
                        color: AppColors.softOrange,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: _merchantOrange,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _showImageGallery(context, images),
                        child: _imageCarousel(images),
                      ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _statusPill(isLive: _isLiveOnApp(business)),
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
                    color: _merchantInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!_isLiveOnApp(business))
                  _businessDetail(
                    Icons.info_outline_rounded,
                    'Not live on the app — complete and publish a News Card.',
                  ),
                if (address.isNotEmpty)
                  _businessDetail(Icons.location_on_outlined, address),
                if (facility.isNotEmpty)
                  _businessDetail(
                    Icons.business_outlined,
                    'Facility: $facility',
                  ),
                if (type == 'Sports' && category.isNotEmpty)
                  _businessDetail(Icons.sports_rounded, 'Sport: $category'),
                if (type == 'Event' && category.isNotEmpty)
                  _businessDetail(
                    Icons.celebration_outlined,
                    'Event type: $category',
                  ),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _businessDetail(
                    Icons.fitness_center_rounded,
                    'Class: $category',
                  ),
                if (courts.isNotEmpty)
                  _businessDetail(Icons.grid_3x3, 'Courts: $courts'),
                if (sessions.isNotEmpty)
                  _businessDetail(
                    Icons.event_available_outlined,
                    'Sessions: $sessions',
                  ),
                if (hours.isNotEmpty)
                  _businessDetail(Icons.access_time, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _businessDetail(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                if (ratePeriods.isNotEmpty)
                  _businessDetail(
                    Icons.payments_outlined,
                    'Special rates: ${_formatRatePeriods(ratePeriods)}',
                  ),
                if (details.isNotEmpty)
                  _businessDetail(Icons.info_outline, details),
                const SizedBox(height: 6),
                _priceBox(
                  type,
                  ratePeriods.isNotEmpty
                      ? 'See special rates above'
                      : price.isEmpty
                      ? 'Price not set'
                      : price,
                  hasRatePeriods: ratePeriods.isNotEmpty,
                ),
                const SizedBox(height: 6),
                AppText(
                  'Amenities',
                  style: TextStyle(
                    color: _merchantMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                if (tags.isEmpty)
                  AppText(
                    'No amenities listed',
                    style: TextStyle(color: _merchantMuted, fontSize: 12),
                    localize: true,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final tag in tags) _tag(tag)],
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showMessage('Opening $name'),
                        icon: const Icon(Icons.language, size: 15),
                        label: const AppText('Visit', localize: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _merchantNavy,
                          side: const BorderSide(color: _merchantNavy),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _showMessage('Booking $name is ready.'),
                        icon: const Icon(Icons.calendar_month, size: 15),
                        label: const AppText('Book now', localize: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _merchantOrange,
                          foregroundColor: AppColors.onAccent,
                          minimumSize: const Size(0, 36),
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
    );
  }

  String _businessValue(Map<String, dynamic> business, List<String> keys) {
    for (final key in keys) {
      final value = business[key] ?? business[_snakeCase(key)];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return '';
  }

  String _hourlyPrice(Map<String, dynamic> business) {
    final isEvent =
        business['businessType'] == 'Event' ||
        business['business_type'] == 'Event';
    final value = isEvent
        ? (business['eventFee'] ??
              business['event_fee'] ??
              business['pricePerHour'] ??
              business['price_per_hour'])
        : business['pricePerHour'] ??
              business['price_per_hour'] ??
              business['price'] ??
              business['hourlyRate'];
    final price = value is num ? value.toDouble() : double.tryParse('$value');
    if (price == null || price <= 0) return '';
    final formatted = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return isEvent ? '₱$formatted / event' : '₱$formatted / hr';
  }

  List<Map<String, dynamic>> _businessRatePeriods(
    Map<String, dynamic> business,
  ) {
    final value = business['ratePeriods'] ?? business['rate_periods'];
    dynamic decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return [];
      }
    }
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((period) => Map<String, dynamic>.from(period))
        .where(
          (period) =>
              '${period['start'] ?? ''}'.trim().isNotEmpty &&
              '${period['end'] ?? ''}'.trim().isNotEmpty,
        )
        .toList();
  }

  String _formatRatePeriods(List<Map<String, dynamic>> periods) => periods
      .map((period) {
        final start = period['start'];
        final end = period['end'];
        final value = period['pricePerHour'] ?? period['price_per_hour'];
        final price = value is num
            ? value.toDouble()
            : double.tryParse('$value');
        final formattedPrice = price == null
            ? ''
            : price == price.roundToDouble()
            ? '₱${price.toStringAsFixed(0)}'
            : '₱${price.toStringAsFixed(2)}';
        return '$start - $end${formattedPrice.isEmpty ? '' : ' ($formattedPrice / hr)'}';
      })
      .join(', ');

  List<String> _businessTags(Map<String, dynamic> business) {
    final value =
        business['tags'] ?? business['amenities'] ?? business['amenities_json'];
    if (value is List) {
      return value.whereType<String>().where((tag) => tag.isNotEmpty).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((tag) => tag.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Widget _statusPill({required bool isLive}) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        isLive ? 'LIVE' : 'NOT LIVE',
        style: TextStyle(
          color: isLive ? Colors.green : _merchantOrange,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _priceBox(String type, String price, {bool hasRatePeriods = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: _merchantLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                hasRatePeriods
                    ? 'Rate schedule'
                    : type == 'Fitness & Wellness'
                    ? 'Session price'
                    : type == 'Event'
                    ? 'Event package'
                    : 'Price / hour',
                style: TextStyle(
                  color: _merchantMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppText(
              price,
              style: TextStyle(
                color: _merchantInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _tag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        label,
        style: TextStyle(color: _merchantInk, fontSize: 10),
      ),
    ),
  );

  Widget _businessDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _merchantMuted),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _merchantMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
