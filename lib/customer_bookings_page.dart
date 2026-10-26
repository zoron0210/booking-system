import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'app_design_system.dart';
import 'auth_api.dart';
import 'core/business_type.dart';
import 'core/booking_approval_deadline.dart';
import 'features/bookings/presentation/booking_card_header.dart';
import 'features/bookings/presentation/booking_details_panel.dart';
import 'features/bookings/presentation/booking_status_banner.dart';
import 'features/bookings/presentation/customer_booking_controller.dart';
import 'features/bookings/data/customer_bookings_session_provider.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'messages_dashboard.dart';
import 'profile_dashboard.dart';
import 'prototype_payment_dialog.dart';
import 'app_bottom_navigation.dart';
import 'saved_dashboard.dart';
import 'news_feed.dart';
import 'rating_widgets.dart';
import 'models/booking.dart';
import 'skeleton_loader.dart';
import 'app_preferences.dart';

String _bookingErrorMessage(Object error, String action) {
  if (error is AuthApiException) {
    if (error.statusCode == 401) {
      return 'Your session has expired. Please sign in again to $action.';
    }
    if (error.statusCode == 0 || error.statusCode == 408) {
      return 'We couldn’t connect to the booking service. Check your connection and try again.';
    }
    if (error.statusCode >= 500) {
      return 'We couldn’t $action right now. Please try again shortly.';
    }
    return error.message;
  }
  return 'We couldn’t $action right now. Please try again.';
}

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.businessType,
    this.sessionProvider,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String? businessType;
  final CustomerBookingsSessionProvider? sessionProvider;

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _BookingGallery extends StatefulWidget {
  const _BookingGallery({required this.images});

  final List<String> images;

  @override
  State<_BookingGallery> createState() => _BookingGalleryState();
}

