import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/api_transport.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/business_type.dart';
import 'package:myapp/features/bookings/data/matchmaking_api.dart';
import 'package:myapp/features/bookings/domain/matchmaking_availability.dart';
import 'package:myapp/features/venues/data/venue_api.dart';
import 'package:myapp/features/venues/domain/venue_models.dart';

class MatchmakingHostPage extends StatefulWidget {
  const MatchmakingHostPage({
    super.key,
    required this.api,
    required this.token,
    this.initialVenueId,
  });

  final ApiTransport api;
  final String token;
  final int? initialVenueId;

  @override
  State<MatchmakingHostPage> createState() => _MatchmakingHostPageState();
}

class _MatchmakingHostPageState extends State<MatchmakingHostPage> {
  late final Future<List<VenueBusiness>> _venuesFuture;
  final _notesController = TextEditingController();
  VenueBusiness? _selectedVenue;
  var _selectedVenueId = 0;
  var _slotNumber = 1;
  var _sportType = '';
  var _matchDate = DateTime.now().add(const Duration(days: 1));
  var _startTime = const TimeOfDay(hour: 18, minute: 0);
  var _durationHours = 1.0;
  var _skillLevel = 'open';
  var _paymentMethod = 'online';
  var _paymentPolicy = 'split_remaining';
  var _saving = false;
  var _availabilityLoading = true;
  var _availabilityRequest = 0;
  List<Map<String, dynamic>> _occupiedBookings = const [];
  String? _availabilityError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _venuesFuture = VenueCatalogRepository(widget.api).customerBusinesses();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability(int venueId) async {
    final request = ++_availabilityRequest;
    final date = _dateString(_matchDate);
    setState(() {
      _availabilityLoading = true;
      _availabilityError = null;
      _error = null;
      _occupiedBookings = const [];
    });
    try {
      final bookings = await MatchmakingApi(widget.api).getBookingAvailability(
        token: widget.token,
        venueId: venueId,
        date: date,
      );
      if (!mounted ||
          request != _availabilityRequest ||
          venueId != _selectedVenueId ||
          date != _dateString(_matchDate)) {
        return;
      }
      setState(() {
        _occupiedBookings = bookings;
        _availabilityLoading = false;
      });
    } on Exception catch (error) {
      if (mounted && request == _availabilityRequest) {
        setState(() {
          _availabilityError = error.toString();
          _availabilityLoading = false;
        });
      }
    }
  }

  List<int> get _availableSlots {
    final venue = _selectedVenue;
    if (venue == null || _availabilityLoading || _availabilityError != null) {
      return const [];
    }
    final fullCourt = _fullCourtFor(venue, _sportType);
    return availableMatchmakingSlots(
      bookings: _occupiedBookings,
      startTime:
          '${_startTime.hour.toString().padLeft(2, '0')}:'
          '${_startTime.minute.toString().padLeft(2, '0')}',
      durationHours: _durationHours,
      slotCount: fullCourt ? 1 : _slotsFor(venue, _sportType),
      fullCourt: fullCourt,
    );
  }

