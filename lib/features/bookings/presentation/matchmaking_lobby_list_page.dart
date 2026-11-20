import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/api_transport.dart';
import 'package:myapp/core/user_facing_error.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/bookings/data/matchmaking_api.dart';
import 'package:myapp/features/bookings/domain/matchmaking_models.dart';
import 'package:myapp/features/bookings/presentation/matchmaking_host_page.dart';
import 'package:myapp/features/session/application/session_service.dart';

class MatchmakingLobbyListPage extends StatefulWidget {
  const MatchmakingLobbyListPage({
    super.key,
    required this.api,
    this.initialUserPosition,
    this.venueId,
    this.searchQuery = '',
    this.initialLobbyId,
    this.isActive = true,
  });

  final ApiTransport api;
  final Position? initialUserPosition;
  final int? venueId;
  final String searchQuery;
  final int? initialLobbyId;
  final bool isActive;

  @override
  State<MatchmakingLobbyListPage> createState() =>
      _MatchmakingLobbyListPageState();
}

class _MatchmakingLobbyListPageState extends State<MatchmakingLobbyListPage> {
  late final MatchmakingApi _matchmakingApi = MatchmakingApi(widget.api);
  final ScrollController _scrollController = ScrollController();
  String? _token;
  int? _currentUserId;
  Position? _userPosition;
  List<MatchmakingLobby> _lobbies = const [];
  List<MatchmakingHostRequest> _hostLobbies = const [];
  String _sportFilter = '';
  String? _dateFilter;
  String? _error;
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  final Set<int> _joining = <int>{};

  @override
  void initState() {
    super.initState();
    _userPosition = widget.initialUserPosition;
    _scrollController.addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MatchmakingLobbyListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialUserPosition != widget.initialUserPosition) {
      _userPosition = widget.initialUserPosition;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _load();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (_loadingMore || _loading || !_hasMore || _nextCursor == null) return;
    if (current >= maxScroll - 200) {
      _load(loadMore: true);
    }
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore && (_loadingMore || !_hasMore || _nextCursor == null)) {
      return;
    }
    if (mounted) {
      setState(() {
        if (!loadMore) {
          _loading = true;
        }
        _loadingMore = loadMore;
        _error = null;
      });
    }
    try {
      final session = await AppSessionService.instance.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Log in to find or host a match.', 401);
      }
      final profile = await widget.api.request(
        'GET',
        '/api/auth/me',
        headers: widget.api.authHeadersForToken(token),
      );
      final user = profile['user'];
      final userId = user is Map ? _positiveInt(user['id']) : null;
      if (userId == null) {
        throw const FormatException(
          'The server returned an invalid user profile.',
        );
      }
      final page = await _matchmakingApi.getLobbiesPage(
        token: token,
        sport: _sportFilter,
        date: _dateFilter,
        venueId: widget.venueId,
        lobbyId: widget.initialLobbyId,
        cursor: loadMore ? int.tryParse(_nextCursor ?? '') : null,
        limit: widget.initialLobbyId == null ? 20 : 1,
      );
      final hostLobbies = await _matchmakingApi.getHostLobbies(token: token);
      if (!mounted) return;
      final mergedLobbies = loadMore
          ? <MatchmakingLobby>[..._lobbies, ...page.lobbies]
          : page.lobbies;
      final deduped = <int, MatchmakingLobby>{};
      for (final lobby in mergedLobbies) {
        deduped[lobby.id] = lobby;
      }
      final ordered = deduped.values.toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      setState(() {
        _token = token;
        _currentUserId = userId;
        _lobbies = ordered;
        _hostLobbies = hostLobbies;
        _loading = false;
        _loadingMore = false;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingErrorMessage(
          error,
          fallback: 'We couldn’t load match listings. Please try again.',
        );
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _join(MatchmakingLobby lobby) async {
    final token = _token;
    if (token == null || _joining.contains(lobby.id)) return;
    setState(() => _joining.add(lobby.id));
    try {
      await _matchmakingApi.joinLobby(token: token, lobbyId: lobby.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Join request sent to the host. It does not reserve a place until the host accepts.',
          ),
        ),
      );
      await _load();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                error,
                fallback: 'We couldn’t send your join request. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joining.remove(lobby.id));
    }
  }

