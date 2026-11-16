part of 'news_feed.dart';

extension _NewsFeedMap on _NewsFeedPageState {
  Widget _courtMapHeaderControl() => IconButton(
    key: const ValueKey('news-feed-toggle-court-map'),
    tooltip: _courtMapExpanded
        ? 'Hide ${widget.venueNoun == 'courts' ? 'court' : 'venue'} map'
        : 'Show ${widget.venueNoun} on map',
    onPressed: () => _updateState(() => _courtMapExpanded = !_courtMapExpanded),
    icon: AnimatedRotation(
      turns: _courtMapExpanded ? .5 : 0,
      duration: const Duration(milliseconds: 180),
      child: const Icon(Icons.map_outlined),
    ),
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
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

  Future<void> _maybeRequestLocationForDiscovery() async {
    if (_userPosition != null || _locationLoading) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _updateState(() => _userPosition = position);
    } on Exception {
      // Keep browsing usable even when location cannot be obtained.
    }
  }

  Future<void> _useMyLocation({required VoidCallback refreshSheet}) async {
    _updateState(() => _locationLoading = true);
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
      _updateState(() => _userPosition = position);
      refreshSheet();
      _showLocationMessage(
        '${widget.venueNoun[0].toUpperCase()}${widget.venueNoun.substring(1)} are now ordered nearest to your location.',
      );
    } on Exception catch (error) {
      _showLocationMessage('Could not get your location: $error');
    } finally {
      if (mounted) {
        _updateState(() => _locationLoading = false);
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
}