  Future<void> _submit() async {
    if (_selectedVenueId <= 0 ||
        _slotNumber <= 0 ||
        _sportType.trim().isEmpty) {
      setState(() => _error = 'Choose a venue, court, and sport.');
      return;
    }
    if (_availabilityLoading || _availabilityError != null) {
      setState(
        () => _error = 'Check venue availability before requesting a match.',
      );
      return;
    }
    if (!_availableSlots.contains(_slotNumber)) {
      setState(
        () => _error =
            'That court slot is no longer available. Choose another slot.',
      );
      return;
    }
    final matchStart = DateTime(
      _matchDate.year,
      _matchDate.month,
      _matchDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    if (!matchStart.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a future match time.');
      return;
    }
    final currentVenue = _selectedVenue;
    if (currentVenue == null) {
      setState(() => _error = 'Choose a venue before requesting a match.');
      return;
    }
    final venueData = currentVenue.toViewData();
    final openingHours =
        '${venueData['openingHours'] ??
            venueData['opening_hours'] ??
            venueData['hours'] ??
            ''}'
            .trim();
    if (!_isWithinOpeningHours(openingHours)) {
      setState(() => _error = 'Choose a time within the venue opening hours.');
      return;
    }
    final selectedSport = _slotConfiguration(currentVenue, _sportType);
    final pricePerHour =
        _number(
          selectedSport?['pricePerHour'] ?? selectedSport?['price_per_hour'],
        ) ??
        _number(
          currentVenue.toViewData()['pricePerHour'] ??
              currentVenue.toViewData()['price_per_hour'],
        ) ??
        0;
    if (!pricePerHour.isFinite || pricePerHour <= 0) {
      setState(() => _error = 'This sport does not have a valid venue rate.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final venues = await _venuesFuture;
      final selectedVenue = venues.firstWhere(
        (venue) => venue.id == _selectedVenueId,
      );
      final latestBookings = await MatchmakingApi(
        widget.api,
      ).getBookingAvailability(
        token: widget.token,
        venueId: _selectedVenueId,
        date: _dateString(_matchDate),
      );
      final fullCourt = _fullCourtFor(selectedVenue, _sportType);
      final latestAvailableSlots = availableMatchmakingSlots(
        bookings: latestBookings,
        startTime:
            '${_startTime.hour.toString().padLeft(2, '0')}:'
            '${_startTime.minute.toString().padLeft(2, '0')}',
        durationHours: _durationHours,
        slotCount: fullCourt ? 1 : _slotsFor(selectedVenue, _sportType),
        fullCourt: fullCourt,
      );
      if (!latestAvailableSlots.contains(_slotNumber)) {
        if (mounted) {
          setState(() {
            _saving = false;
            _occupiedBookings = latestBookings;
            _error =
                'That court slot was just booked. Choose another available slot.';
          });
        }
        return;
      }
      final lobbyId = await MatchmakingApi(widget.api).createLobby(
        token: widget.token,
        venueId: _selectedVenueId,
        slotNumber: _slotNumber,
        sportType: _sportType,
        matchDate:
            '${_matchDate.year.toString().padLeft(4, '0')}-'
            '${_matchDate.month.toString().padLeft(2, '0')}-'
            '${_matchDate.day.toString().padLeft(2, '0')}',
        startTime:
            '${_startTime.hour.toString().padLeft(2, '0')}:'
            '${_startTime.minute.toString().padLeft(2, '0')}',
        durationHours: _durationHours,
        skillLevel: _skillLevel,
        paymentMethod: _paymentMethod,
        paymentPolicy: _paymentPolicy,
        opponentCriteria: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(lobbyId);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Host a Match', localize: true),
    ),
    body: FutureBuilder<List<VenueBusiness>>(
        future: _venuesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return AppText(
              'Could not load eligible Sports venues: ${snapshot.error}',
            );
          }
          final venues = (snapshot.data ?? const <VenueBusiness>[])
              .where(
                (venue) =>
                    venue.enabled &&
                    venue.allowMatchmaking &&
                    BusinessTypeParser.parse(venue.businessType) ==
                        BusinessType.sports,
              )
              .toList(growable: false);
          if (widget.initialVenueId != null &&
              !venues.any((venue) => venue.id == widget.initialVenueId)) {
            return const AppText(
              'This venue is not currently available for matchmaking.',
              localize: true,
            );
          }
          if (venues.isEmpty) {
            return AppText(
              'No enabled Sports venues currently allow matchmaking.',
              localize: true,
            );
          }
          if (_selectedVenueId == 0) {
            final initialVenue = venues.firstWhere(
              (venue) => venue.id == widget.initialVenueId,
              orElse: () => venues.first,
            );
            _selectedVenueId = initialVenue.id;
            _sportType = _sportsFor(initialVenue).first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _availabilityRequest == 0) {
                _loadAvailability(initialVenue.id);
              }
            });
          }
          final selectedVenue = venues.firstWhere(
            (venue) => venue.id == _selectedVenueId,
            orElse: () => venues.first,
          );
          _selectedVenue = selectedVenue;
          final sports = _sportsFor(selectedVenue);
          if (!sports.contains(_sportType)) _sportType = sports.first;
          final fullCourt = _fullCourtFor(selectedVenue, _sportType);
          final courtCount = fullCourt
              ? 1
              : _slotsFor(selectedVenue, _sportType);
          if (_slotNumber > courtCount) _slotNumber = 1;
          final startTime =
              '${_startTime.hour.toString().padLeft(2, '0')}:'
              '${_startTime.minute.toString().padLeft(2, '0')}';
          final availableSlots =
              _availabilityLoading || _availabilityError != null
              ? const <int>[]
              : availableMatchmakingSlots(
                  bookings: _occupiedBookings,
                  startTime: startTime,
                  durationHours: _durationHours,
                  slotCount: courtCount,
                  fullCourt: fullCourt,
                );
          final selectedSport = _slotConfiguration(
            selectedVenue,
            _sportType,
          );
          final pricePerHour =
              _number(
                selectedSport?['pricePerHour'] ??
                    selectedSport?['price_per_hour'],
              ) ??
              _number(
                selectedVenue.toViewData()['pricePerHour'] ??
                    selectedVenue.toViewData()['price_per_hour'],
              ) ??
              0;
          final totalPrice = pricePerHour * _durationHours;
          final hostShare = totalPrice * 0.5;
          final venueData = selectedVenue.toViewData();
          final venueAddress = '${venueData['address'] ?? ''}'.trim();
          final openingHours =
              '${venueData['openingHours'] ??
                  venueData['opening_hours'] ??
                  venueData['hours'] ??
                  ''}'
                  .trim();
          final remainingBalance = totalPrice - hostShare;
          final hostBalance = _paymentPolicy == 'host_covers_remaining'
              ? remainingBalance
              : remainingBalance / 2;
          final opponentShare = remainingBalance - hostBalance;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.initialVenueId == null)
                  DropdownButtonFormField<int>(
                    initialValue: selectedVenue.id,
                    decoration: const InputDecoration(labelText: 'Venue'),
                    items: [
                      for (final venue in venues)
                        DropdownMenuItem(
                          value: venue.id,
                          child: Text(
                            '${venue.toViewData()['name'] ?? 'Sports venue'}',
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            final venueId = value ?? 0;
                            final venue = venues.firstWhere(
                              (item) => item.id == venueId,
                            );
                            setState(() {
                              _selectedVenueId = venueId;
                              _sportType = _sportsFor(venue).first;
                              _slotNumber = 1;
                            });
                            _loadAvailability(venueId);
                          },
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      suffixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    child: Text(
                      '${selectedVenue.toViewData()['name'] ?? 'Sports venue'}',
                    ),
                  ),
                if (venueAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      venueAddress,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppText(
                      'Request venue approval first, pay the 50% host deposit after approval within 15 minutes, then publish the match for players. Online payment and cash on arrival are separate handling methods; a join request is not a confirmed match.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _sportType,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: [
                    for (final sport in sports)
                      DropdownMenuItem(value: sport, child: Text(sport)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _sportType = value ?? '';
                          _slotNumber = 1;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _slotNumber,
                  decoration: InputDecoration(
                    labelText: fullCourt ? 'Court' : 'Court slot',
                  ),
                  items: [
                    for (var slot = 1; slot <= courtCount; slot++)
                      DropdownMenuItem(
                        value: slot,
                        enabled: availableSlots.contains(slot),
                        child: Text(
                          fullCourt
                              ? 'Whole court'
                              : 'Slot $slot · '
                                    '${availableSlots.contains(slot) ? 'Available' : 'Booked'}',
                        ),
                      ),
                  ],
                  onChanged: _saving ||
                          _availabilityLoading ||
                          _availabilityError != null
                      ? null
                      : (value) => setState(() {
                          _slotNumber = value ?? 1;
                          _error = null;
                        }),
                ),
                if (_availabilityLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppText('Checking available court slots...'),
                  ),
                ] else if (_availabilityError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Could not verify availability: $_availabilityError',
                      style: TextStyle(color: AppColors.errorText),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _loadAvailability(selectedVenue.id),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const AppText('Retry availability check'),
                    ),
                  ),
                ] else if (availableSlots.isEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'No court slots are available at this time. Choose another date or time.',
                      style: TextStyle(color: AppColors.errorText),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      fullCourt
                          ? 'Whole court available'
                          : '${availableSlots.length} of $courtCount court slots available',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _chooseDate(selectedVenue.id),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_matchDate.month}/${_matchDate.day}/${_matchDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _chooseTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(_startTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<double>(
                  initialValue: _durationHours,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hour')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5 hours')),
                    DropdownMenuItem(value: 2, child: Text('2 hours')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _durationHours = value ?? 1;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _skillLevel,
                  decoration: const InputDecoration(labelText: 'Skill level'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open to All')),
                    DropdownMenuItem(
                      value: 'beginner',
                      child: Text('Beginner'),
                    ),
                    DropdownMenuItem(
                      value: 'intermediate',
                      child: Text('Intermediate'),
                    ),
                    DropdownMenuItem(
                      value: 'advanced',
                      child: Text('Advanced'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _skillLevel = value ?? 'open';
                          _error = null;
                        }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLength: 255,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                const AppText(
                  'Payment method',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  key: const ValueKey('matchmaking-payment-method'),
                  segments: const [
                    ButtonSegment(
                      value: 'cash_on_arrival',
                      icon: Icon(Icons.payments_outlined),
                      label: Text('COA'),
                    ),
                    ButtonSegment(
                      value: 'online',
                      icon: Icon(Icons.credit_card_outlined),
                      label: Text('Online'),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _paymentMethod = value.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 12),
                const AppText(
                  'Who pays the remaining balance?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('matchmaking-payment-free-to-join'),
                      label: const Text('Free to join'),
                      selected: _paymentPolicy == 'host_covers_remaining',
                      onSelected: _saving
                          ? null
                          : (_) => setState(
                              () => _paymentPolicy = 'host_covers_remaining',
                            ),
                    ),
                    ChoiceChip(
                      key: const ValueKey('matchmaking-payment-opponent-share'),
                      label: const Text('Opponent shares'),
                      selected: _paymentPolicy == 'split_remaining',
                      onSelected: _saving
                          ? null
                          : (_) => setState(
                              () => _paymentPolicy = 'split_remaining',
                            ),
                    ),
                  ],
                ),
                if (openingHours.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Venue hours: $openingHours',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Payment breakdown',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          _paymentMethod == 'online'
                              ? 'After venue approval, pay the 50% deposit online within 15 minutes to publish your match.'
                              : 'After venue approval, pay the 50% cash deposit at the venue within 15 minutes. The match publishes after the venue confirms it.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Divider(height: 16),
                        _amountRow('Match total', totalPrice),
                        _amountRow('Host 50% deposit', hostShare),
                        _amountRow(
                          _paymentPolicy == 'host_covers_remaining'
                              ? 'Host remaining balance'
                              : 'Host share of remaining balance',
                          hostBalance,
                        ),
                        _amountRow(
                          _paymentPolicy == 'host_covers_remaining'
                              ? 'Opponent share · free to join'
                              : 'Opponent share of remaining balance',
                          opponentShare,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error case final error?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      error,
                      style: TextStyle(color: AppColors.errorText),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
        onPressed: _saving ||
                _availabilityLoading ||
                _availabilityError != null ||
                _availableSlots.isEmpty ||
                !_isWithinSelectedOpeningHours
            ? null
            : _submit,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : AppText('Request venue approval', localize: true),
      ),
        ),
      ),
    ),
  );

  Future<void> _chooseDate(int venueId) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _matchDate = date;
        _error = null;
      });
      await _loadAvailability(venueId);
    }
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null && mounted) {
      setState(() {
        _startTime = time;
        _error = null;
      });
    }
  }

  List<String> _sportsFor(VenueBusiness venue) {
    final data = venue.toViewData();
    dynamic slots = data['sportsSlots'] ?? data['sports_slots_json'];
    if (slots is String) {
      try {
        slots = jsonDecode(slots);
      } on FormatException {
        slots = null;
      }
    }
    final sports = <String>{};
    if (slots is List) {
      for (final slot in slots.whereType<Map>()) {
        final sport = slot['sportType'] ?? slot['sport_type'];
        if (sport is String && sport.trim().isNotEmpty) {
          sports.add(sport.trim());
        }
      }
    }
    if (sports.isEmpty) {
      final category = data['category'];
      if (category is String && category.trim().isNotEmpty) {
        sports.addAll(
          category
              .split(',')
              .map((value) => value.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }
    return sports.isEmpty ? ['Sports'] : sports.toList()
      ..sort();
  }

  Map<String, dynamic>? _slotConfiguration(
    VenueBusiness venue,
    String sport,
  ) {
    final data = venue.toViewData();
    dynamic slots = data['sportsSlots'] ?? data['sports_slots_json'];
    if (slots is String) {
      try {
        slots = jsonDecode(slots);
      } on FormatException {
        return null;
      }
    }
    if (slots is! List) return null;
    for (final config in slots.whereType<Map>()) {
      final configuredSport = config['sportType'] ?? config['sport_type'];
      if (configuredSport is String &&
          configuredSport.trim().toLowerCase() == sport.toLowerCase()) {
        return Map<String, dynamic>.from(config);
      }
    }
    return null;
  }

  bool _fullCourtFor(VenueBusiness venue, String sport) {
    final config = _slotConfiguration(venue, sport);
    if (config == null) return true;
    final value = config['fullStudio'] ?? config['full_studio'];
    return value == true || value == 1 || value == '1' || value == 'true';
  }

  int _slotsFor(VenueBusiness venue, String sport) {
    final data = venue.toViewData();
    dynamic slots = data['sportsSlots'] ?? data['sports_slots_json'];
    if (slots is String) {
      try {
        slots = jsonDecode(slots);
      } on FormatException {
        slots = null;
      }
    }
    if (slots is List) {
      for (final config in slots.whereType<Map>()) {
        final configuredSport = config['sportType'] ?? config['sport_type'];
        if (configuredSport is String &&
            configuredSport.trim().toLowerCase() == sport.toLowerCase()) {
          final count = int.tryParse(
            '${config['slotCount'] ?? config['slot_count'] ?? ''}',
          );
          if (count != null && count > 0) return count;
        }
      }
    }
    final count = int.tryParse(
      '${data['slotCount'] ?? data['slot_count'] ?? 1}',
    );
    return count == null || count < 1 ? 1 : count;
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get _isWithinSelectedOpeningHours {
    final data = _selectedVenue?.toViewData();
    return _isWithinOpeningHours(
      '${data?['openingHours'] ??
          data?['opening_hours'] ??
          data?['hours'] ??
          ''}'
          .trim(),
    );
  }

  bool _isWithinOpeningHours(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*[-–]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return false;
    int? toMinutes(String hourText, String? minuteText, String period) {
      final hour = int.tryParse(hourText);
      final minute = int.tryParse(minuteText ?? '0');
      if (hour == null ||
          hour < 1 ||
          hour > 12 ||
          minute == null ||
          minute < 0 ||
          minute > 59) {
        return null;
      }
      return (hour % 12 + (period.toUpperCase() == 'PM' ? 12 : 0)) * 60 +
          minute;
    }

    final opening = toMinutes(match[1]!, match[2], match[3]!);
    var closing = toMinutes(match[4]!, match[5], match[6]!);
    if (match[4] == '12' &&
        (match[5] == null || match[5] == '00') &&
        match[6]!.toUpperCase() == 'AM') {
      closing = 24 * 60;
    }
    if (opening == null || closing == null || closing <= opening) return false;
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = start + (_durationHours * 60).round();
    return start >= opening && end <= closing;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Widget _amountRow(String label, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: AppText(label)),
        AppText('\u{20B1} ${amount.toStringAsFixed(2)}'),
      ],
    ),
  );
}