  Future<void> _hostMatch() async {
    final token = _token;
    if (token == null) return;
    final lobbyId = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (context) => MatchmakingHostPage(
          api: widget.api,
          token: token,
          initialVenueId: widget.venueId,
        ),
      ),
    );
    if (!mounted || lobbyId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your request was sent to the venue for approval.'),
      ),
    );
    await _load();
  }

  Future<void> _payDownpayment(MatchmakingHostRequest lobby) async {
    final token = _token;
    if (token == null) return;
    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose online payment'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gcash'),
            child: const Text('GCash'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'paymaya'),
            child: const Text('PayMaya'),
          ),
        ],
      ),
    );
    if (!mounted || paymentMethod == null) return;
    try {
      final checkout = await _matchmakingApi.createHostDownpaymentCheckout(
        token: token,
        bookingId: lobby.bookingId,
        paymentMethod: paymentMethod,
      );
      if (!await launchUrl(checkout, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the payment checkout.');
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                error,
                fallback: 'We couldn’t start payment. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _payHostBalance(MatchmakingHostRequest lobby) async {
    final token = _token;
    if (token == null || lobby.hostBalancePaymentStatus != 'unpaid') return;
    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose online payment'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gcash'),
            child: const Text('GCash'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'paymaya'),
            child: const Text('PayMaya'),
          ),
        ],
      ),
    );
    if (!mounted || paymentMethod == null) return;
    try {
      final checkout = await _matchmakingApi.createHostBalanceCheckout(
        token: token,
        bookingId: lobby.bookingId,
        paymentMethod: paymentMethod,
      );
      if (!await launchUrl(checkout, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the payment checkout.');
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                error,
                fallback: 'We couldn’t start payment. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _chooseDate() async {
    final initial = _dateFilter == null
        ? DateTime.now()
        : DateTime.parse(_dateFilter!);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dateFilter =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      _nextCursor = null;
      _hasMore = false;
    });
    await _load();
  }

  Future<void> _loadLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Location services are off. Turn them on to see match distances.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Allow it to see match distances.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is blocked. Enable it in app settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => _userPosition = position);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                error,
                fallback: 'We couldn’t update your location. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = <String>{
      for (final lobby in _lobbies) lobby.sportType,
    }.toList()..sort();
    final visibleLobbies = _lobbies
        .where(
          (lobby) => matchmakingLobbyMatchesSearch(
            lobby,
            widget.initialLobbyId == null
                ? widget.searchQuery
                : 'match ${widget.initialLobbyId}',
          ),
        )
        .toList();
    final position = _userPosition;
    if (position != null) {
      visibleLobbies.sort((a, b) {
        final distanceComparison =
            (_distanceMeters(a, position) ?? double.infinity).compareTo(
              _distanceMeters(b, position) ?? double.infinity,
            );
        return distanceComparison != 0
            ? distanceComparison
            : b.id.compareTo(a.id);
      });
    }
    final normalizedQuery =
        (widget.initialLobbyId == null
                ? widget.searchQuery
                : 'match ${widget.initialLobbyId}')
            .trim()
            .toLowerCase();
    final visibleHostLobbies = _hostLobbies.where((lobby) {
      if (normalizedQuery.isEmpty) return true;
      return [
        lobby.venueName,
        lobby.sportType,
        lobby.matchDate,
        lobby.startTime,
        lobby.status,
      ].join(' ').toLowerCase().contains(normalizedQuery);
    }).toList();
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sportFilter,
                      decoration: const InputDecoration(
                        labelText: 'Sport',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All sports'),
                        ),
                        for (final sport in sports)
                          DropdownMenuItem(value: sport, child: Text(sport)),
                      ],
                      onChanged: (value) async {
                        setState(() {
                          _sportFilter = value ?? '';
                          _nextCursor = null;
                          _hasMore = false;
                        });
                        await _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Filter by date',
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                  IconButton(
                    tooltip: 'Use my location',
                    onPressed: _loadLocation,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                  if (_dateFilter != null)
                    IconButton(
                      tooltip: 'Clear date filter',
                      onPressed: () async {
                        setState(() {
                          _dateFilter = null;
                          _nextCursor = null;
                          _hasMore = false;
                        });
                        await _load();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
            if (_dateFilter != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppText('Matches on $_dateFilter'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          'Regular booking reserves court time for your group. Matchmaking lets you host or join a public match; a join request does not reserve a place until the host accepts.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: AppText('Try again', localize: true),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child:
                          visibleLobbies.isEmpty && visibleHostLobbies.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              children: [
                                const SizedBox(height: 80),
                                Icon(
                                  Icons.sports_handball_outlined,
                                  size: 44,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(height: 12),
                                AppText(
                                  normalizedQuery.isEmpty
                                      ? 'No open matches found. Host one and invite players!'
                                      : 'No matches found for "${widget.searchQuery}".',
                                  textAlign: TextAlign.center,
                                  localize: true,
                                ),
                              ],
                            )
                          : ListView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                100,
                              ),
                              children: [
                                if (visibleHostLobbies.isNotEmpty) ...[
                                  const AppText(
                                    'Your matchmaking requests',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final lobby in visibleHostLobbies) ...[
                                    _hostRequestCard(lobby),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                                if (visibleLobbies.isNotEmpty) ...[
                                  const AppText(
                                    'Find a match',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final lobby in visibleLobbies) ...[
                                    _lobbyCard(lobby),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                                if (_hasMore)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Center(
                                      child: _loadingMore
                                          ? const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                SizedBox(width: 8),
                                                AppText(
                                                  'Loading more matches...',
                                                ),
                                              ],
                                            )
                                          : AppText(
                                              'Scroll for more matches',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                    ),
                                  )
                                else if (visibleLobbies.length > 1 ||
                                    _lobbies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Center(
                                      child: AppText(
                                        'You reached the end of the current match feed.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            key: const ValueKey('matchmaking-host-match'),
            onPressed: _token == null ? null : _hostMatch,
            icon: const Icon(Icons.add_rounded),
            label: AppText('Host a Match', localize: true),
          ),
        ),
      ],
    );
  }

  Widget _lobbyCard(MatchmakingLobby lobby) {
    final isHost = lobby.hostUserId == _currentUserId;
    final hasActiveRequest =
        lobby.requestStatus == 'pending' || lobby.requestStatus == 'accepted';
    final disabled = isHost || hasActiveRequest || lobby.status != 'open';
    return Card(
      key: ValueKey('matchmaking-lobby-${lobby.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showVenueDetails(lobby),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lobby.venueImages.isNotEmpty) ...[
                _venueImage(lobby.venueImages.first, height: 150),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (lobby.venueLogoUrl != null &&
                      lobby.venueLogoUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image:
                            _imageProvider(lobby.venueLogoUrl!) ??
                            const AssetImage('assets/court/pickle-court.jpg'),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.storefront_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      lobby.venueName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      lobby.skillLevel == 'open'
                          ? 'Open skill level'
                          : _skillLabel(lobby.skillLevel),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (lobby.venueAddress != null)
                Text(
                  lobby.venueAddress!,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _detail(
                    Icons.calendar_today_outlined,
                    '${lobby.matchDate} · ${lobby.startTime}',
                  ),
                  _detail(Icons.sports_outlined, lobby.sportType),
                  _detail(Icons.stadium_outlined, 'Court ${lobby.slotNumber}'),
                  _detail(
                    Icons.person_pin_circle_outlined,
                    _distanceLabel(lobby),
                  ),
                  _detail(
                    Icons.star_rounded,
                    '${lobby.venueRating.toStringAsFixed(1)} · ${lobby.venueReviewCount} reviews',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _detail(
                Icons.payments_outlined,
                'Total ₱${lobby.totalPrice.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 4),
              _detail(
                Icons.person_outline_rounded,
                'Host deposit ₱${lobby.hostShareAmount.toStringAsFixed(2)} · '
                '${lobby.opponentShareAmount == 0 ? 'Free to join' : 'Your share ₱${lobby.opponentShareAmount.toStringAsFixed(2)}'}',
              ),
              _detail(
                Icons.payments_outlined,
                lobby.paymentMethod == 'cash_on_arrival'
                    ? 'Cash on Arrival'
                    : 'Online payment',
              ),
              if (lobby.opponentCriteria != null) ...[
                const SizedBox(height: 8),
                AppText('Looking for: ${lobby.opponentCriteria!}'),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: lobby.hostAvatarUrl == null
                        ? null
                        : _imageProvider(lobby.hostAvatarUrl!),
                    child: lobby.hostAvatarUrl == null
                        ? const Icon(Icons.person_outline, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'Hosted by ${lobby.hostFirstName}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: disabled || _joining.contains(lobby.id)
                        ? null
                        : () => _join(lobby),
                    child: _joining.contains(lobby.id)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppText(
                            isHost
                                ? 'Your match'
                                : hasActiveRequest
                                ? 'Requested'
                                : 'Request to Match',
                            localize: true,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hostRequestCard(MatchmakingHostRequest lobby) {
    final waitingForPayment =
        lobby.status == 'awaiting_host_downpayment' &&
        lobby.paymentStatus == 'unpaid';
    final status = switch (lobby.status) {
      'pending_merchant_approval' => 'Awaiting venue approval',
      'awaiting_host_downpayment' => 'Venue approved',
      'matched' => 'Matched',
      _ => 'Published',
    };
    final waitingForHostBalance =
        lobby.status == 'matched' &&
        lobby.paymentMethod == 'online' &&
        lobby.hostBalancePaymentStatus == 'unpaid' &&
        lobby.hostBalanceAmount > 0;
    return Card(
      key: ValueKey('matchmaking-host-request-${lobby.lobbyId}'),
      child: ListTile(
        title: Text('${lobby.venueName} · ${lobby.sportType}'),
        subtitle: Text(
          'Court ${lobby.slotNumber} · ${lobby.matchDate} ${lobby.startTime}\n'
          '$status · 50% downpayment ₱${lobby.hostShareAmount.toStringAsFixed(2)}\n'
          '${lobby.paymentMethod == 'cash_on_arrival' ? 'Cash on Arrival' : 'Online'} · '
          'Host balance ₱${lobby.hostBalanceAmount.toStringAsFixed(2)}',
        ),
        isThreeLine: true,
        trailing: waitingForPayment && lobby.paymentMethod == 'online'
            ? FilledButton(
                onPressed: () => _payDownpayment(lobby),
                child: const Text('Pay 50%'),
              )
            : waitingForPayment
            ? const Text('Pay at venue')
            : waitingForHostBalance
            ? FilledButton(
                onPressed: () => _payHostBalance(lobby),
                child: const Text('Pay balance'),
              )
            : null,
      ),
    );
  }

  Future<void> _showVenueDetails(MatchmakingLobby lobby) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lobby.venueName),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final image in lobby.venueImages) ...[
                  _venueImage(image, height: 170),
                  const SizedBox(height: 8),
                ],
                if (lobby.venueAddress != null)
                  Text('Address: ${lobby.venueAddress}'),
                const SizedBox(height: 6),
                Text(
                  'Rating: ${lobby.venueRating.toStringAsFixed(1)} '
                  '(${lobby.venueReviewCount} reviews)',
                ),
                if (lobby.latitude != null && lobby.longitude != null)
                  Text('GPS: ${lobby.latitude}, ${lobby.longitude}'),
                const Divider(height: 20),
                Text('${lobby.sportType} · Court ${lobby.slotNumber}'),
                Text('${lobby.matchDate} · ${lobby.startTime}'),
                Text('Skill level: ${_skillLabel(lobby.skillLevel)}'),
                Text(
                  'Host downpayment: ₱${lobby.hostShareAmount.toStringAsFixed(2)}',
                ),
                Text(
                  'Opponent share: ₱${lobby.opponentShareAmount.toStringAsFixed(2)}',
                ),
                Text(
                  'Host remaining balance: '
                  '₱${lobby.hostBalanceAmount.toStringAsFixed(2)}',
                ),
                Text(
                  lobby.paymentMethod == 'cash_on_arrival'
                      ? 'Payment method: Cash on Arrival'
                      : 'Payment method: Online',
                ),
                Text(
                  'Host: ${lobby.hostFirstName} · ${_skillLabel(lobby.skillLevel)}',
                ),
                if (lobby.opponentCriteria != null)
                  Text('Opponent criteria: ${lobby.opponentCriteria}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _venueImage(String value, {required double height}) {
    final uri = Uri.tryParse(value);
    if (uri != null && {'http', 'https'}.contains(uri.scheme)) {
      return Image.network(
        value,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height),
      );
    }
    try {
      final base64Value = value.contains(',')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return Image.memory(
        base64Decode(base64Value),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height),
      );
    } on FormatException {
      return _imagePlaceholder(height);
    }
  }

  Widget _imagePlaceholder(double height) => Container(
    height: height,
    color: AppColors.surfaceVariant,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined),
  );

  ImageProvider<Object>? _imageProvider(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && {'http', 'https'}.contains(uri.scheme)) {
      return NetworkImage(value);
    }
    try {
      final base64Value = value.contains(',')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return MemoryImage(base64Decode(base64Value));
    } on FormatException {
      return null;
    }
  }

  Widget _detail(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 4),
      AppText(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
    ],
  );

  String _distanceLabel(MatchmakingLobby lobby) {
    final position = _userPosition;
    final meters = position == null ? null : _distanceMeters(lobby, position);
    if (meters == null) return 'Distance unavailable';
    return meters < 1000
        ? '${meters.round()} m away'
        : '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  double? _distanceMeters(MatchmakingLobby lobby, Position position) {
    final latitude = lobby.latitude;
    final longitude = lobby.longitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }

  String _skillLabel(String skill) => switch (skill) {
    'beginner' => 'Beginner',
    'intermediate' => 'Intermediate',
    'advanced' => 'Advanced',
    _ => 'Open to All',
  };
}

int? _positiveInt(dynamic value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}