class _BookingGalleryState extends State<_BookingGallery> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.images.length > 1 ? widget.images.length * 1000 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: multiple ? 10000 : 1,
              onPageChanged: (page) {
                setState(() => _index = page % widget.images.length);
              },
              itemBuilder: (_, page) => Image(
                image: _imageProvider(
                  widget.images[page % widget.images.length],
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  'assets/court/pickle-court.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (multiple)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var dot = 0; dot < widget.images.length; dot++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: dot == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dot == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider _imageProvider(String image) {
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      if (comma >= 0) {
        try {
          return MemoryImage(base64Decode(image.substring(comma + 1)));
        } on FormatException {
          return const AssetImage('assets/court/pickle-court.jpg');
        }
      }
    }
    if (image.startsWith('http')) return NetworkImage(image);
    return AssetImage(image);
  }
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage>
    with WidgetsBindingObserver {
  late final AuthApi _api;
  late final CustomerBookingsSessionProvider _sessionProvider;
  late Future<List<Booking>> _bookings;
  Timer? _bookingRefreshTimer;
  var _refreshingForUpdates = false;
  final List<ScrollController> _bookingScrollControllers = List.generate(
    3,
    (_) => ScrollController(),
  );
  final List<GlobalKey<RefreshIndicatorState>> _bookingRefreshKeys =
      List.generate(3, (_) => GlobalKey<RefreshIndicatorState>());
  final TextEditingController _bookingSearchController =
      TextEditingController();
  int _selectedBookingTab = 0;
  String _approvedPaymentFilter = 'all';
  String _bookingSearchQuery = '';
  int _unreadBookingCount = 0;
  List<Booking> _bookingStatusNotifications = [];
  Booking? _activeBookingStatusBannerBooking;
  int _unreadMessageCount = 0;
  String? _messageCountError;
  String? _bookingStatusBannerKey;
  var _showBookingStatusBanner = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? AuthApi();
    _sessionProvider =
        widget.sessionProvider ?? AppCustomerBookingsSessionProvider();
    _bookings = _loadBookings();
    _bookingRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshForUpdates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bookingRefreshTimer?.cancel();
    _bookingSearchController.dispose();
    for (final controller in _bookingScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<Booking>> _loadBookings() async {
    final session = await _sessionProvider.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) return [];
    final bookings = await _api.customerBookingModels(
      token,
      businessType: widget.businessType,
    );
    final bannerBooking = CustomerBookingController.selectStatusBannerBooking(
      bookings
          .where(CustomerBookingController.isNotificationRelevant)
          .where(
            (booking) => !session.bookingStatusBannerDismissed(
              CustomerBookingController.bookingStatusKey(booking),
            ),
          )
          .toList(),
    );
    _bookingStatusNotifications =
        bookings
            .where(
              (booking) =>
                  CustomerBookingController.bookingStatus(booking) ==
                      'expired' ||
                  CustomerBookingController.awaitingApprovalPayment(booking),
            )
            .where(
              (booking) => !session.bookingStatusBannerDismissed(
                CustomerBookingController.bookingStatusKey(booking),
              ),
            )
            .toList()
          ..sort(CustomerBookingController.compareBookingStatusNotifications);
    _activeBookingStatusBannerBooking = bannerBooking;
    _bookingStatusBannerKey = bannerBooking == null
        ? null
        : CustomerBookingController.bookingStatusKey(bannerBooking);
    _showBookingStatusBanner =
        bannerBooking != null &&
        !session.bookingStatusBannerDismissed(_bookingStatusBannerKey!);
    _unreadBookingCount = _bookingStatusNotifications.length;
    try {
      final conversations = await _api.conversations(
        token,
        businessType: widget.businessType,
      );
      _unreadMessageCount = conversations.fold<int>(
        0,
        (total, conversation) =>
            total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
      );
      _messageCountError = null;
    } on Exception catch (error) {
      _messageCountError =
          error is AuthApiException &&
              (error.statusCode == 0 || error.statusCode == 408)
          ? 'We couldn’t check for new messages. Check your connection and try again.'
          : 'Your unread message count is temporarily unavailable.';
    }
    if (mounted) setState(() {});
    return bookings;
  }

  Future<void> _refresh() async {
    await _dismissBookingStatusBanner();
    if (!mounted) return;
    setState(() {
      _bookings = _loadBookings();
    });
    await _bookings;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshForUpdates();
  }

  void _refreshForUpdates() {
    if (!mounted || _refreshingForUpdates) return;
    _refreshingForUpdates = true;
    setState(() {
      _bookings = _loadBookings().whenComplete(() {
        _refreshingForUpdates = false;
      });
    });
  }

  Future<void> _refreshAndScrollToTop() async {
    final refresh = _bookingRefreshKeys[_selectedBookingTab].currentState
        ?.show();
    if (refresh != null) {
      await refresh;
    } else {
      await _refresh();
    }
    if (!mounted) return;
    final controller = _bookingScrollControllers[_selectedBookingTab];
    if (controller.hasClients) {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _dismissBookingStatusBanner() async {
    if (!_showBookingStatusBanner) return;
    final bannerKey = _bookingStatusBannerKey;
    setState(() {
      _bookingStatusNotifications.removeWhere(
        (booking) => _bookingStatusKey(booking) == bannerKey,
      );
      final nextBooking = _bookingStatusNotifications.isEmpty
          ? null
          : _bookingStatusNotifications.first;
      _activeBookingStatusBannerBooking = nextBooking;
      _bookingStatusBannerKey = nextBooking == null
          ? null
          : _bookingStatusKey(nextBooking);
      _showBookingStatusBanner = nextBooking != null;
      _unreadBookingCount = _bookingStatusNotifications.length;
    });
    if (bannerKey == null) return;
    final session = await _sessionProvider.load();
    await session.dismissBookingStatusBanner(bannerKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const AppText('Bookings', localize: true),
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              key: const ValueKey('customer-bookings-loading-skeleton'),
              padding: const EdgeInsets.all(16),
              children: [
                for (var index = 0; index < 3; index++) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonBlock(height: 148, borderRadius: 12),
                        const SizedBox(height: 6),
                        const SkeletonBlock(width: 180, height: 18),
                        const SizedBox(height: 6),
                        const SkeletonBlock(width: 125, height: 13),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              child: SkeletonBlock(
                                height: 38,
                                borderRadius: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: SkeletonBlock(
                                height: 38,
                                borderRadius: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < 2) const SizedBox(height: 6),
                ],
              ],
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'We couldn’t load your bookings right now. Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      localize: true,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('customer-bookings-retry'),
                      onPressed: () => setState(() {
                        _bookings = _loadBookings();
                      }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const AppText('Try again', localize: true),
                    ),
                  ],
                ),
              ),
            );
          }
          final bookings = snapshot.data ?? const <Booking>[];
          final pending = bookings
              .where(
                (booking) =>
                    _bookingStatus(booking) == 'pending' &&
                    _matchesBookingSearch(booking),
              )
              .toList();
          final approved =
              bookings
                  .where(
                    (booking) =>
                        _bookingStatus(booking) == 'approved' &&
                        _matchesBookingSearch(booking),
                  )
                  .toList()
                ..sort(_compareApprovedPaymentPriority);
          final filteredApproved = approved.where((booking) {
            return switch (_approvedPaymentFilter) {
              'payable' => booking.paymentStatus.toLowerCase() != 'paid',
              'paid' => booking.paymentStatus.toLowerCase() == 'paid',
              _ => true,
            };
          }).toList();
          final completed = bookings
              .where(
                (booking) =>
                    const {
                      'finished',
                      'done',
                      'completed',
                      'expired',
                      'cancelled',
                    }.contains(_bookingStatus(booking)) &&
                    _matchesBookingSearch(booking),
              )
              .toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                if (_messageCountError != null)
                  MaterialBanner(
                    backgroundColor: AppColors.softStatus,
                    leading: const Icon(
                      Icons.sync_problem_rounded,
                      color: Color(0xFFB85C00),
                    ),
                    content: AppText(
                      _messageCountError!,
                      style: TextStyle(color: AppColors.ink),
                    ),
                    actions: [
                      TextButton(
                        onPressed: _refresh,
                        child: const AppText('Retry', localize: true),
                      ),
                    ],
                  ),
                if (_bookingStatusNotifications.isNotEmpty ||
                    approved.isNotEmpty ||
                    completed.isNotEmpty)
                  AnimatedSize(
                    alignment: Alignment.topCenter,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: _showBookingStatusBanner
                        ? _bookingStatusBanner(approved, completed)
                        : const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: TextField(
                    key: const ValueKey('customer-bookings-search'),
                    controller: _bookingSearchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) =>
                        setState(() => _bookingSearchQuery = value),
                    decoration: InputDecoration(
                      hintText: appLanguageText(
                        'Search venue, transaction ID, or booking reference',
                        'Maghanap ng venue, transaction ID, o booking reference',
                        languageCode: Localizations.localeOf(context)
                            .languageCode,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _bookingSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey(
                                'customer-bookings-search-clear',
                              ),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _bookingSearchController.clear();
                                setState(() => _bookingSearchQuery = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: AppColors.surface,
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.ink,
                    unselectedLabelColor: AppColors.muted,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    onTap: (index) =>
                        setState(() => _selectedBookingTab = index),
                    tabs: [
                      Tab(
                        child: AppText(
                          'Pending (${pending.length})',
                          localize: true,
                        ),
                      ),
                      Tab(
                        child: AppText(
                          'Approved (${approved.length})',
                          localize: true,
                        ),
                      ),
                      Tab(
                        child: AppText(
                          'Completed (${completed.length})',
                          localize: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _bookingTab(
                        pending,
                        emptyMessage: _bookingEmptyMessage(
                          'No pending bookings.',
                        ),
                        controller: _bookingScrollControllers[0],
                        refreshKey: _bookingRefreshKeys[0],
                      ),
                      Column(
                        children: [
                          if (_selectedBookingTab == 1)
                            _approvedPaymentFilters(
                              approved.length,
                              filteredApproved.length,
                            ),
                          Expanded(
                            child: _bookingTab(
                              filteredApproved,
                              emptyMessage: _bookingEmptyMessage(
                                _approvedPaymentFilter == 'paid'
                                    ? 'No fully paid bookings.'
                                    : _approvedPaymentFilter == 'payable'
                                    ? 'No payable bookings.'
                                    : 'No approved bookings.',
                              ),
                              controller: _bookingScrollControllers[1],
                              refreshKey: _bookingRefreshKeys[1],
                            ),
                          ),
                        ],
                      ),
                      _bookingTab(
                        completed,
                        emptyMessage: _bookingEmptyMessage(
                          'No completed bookings.',
                        ),
                        controller: _bookingScrollControllers[2],
                        refreshKey: _bookingRefreshKeys[2],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 3,
        hideSavedDestination: true,
        showHomeDestination: true,
        unreadMessageCount: _unreadMessageCount,
        unreadBookingCount: _unreadBookingCount,
        onDestinationReselected: _refreshAndScrollToTop,
        onDestinationSelected: (index) {
          if (index == 3) return;
          if (index == 5) {
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => CustomerHomePage(
                  onLogout: widget.onLogout,
                  api: widget.api,
                  initialUserPosition: widget.initialUserPosition,
                  businessType: widget.businessType,
                ),
              ),
            );
            return;
          }
          if (index == 0) {
            _openExplore();
            return;
          }
          if (index == 1) {
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => SavedDashboardPage(
                  onLogout: widget.onLogout,
                  itemType: SavedDashboardPage.itemTypeForBusinessType(
                    widget.businessType,
                  ),
                  initialUserPosition: widget.initialUserPosition,
                ),
              ),
            );
            return;
          }
          if (index == 2) {
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => MessagesDashboardPage(
                  initialUserPosition: widget.initialUserPosition,
                  businessType: widget.businessType,
                ),
              ),
            );
            return;
          }
          _replaceWith(
            MaterialPageRoute(
              builder: (_) => ProfileDashboardPage(
                onLogout: widget.onLogout,
                initialUserPosition: widget.initialUserPosition,
                businessType: widget.businessType,
              ),
            ),
          );
        },
      ),
    );
  }

  String _bookingStatus(Booking booking) =>
      CustomerBookingController.bookingStatus(booking);

  bool _awaitingApprovalPayment(Booking booking) =>
      CustomerBookingController.awaitingApprovalPayment(booking);

  double _prototypePayableAmount(Booking booking) =>
      CustomerBookingController.prototypePayableAmount(booking);

  String _bookingStatusKey(Booking booking) =>
      CustomerBookingController.bookingStatusKey(booking);

  String _formatTime(dynamic value) {
    final raw = '$value'.trim();
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    return _clockLabel(hour, minute);
  }

  String _clockLabel(int hour, int minute) {
    final normalizedHour = hour % 24;
    final period = normalizedHour >= 12 ? 'PM' : 'AM';
    final displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _bookingStatusBanner(List<Booking> approved, List<Booking> completed) {
    final booking =
        _activeBookingStatusBannerBooking ??
        (completed.isNotEmpty ? completed.first : approved.first);
    final status = _bookingStatus(booking);
    final isCompleted = {'finished', 'done', 'completed'}.contains(status);
    final isInactive = {'expired', 'cancelled'}.contains(status);
    final isExpired = status == 'expired';
    final isAwaitingPayment = _awaitingApprovalPayment(booking);

    return BookingStatusBanner(
      booking: booking,
      status: status,
      isCompleted: isCompleted,
      isInactive: isInactive,
      isExpired: isExpired,
      isAwaitingPayment: isAwaitingPayment,
      onRefresh: _refresh,
      onDismiss: _dismissBookingStatusBanner,
      prototypePayableAmount: _prototypePayableAmount,
      formatTime: _formatTime,
    );
  }

  Widget _bookingTab(
    List<Booking> bookings, {
    required String emptyMessage,
    required ScrollController controller,
    required GlobalKey<RefreshIndicatorState> refreshKey,
  }) {
    return RefreshIndicator(
      key: refreshKey,
      onRefresh: _refresh,
      child: bookings.isEmpty
          ? ListView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(child: AppText(emptyMessage, localize: true)),
              ],
            )
          : ListView.separated(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) => _bookingCard(bookings[index]),
            ),
    );
  }

  bool _matchesBookingSearch(Booking booking) =>
      CustomerBookingController.matchesBookingSearch(
        booking,
        _bookingSearchQuery,
      );

  String _bookingEmptyMessage(String defaultMessage) =>
      _bookingSearchQuery.trim().isEmpty
      ? defaultMessage
      : 'No bookings match your search.';

  void _replaceWith(Route<void> route) {
    Navigator.of(context).pushReplacement(route);
  }

  Future<void> _openExplore() async {
    if (!mounted) return;
    _replaceWith(
      MaterialPageRoute(
        builder: (_) => switch (BusinessTypeParser.parse(widget.businessType)) {
          BusinessType.event => EventDashboardPage(
            onLogout: widget.onLogout,
            api: widget.api,
            initialUserPosition: widget.initialUserPosition,
          ),
          BusinessType.fitness => FitnessDashboardPage(
            onLogout: widget.onLogout,
            api: widget.api,
            initialUserPosition: widget.initialUserPosition,
          ),
          _ => NewsFeedPage(
            onLogout: widget.onLogout,
            initialUserPosition: widget.initialUserPosition,
            businessType: widget.businessType ?? 'Sports',
          ),
        },
      ),
    );
  }

  Widget _approvedPaymentFilters(int total, int visible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          for (final filter in const [
            ('all', 'All'),
            ('payable', 'Payable'),
            ('paid', 'Fully paid'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('approved-payment-filter-${filter.$1}'),
                label: AppText(filter.$2, localize: true),
                selected: _approvedPaymentFilter == filter.$1,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _approvedPaymentFilter = filter.$1);
                  }
                },
              ),
            ),
          const Spacer(),
          AppText(
            '$visible / $total',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  int _compareApprovedPaymentPriority(Booking first, Booking second) {
    final firstPaid = first.paymentStatus.toLowerCase() == 'paid';
    final secondPaid = second.paymentStatus.toLowerCase() == 'paid';
    if (firstPaid != secondPaid) return firstPaid ? 1 : -1;
    final firstDue = DateTime.tryParse(first.paymentDueAt);
    final secondDue = DateTime.tryParse(second.paymentDueAt);
    if (firstDue != null && secondDue != null) {
      return firstDue.compareTo(secondDue);
    }
    if (firstDue != null) return -1;
    if (secondDue != null) return 1;
    return 0;
  }

  Future<void> _payBookingPrototype(Booking booking) async {
    final paymentProvider = await showDialog<String>(
      context: context,
      builder: (_) =>
          PrototypePaymentDialog(amount: _prototypePayableAmount(booking)),
    );
    if (paymentProvider == null || !mounted) return;
    try {
      final token = (await _sessionProvider.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in again to complete this payment.',
          401,
        );
      }
      await _api.recordPrototypeBookingPayment(
        token: token,
        bookingId: booking.id!,
        provider: paymentProvider,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Prototype payment recorded. No real payment was processed.',
            localize: true,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _bookingErrorMessage(error, 'start this payment'),
            localize: true,
          ),
        ),
      );
    }
  }

  Widget _bookingCard(Booking booking) {
    final status = _bookingStatus(booking);
    final canPayBookingPrototype = _awaitingApprovalPayment(booking);
    final paymentDeadline = DateTime.tryParse(booking.paymentDueAt);
    final approvalDeadline = parseBookingApprovalDeadline(
      booking['approvalExpiresAt'],
    );
    final images = _imageUrls(booking);
    final type = '${booking['businessType'] ?? ''}'.trim();
    final category = '${booking['category'] ?? ''}'.trim();
    final rate = _venueRateLabel(booking);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: Stack(
              children: [
                _BookingGallery(images: images),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _imageBadge(
                    type.isEmpty ? 'Booking' : type,
                    AppColors.surface.withValues(alpha: .94),
                    AppColors.ink,
                  ),
                ),
                if (category.isNotEmpty)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _imageBadge(
                      category,
                      AppColors.accent,
                      AppColors.onAccent,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookingCardHeader(
                  booking: booking,
                  status: status,
                  canPayBookingPrototype: canPayBookingPrototype,
                  statusColor: _statusColor,
                  statusGuidance: _statusGuidance,
                  statusLabel: _statusLabel,
                  onCancel: booking.id == null
                      ? null
                      : () => _cancelCustomerBooking(booking),
                  onDetails: () => _showBookingInfo(booking),
                  approvalDeadline: approvalDeadline,
                  paymentDeadline: paymentDeadline,
                  paymentRefundGuidance: _paymentRefundGuidance,
                  prototypePayableAmount: _prototypePayableAmount,
                  formatBookingApprovalDeadline: (deadline) => deadline == null
                      ? '—'
                      : formatBookingApprovalDeadline(deadline),
                ),
                const SizedBox(height: 6),
                _venueDetail(Icons.location_on_outlined, booking['address']),
                _venueDetail(Icons.access_time_rounded, booking['hours']),
                if (rate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoPanel('Venue rate', rate),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status, {bool awaitingPayment = false}) =>
      awaitingPayment
      ? 'Approved · payment due'
      : switch (status.toLowerCase()) {
          'pending' => 'Awaiting approval',
          'approved' => 'Confirmed',
          'finished' || 'done' || 'completed' => 'Completed',
          'expired' => 'Expired',
          'cancelled' => 'Cancelled',
          _ =>
            status
                .split(RegExp(r'[_\s]+'))
                .where((part) => part.isNotEmpty)
                .map(
                  (part) =>
                      '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
                )
                .join(' '),
        };

  Color _statusColor(String status, {bool awaitingPayment = false}) =>
      awaitingPayment
      ? const Color(0xFFB85C00)
      : switch (status.toLowerCase()) {
          'pending' => const Color(0xFFB85C00),
          'approved' ||
          'finished' ||
          'done' ||
          'completed' => const Color(0xFF18794E),
          'expired' || 'cancelled' => const Color(0xFFB42318),
          _ => const Color(0xFF475467),
        };

  String _statusGuidance(String status, {bool awaitingPayment = false}) =>
      awaitingPayment
      ? 'The venue approved this booking. Pay the required amount using the test payment form before the payment deadline, or the reservation will expire.'
      : switch (status.toLowerCase()) {
          'pending' =>
            'Waiting for the venue to approve your request. Not confirmed yet.',
          'approved' => 'Confirmed by the venue. Your booking is ready.',
          'finished' ||
          'done' ||
          'completed' => 'This booking has been completed.',
          'expired' => 'This reservation expired because payment was not received before the payment deadline.',
          'cancelled' =>
            'This booking was cancelled and is no longer reserved.',
          _ => 'Check the booking details or contact the venue for an update.',
        };

  Widget _imageBadge(String text, Color background, Color foreground) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: AppText(
            text,
            localize: true,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  Future<void> _showRatingDialog(
    Booking booking, {
    bool closeDetailsOnSubmit = false,
  }) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _BookingRatingDialog(
        booking: booking,
        api: _api,
        sessionProvider: _sessionProvider,
      ),
    );
    if (!mounted || submitted != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AppText('Your rating was submitted.', localize: true),
      ),
    );
    await _refresh();
    if (closeDetailsOnSubmit && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteBooking(Booking booking) async {
    final isCancelled = '${booking['status']}'.toLowerCase() == 'cancelled';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          isCancelled
              ? 'Delete cancelled booking?'
              : 'Delete completed booking?',
          localize: true,
        ),
        content: AppText(
          isCancelled
              ? 'This permanently deletes the cancelled booking from your history. This action cannot be undone.'
              : 'This permanently deletes the booking and its attendance and review records. This action cannot be undone.',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep booking', localize: true),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete permanently', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await _sessionProvider.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in again to delete this booking.',
          401,
        );
      }
      final bookingId = booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be deleted right now.',
          400,
        );
      }
      await _api.deleteCustomerBooking(token: token, bookingId: bookingId);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Booking permanently deleted.', localize: true),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _bookingErrorMessage(error, 'delete this booking'),
            localize: true,
          ),
        ),
      );
    }
  }

  Future<void> _cancelCustomerBooking(Booking booking) async {
    final paymentWarning = _cancellationPaymentWarning(booking);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Cancel this booking?', localize: true),
        content: AppText(
          'You can cancel this booking at any time before it is completed. '
          '$paymentWarning',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep booking', localize: true),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Cancel booking', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await _sessionProvider.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in again to cancel this booking.',
          401,
        );
      }
      final bookingId = booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be cancelled right now.',
          400,
        );
      }
      final result = await _api.cancelCustomerBooking(
        token: token,
        bookingId: bookingId,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '${result['message'] ?? 'Booking cancelled.'}',
            localize: true,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _bookingErrorMessage(error, 'cancel this booking'),
            localize: true,
          ),
        ),
      );
    }
  }

  String _cancellationPaymentWarning(Booking booking) {
    if (booking.paymentMethod == 'cash_on_arrival' && booking.paidAmount > 0) {
      return 'Cash already collected cannot be voided by the app; it must be '
          'returned manually.';
    }
    if (booking.paymentMethod == 'cash_on_arrival') {
      return 'Any cash already collected must be returned manually; the app '
          'cannot void cash payments.';
    }
    if (booking.paymentStatus.toLowerCase() != 'paid' ||
        booking.paymentMethod != 'online') {
      return 'Any online payment completed after cancellation will be handled '
          'under the same cancellation policy.';
    }
    final start = _bookingStartDateTime(booking);
    if (start == null) {
      return 'The payment refund eligibility will be checked using the '
          'booking start time.';
    }
    final timeUntilStart = start.difference(DateTime.now());
    if (timeUntilStart >= const Duration(hours: 6)) {
      return 'The booking is at least 6 hours away, so the online payment '
          'refund will be requested.';
    }
    return 'Because the booking starts in less than 6 hours or has already '
        'started, the online payment cannot be voided or refunded.';
  }

  DateTime? _bookingStartDateTime(Booking booking) {
    final time = booking.startTime.length >= 5
        ? booking.startTime.substring(0, 5)
        : booking.startTime;
    return DateTime.tryParse('${booking.date}T$time');
  }

  String _paymentRefundGuidance(String status) => switch (status) {
    'pending' => 'Online payment refund is being processed.',
    'succeeded' => 'Online payment refund completed.',
    'failed' =>
      'Online payment refund could not be confirmed. Please contact support.',
    'not_eligible' => 'Payment was not refunded because the booking starts within 6 hours or has started.',
    'manual_cash_return' => 'Cash already collected must be returned manually; it cannot be voided by the app.',
    _ => '',
  };

  Widget _infoPanel(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.page,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE7EBF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          appLanguageText(
            label,
            label,
            languageCode: Localizations.localeOf(context).languageCode,
          ).toUpperCase(),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          value,
          localize: true,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  String _venueRateLabel(Booking booking) {
    final periods = booking['ratePeriods'];
    if (periods is List && periods.isNotEmpty) {
      final labels = periods.whereType<Map>().map((period) {
        final start = period['start'] ?? '';
        final end = period['end'] ?? '';
        final price = _amount(period['pricePerHour']);
        return '$start - $end · \u{20B1} ${price.toStringAsFixed(2)} / hr';
      }).toList();
      if (labels.isNotEmpty) return labels.join('\n');
    }

    final value = _amount(booking['venuePricePerHour']);
    if (value > 0) return '\u{20B1} ${value.toStringAsFixed(2)} / hr';
    final fee = _amount(booking['eventFee']);
    return fee > 0 ? '\u{20B1} ${fee.toStringAsFixed(2)} per booking' : '';
  }

  double _amount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _showBookingInfo(Booking booking) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.page,
          appBar: AppBar(
            title: const AppText(
              'Booking details',
              style: TextStyle(fontWeight: FontWeight.w900),
              localize: true,
            ),
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: _bookingDetailsCard(booking),
          ),
        ),
      ),
    );
  }

  Widget _bookingDetailsCard(Booking booking) {
    return BookingDetailsPanel(
      booking: booking,
      onDeleteBooking: _deleteBooking,
      onPayBookingPrototype: _payBookingPrototype,
      onReviewBooking: _showRatingDialog,
      formatBookingApprovalDeadline: formatBookingApprovalDeadline,
    );
  }

  List<String> _imageUrls(Booking booking) {
    final images = <String>[];
    final raw = booking['imageUrls'];
    if (raw is List) {
      images.addAll(raw.map((value) => '$value').where(_validImage));
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          images.addAll(decoded.map((value) => '$value').where(_validImage));
        }
      } on FormatException {
        if (_validImage(raw)) images.add(raw.trim());
      }
    }

    final direct = '${booking['imageUrl'] ?? ''}'.trim();
    if (images.isEmpty && _validImage(direct)) {
      try {
        final decoded = jsonDecode(direct);
        if (decoded is List) {
          images.addAll(decoded.map((value) => '$value').where(_validImage));
        } else {
          images.add(direct);
        }
      } on FormatException {
        images.add(direct);
      }
    }
    return images.isEmpty ? ['assets/court/pickle-court.jpg'] : images;
  }

  bool _validImage(String value) {
    final image = value.trim();
    return image.isNotEmpty && image != 'null';
  }

  Widget _venueDetail(IconData icon, dynamic value) {
    final text = '$value'.trim();
    if (value == null || text.isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: AppText(
              text,
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingRatingDialog extends StatefulWidget {
  const _BookingRatingDialog({
    required this.booking,
    required this.api,
    required this.sessionProvider,
  });

  final Booking booking;
  final AuthApi api;
  final CustomerBookingsSessionProvider sessionProvider;

  @override
  State<_BookingRatingDialog> createState() => _BookingRatingDialogState();
}

class _BookingRatingDialogState extends State<_BookingRatingDialog> {
  final _comment = TextEditingController();
  final _imagePicker = ImagePicker();
  var _rating = 0;
  var _submitting = false;
  String? _error;
  Uint8List? _imageBytes;
  String? _imageData;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = 'Choose a review photo smaller than 5 MB.');
        return;
      }
      final mime = image.mimeType ?? 'image/jpeg';
      if (!mime.startsWith('image/')) {
        setState(() => _error = 'Choose a valid image file.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageData = 'data:$mime;base64,${base64Encode(bytes)}';
        _error = null;
      });
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'We couldn’t open your photos. Please try again.',
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageData = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final token = (await widget.sessionProvider.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in to rate this booking.',
          401,
        );
      }
      final bookingId = widget.booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be rated because its ID is missing.',
          400,
        );
      }
      await widget.api.venues.submitCustomerReview(
        token: token,
        bookingId: bookingId,
        rating: _rating,
        comment: _comment.text.trim(),
        imageData: _imageData,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _bookingErrorMessage(error, 'submit your review');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.secondary;
    final ratingLabel = switch (_rating) {
      1 => 'Needs improvement',
      2 => 'Could be better',
      3 => 'Good',
      4 => 'Great',
      5 => 'Excellent',
      _ => null,
    };
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: (screen.height - keyboardHeight) * .86,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.rate_review_outlined, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Share your experience',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            localize: true,
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            widget.booking.venue.name,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: appLanguageText('Close', 'Close'),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'How was your completed booking?',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                        localize: true,
                      ),
                      const SizedBox(height: 8),
                      AppRatingInput(
                        rating: _rating,
                        onChanged: (rating) => setState(() => _rating = rating),
                        keyPrefix: 'booking-review-star-',
                        tooltipForRating: (rating) => appLanguageText(
                          '$rating stars',
                          '$rating stars',
                          languageCode: Localizations.localeOf(context)
                              .languageCode,
                        ),
                        enabled: !_submitting,
                        size: 38,
                        color: accent,
                      ),
                      if (_rating == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: AppText(
                              'Choose a star rating to continue.',
                              style: TextStyle(color: AppColors.muted),
                              localize: true,
                            ),
                          ),
                        )
                      else if (ratingLabel != null)
                        Center(
                          child: Container(
                            key: const ValueKey('booking-review-rating-label'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: AppText(
                              '$ratingLabel · $_rating/5',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _comment,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          alignLabelWithHint: true,
                          labelText: appLanguageText(
                            'Your review',
                            'Your review',
                          ),
                          hintText: appLanguageText(
                            'What did you enjoy about your visit?',
                            'What did you enjoy about your visit?',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_imageBytes case final imageBytes?) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withValues(alpha: .45),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              imageBytes,
                              key: const ValueKey(
                                'booking-review-image-preview',
                              ),
                              width: double.infinity,
                              height: 190,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _submitting ? null : _removeImage,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: accent,
                            ),
                            label: const AppText(
                              'Remove photo',
                              localize: true,
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('booking-review-add-image'),
                            onPressed: _submitting ? null : _pickImage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(
                                color: accent.withValues(alpha: .55),
                              ),
                              backgroundColor: accent.withValues(alpha: .06),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            icon: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: accent,
                            ),
                            label: const AppText('Add a photo', localize: true),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          'Optional · JPG, PNG or WebP · Up to 5 MB',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        AppText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const AppText('Cancel', localize: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _rating == 0 || _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: AppText(
                          _submitting ? 'Submitting...' : 'Submit review',
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
      ),
    );
  }
}
