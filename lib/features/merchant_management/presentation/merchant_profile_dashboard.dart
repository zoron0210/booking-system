import 'dart:async';

import 'package:flutter/material.dart';

import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/features/activity_log/presentation/activity_log_routes.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/data/merchant_booking_repository.dart';
import 'package:myapp/features/merchant_management/data/merchant_session_provider.dart';
import 'package:myapp/features/merchant_management/domain/merchant_profile_performance.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_profile_dialogs.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_profile_performance_card.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_navigation_drawer.dart';
import 'package:myapp/features/notifications/data/booking_push_notifications.dart';
import 'package:myapp/features/settings/presentation/app_settings_page.dart';
import 'package:myapp/features/notifications/data/booking_notifications.dart';
import 'package:myapp/features/notifications/presentation/booking_transaction_notification_settings.dart';
import 'package:myapp/features/notifications/presentation/notification_settings_page.dart';
import 'package:myapp/core/profile_image_preview.dart';
import 'package:myapp/core/rating_widgets.dart';

Color get _profileInk => AppColors.ink;
Color get _profileMuted => AppColors.muted;
Color get _profileLine => AppColors.border;
Color get _profileAccent => AppColors.accentForeground;

enum _MerchantProfileSetting {
  editProfile,
  bookingDeadlines,
  venueCheckIn,
  activityLog,
  appPreferences,
  switchToCustomerPortal,
  helpCenter,
  termsOfService,
  logOut,
}

class MerchantProfileDashboardPage extends StatefulWidget {
  const MerchantProfileDashboardPage({
    super.key,
    required this.owner,
    required this.profileImage,
    required this.venueCount,
    this.bookings = const [],
    this.businesses = const [],
    required this.onLogout,
    required this.onEditProfile,
    this.api,
    this.bookingRepository,
    this.onNavigate,
    this.onSwitchToCustomerPortal,
    this.openBookingDeadlinesOnStart = false,
    this.openSettingsOnStart = false,
    this.sessionProvider,
  });

  final Map<String, dynamic> owner;
  final ImageProvider<Object>? profileImage;
  final int venueCount;
  final List<Map<String, dynamic>> bookings;
  final List<Map<String, dynamic>> businesses;
  final Future<void> Function(BuildContext context) onLogout;
  final Future<Map<String, dynamic>?> Function() onEditProfile;
  final AuthApi? api;
  final MerchantBookingRepository? bookingRepository;
  final ValueChanged<int>? onNavigate;
  final Future<void> Function(BuildContext context)? onSwitchToCustomerPortal;
  final bool openBookingDeadlinesOnStart;
  final bool openSettingsOnStart;
  final MerchantSessionProvider? sessionProvider;

  @override
  State<MerchantProfileDashboardPage> createState() =>
      _MerchantProfileDashboardPageState();
}

class _MerchantProfileDashboardPageState
    extends State<MerchantProfileDashboardPage> {
  late Map<String, dynamic> _owner;
  late ImageProvider<Object>? _profileImage;
  late final AuthApi _api;
  late final MerchantSessionProvider _sessionProvider;
  late final MerchantBookingRepository _bookingRepository;
  late List<Map<String, dynamic>> _bookings;
  late List<Map<String, dynamic>> _businesses;
  final _profileRefreshKey = GlobalKey<RefreshIndicatorState>();
  final _profileScrollController = ScrollController();
  String _performancePeriod = 'Today';
  bool _matchNotificationsEnabled = false;
  bool _updatingMatchNotificationSetting = false;
  late bool _settingsVisible;

  MerchantProfilePerformance get _performance =>
      MerchantProfilePerformance.calculate(
        bookings: _bookings,
        period: _performancePeriod,
        now: DateTime.now(),
      );

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _sessionProvider = widget.sessionProvider ?? AppMerchantSessionProvider();
    _bookingRepository =
        widget.bookingRepository ?? AuthApiMerchantBookingRepository(api: _api);
    _owner = widget.owner;
    _profileImage = widget.profileImage;
    _bookings = widget.bookings;
    _businesses = widget.businesses;
    _settingsVisible = widget.openSettingsOnStart;
    _loadMatchNotificationSetting();
    if (widget.openBookingDeadlinesOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editBookingDeadlines();
      });
    }
  }

  @override
  void dispose() {
    _profileScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshAndScrollToTop() async {
    final refresh = _profileRefreshKey.currentState?.show();
    if (refresh != null) {
      await refresh;
    } else {
      await _refreshProfileData();
    }
    if (!mounted) return;
    if (_profileScrollController.hasClients) {
      await _profileScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _refreshProfileData() async {
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await _api.merchantProfile(token);
      final businesses = await _api.merchantBusinesses(token);
      final bookings = await _bookingRepository.loadBookings();
      if (!mounted) return;
      setState(() {
        _owner = response['profile'] as Map<String, dynamic>? ?? {};
        _businesses = businesses;
        _bookings = bookings;
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh merchant profile: $error')),
        );
      }
    }
  }

  Future<void> _loadMatchNotificationSetting() async {
    try {
      final session = await _sessionProvider.load();
      if (!mounted) return;
      setState(
        () => _matchNotificationsEnabled = session.matchNotificationsEnabled,
      );
      final notifications = BookingNotifications.instance;
      if (!_matchNotificationsEnabled || !notifications.isSupported) return;

      final allowed = await notifications.notificationsAllowed();
      if (!mounted) return;
      if (!allowed) {
        await session.setMatchNotificationsEnabled(false);
        if (!mounted) return;
        setState(() => _matchNotificationsEnabled = false);
      } else {
        await notifications.synchronizeApprovedBookings(
          accountKey: session.accountEmail ?? _merchantEmail,
          bookings: widget.bookings,
        );
      }
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not check match alerts: $error');
    }
  }

  Future<void> _setMatchNotificationsEnabled(
    bool enabled, {
    required BuildContext settingsContext,
    required StateSetter setSettingsState,
  }) async {
    if (_updatingMatchNotificationSetting) return;
    setState(() => _updatingMatchNotificationSetting = true);
    if (settingsContext.mounted) {
      setSettingsState(() => _updatingMatchNotificationSetting = true);
    }
    try {
      final session = await _sessionProvider.load();
      final notifications = BookingNotifications.instance;
      if (enabled) {
        final granted = await notifications.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const AppText(
                    'Allow notifications and exact alarms to receive match alerts.',
                    localize: true,
                  ),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () => unawaited(_openNotificationSettings()),
                  ),
                ),
              );
          }
          return;
        }
        await notifications.synchronizeApprovedBookings(
          accountKey: session.accountEmail ?? _merchantEmail,
          bookings: widget.bookings,
        );
      } else {
        await notifications.disableForAccount(
          session.accountEmail ?? _merchantEmail,
        );
      }
      await session.setMatchNotificationsEnabled(enabled);
      if (!mounted) return;
      setState(() => _matchNotificationsEnabled = enabled);
      if (settingsContext.mounted) {
        setSettingsState(() => _matchNotificationsEnabled = enabled);
      }
      _showMessage(
        enabled
            ? 'Match start and end alerts are enabled.'
            : 'Match start and end alerts are turned off.',
      );
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not update match alerts: $error');
    } finally {
      if (mounted) {
        setState(() => _updatingMatchNotificationSetting = false);
        if (settingsContext.mounted) {
          setSettingsState(() => _updatingMatchNotificationSetting = false);
        }
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      final opened = await BookingNotifications.instance
          .openSystemNotificationSettings();
      if (opened != true && mounted) {
        _showMessage('Could not open notification settings.');
      }
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not open notification settings: $error');
      }
    }
  }

  Future<void> _openInAppNotificationSettings(
    BuildContext settingsContext,
  ) async {
    await Navigator.of(settingsContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationSettingsPage(
          settingsBuilder: (context, setSettingsState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (BookingNotifications.instance.isSupported)
                _matchNotificationControl(
                  settingsContext: context,
                  setSettingsState: setSettingsState,
                ),
              if (BookingPushNotifications.instance.isSupported)
                BookingTransactionNotificationSettings(
                  api: _api,
                  onMessage: _showMessage,
                ),
            ],
          ),
          onOpenSystemSettings: () => unawaited(_openNotificationSettings()),
        ),
      ),
    );
  }

  Widget _matchNotificationControl({
    required BuildContext settingsContext,
    required StateSetter setSettingsState,
  }) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: _profileLine),
    ),
    clipBehavior: Clip.antiAlias,
    child: SwitchListTile.adaptive(
      key: const ValueKey('merchant-match-notifications-switch'),
      value: _matchNotificationsEnabled,
      onChanged: _updatingMatchNotificationSetting
          ? null
          : (enabled) => _setMatchNotificationsEnabled(
              enabled,
              settingsContext: settingsContext,
              setSettingsState: setSettingsState,
            ),
      activeThumbColor: AppColors.accent,
      secondary: Icon(
        Icons.notifications_active_outlined,
        color: _profileAccent,
      ),
      title: AppText(
        'Match notifications',
        style: TextStyle(
          color: _profileInk,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        localize: true,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    ),
  );

  String get _merchantEmail =>
      (_owner['email'] as String?) ?? 'Merchant account';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_settingsVisible) return _settingsPage();

    final owner = _owner;
    final name = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
        .trim();
    final email = '${owner['email'] ?? ''}'.trim();
    final phone = '${owner['phone'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: AppColors.page,
      drawer: MerchantNavigationDrawer(
        owner: owner,
        profileImage: _profileImage,
        selectedIndex: 4,
        onDestinationSelected: _selectMerchantDrawerDestination,
        onSettingsSelected: _openSettings,
        onLogout: widget.onLogout,
        onHelpCenterSelected: () =>
            unawaited(_handleSetting(_MerchantProfileSetting.helpCenter)),
        onTermsOfServiceSelected: () =>
            unawaited(_handleSetting(_MerchantProfileSetting.termsOfService)),
      ),
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        leadingWidth: 56,
        leading: Builder(
          builder: (context) => IconButton(
            key: const ValueKey('merchant-sidebar-toggle'),
            tooltip: 'Open merchant menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleTextStyle: AppTypography.pageTitle,
        title: Row(
          children: [
            Flexible(
              child: AppText(
                appLanguageText('Merchant Profile', 'Profile ng Merchant'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.pageTitle,
              ),
            ),
            IconButton(
              key: const ValueKey('merchant-profile-info'),
              tooltip: appLanguageText(
                'About merchant profile',
                'About merchant profile',
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const AppText('Merchant Profile', localize: true),
                  content: const AppText(
                    'Manage your account and keep track of your venues.',
                    localize: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const AppText('Got it', localize: true),
                    ),
                  ],
                ),
              ),
              icon: Icon(
                Icons.info_outline_rounded,
                color: _profileMuted,
                size: 19,
              ),
              visualDensity: VisualDensity.compact,
              padding: AppSpacing.buttonPadding,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ],
        ),
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _profileInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        key: _profileRefreshKey,
        onRefresh: _refreshProfileData,
        child: ListView(
          controller: _profileScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const SizedBox(height: 6),
            _profileCard(name, email, phone),
            const SizedBox(height: 6),
            _businessOverviewCard(),
            const SizedBox(height: 6),
            _performanceCard(),
            const SizedBox(height: 6),
            _quickToolsCard(),
          ],
        ),
      ),
    );
  }

  void _selectMerchantDrawerDestination(int index) {
    if (index == 4) {
      unawaited(_refreshAndScrollToTop());
      return;
    }
    widget.onNavigate?.call(index);
    Navigator.of(context).pop();
  }

  void _openSettings() {
    setState(() => _settingsVisible = true);
  }

  Widget _settingsPage() => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      leading: IconButton(
        key: const ValueKey('merchant-settings-close'),
        tooltip: appLanguageText('Close settings', 'Close settings'),
        onPressed: () {
          if (widget.openSettingsOnStart) {
            Navigator.of(context).pop();
          } else {
            setState(() => _settingsVisible = false);
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Row(
        children: [
          const Icon(Icons.settings_outlined, color: Color(0xFFFF8200)),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              appLanguageText('Settings', 'Mga Setting'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Divider(height: 1, color: _profileLine),
                const SizedBox(height: 6),
                if (BookingNotifications.instance.isSupported ||
                    BookingPushNotifications.instance.isSupported)
                  ListTile(
                    key: const ValueKey('merchant-settings-notifications'),
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: AppText(
                      appLanguageText(
                        'Notification settings',
                        'Mga setting ng notification',
                      ),
                    ),
                    subtitle: const AppText(
                      'Manage booking and match alerts',
                      localize: true,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openInAppNotificationSettings(context),
                  ),
                ListTile(
                  key: const ValueKey('merchant-settings-appearance'),
                  leading: const Icon(Icons.palette_outlined),
                  title: AppText(
                    appLanguageText('Appearance & language', 'Hitsura at wika'),
                  ),
                  onTap: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.appPreferences),
                  ),
                ),
                ListTile(
                  key: const ValueKey('merchant-settings-edit-profile'),
                  leading: const Icon(Icons.edit_outlined),
                  title: AppText(
                    appLanguageText('Edit profile', 'I-edit ang profile'),
                  ),
                  onTap: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.editProfile),
                  ),
                ),
                if (widget.onSwitchToCustomerPortal != null)
                  ListTile(
                    key: const ValueKey('merchant-settings-switch-to-customer'),
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const AppText(
                      'Switch to customer portal',
                      localize: true,
                    ),
                    onTap: () => unawaited(
                      _handleSetting(
                        _MerchantProfileSetting.switchToCustomerPortal,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      appLanguageText('VENUE TOOLS', 'MGA TOOL SA VENUE'),
                      style: TextStyle(
                        color: _profileMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  key: const ValueKey('merchant-settings-venue-check-in'),
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const AppText(
                    'Venue arrival check-in',
                    localize: true,
                  ),
                  subtitle: const AppText(
                    'Show a venue QR code to record customer arrivals',
                    localize: true,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.venueCheckIn),
                  ),
                ),
                ListTile(
                  key: const ValueKey('merchant-settings-booking-deadlines'),
                  leading: const Icon(Icons.timer_outlined),
                  title: AppText(
                    appLanguageText(
                      'Booking deadlines',
                      'Mga deadline ng booking',
                    ),
                  ),
                  subtitle: AppText(
                    appLanguageText(
                      'Set approval and payment time limits',
                      'Itakda ang oras para sa pag-apruba at pagbabayad',
                    ),
                  ),
                  onTap: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.bookingDeadlines),
                  ),
                ),
                ListTile(
                  key: const ValueKey('merchant-settings-activity-log'),
                  leading: const Icon(Icons.history_rounded),
                  title: AppText(
                    appLanguageText('Activity log', 'Tala ng aktibidad'),
                  ),
                  onTap: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.activityLog),
                  ),
                ),
                ListTile(
                  key: const ValueKey('merchant-settings-logout'),
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: AppText(
                    appLanguageText('Log out', 'Mag-log out'),
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () =>
                      unawaited(_handleSetting(_MerchantProfileSetting.logOut)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _profileLine),
        ],
      ),
    ),
  );

  Future<void> _handleSetting(_MerchantProfileSetting setting) async {
    switch (setting) {
      case _MerchantProfileSetting.bookingDeadlines:
        await _editBookingDeadlines();
        return;
      case _MerchantProfileSetting.venueCheckIn:
        await _showVenueCheckInQr();
        return;
      case _MerchantProfileSetting.editProfile:
        final updated = await widget.onEditProfile();
        if (!mounted || updated == null) return;
        setState(() {
          _owner = Map<String, dynamic>.from(updated['owner'] as Map);
          _profileImage = updated['profileImage'] as ImageProvider<Object>?;
        });
        return;
      case _MerchantProfileSetting.activityLog:
        await Navigator.of(context)
            .push(ActivityLogRoutes.open(api: widget.api, isMerchant: true));
        return;
      case _MerchantProfileSetting.appPreferences:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AppSettingsPage(preferences: AppPreferences.instance),
          ),
        );
        return;
      case _MerchantProfileSetting.switchToCustomerPortal:
        await widget.onSwitchToCustomerPortal?.call(context);
        return;
      case _MerchantProfileSetting.helpCenter:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MerchantSupportDetailPage(
              title: 'Help Center',
              icon: Icons.help_outline_rounded,
              message: 'Help articles and contact options will be available here soon.',
            ),
          ),
        );
        return;
      case _MerchantProfileSetting.termsOfService:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MerchantSupportDetailPage(
              title: 'Terms of Service',
              icon: Icons.description_outlined,
              message:
                  'The official Terms of Service will be available here soon.',
            ),
          ),
        );
        return;
      case _MerchantProfileSetting.logOut:
        await widget.onLogout(context);
        return;
    }
  }

  Future<void> _showVenueCheckInQr() async {
    if (widget.businesses.isEmpty) {
      _showProfileMessage('Add a venue before generating a check-in QR.');
      return;
    }
    final venueId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const AppText('Choose venue', localize: true),
        children: [
          for (final business in widget.businesses)
            SimpleDialogOption(
              key: ValueKey('merchant-checkin-venue-${business['id']}'),
              onPressed: () {
                final id = business['id'];
                if (id is num) Navigator.of(dialogContext).pop(id.toInt());
              },
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: AppText('${business['name'] ?? 'Venue'}')),
                ],
              ),
            ),
        ],
      ),
    );
    if (!mounted || venueId == null) return;

    try {
      final session = await _sessionProvider.load();
      if (!mounted) return;
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        _showProfileMessage('Sign in again to generate a venue check-in QR.');
        return;
      }
      final venue = widget.businesses.firstWhere(
        (business) => int.tryParse('${business['id']}') == venueId,
        orElse: () => <String, dynamic>{},
      );
      if (venue.isEmpty) {
        _showProfileMessage(
          'That venue is no longer available. Refresh and try again.',
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => MerchantCheckInQrDialog(
          api: _api,
          token: token,
          venueId: venueId,
          venueName: '${venue['name'] ?? 'Venue'}',
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        _showProfileMessage(
          error is AuthApiException
              ? error.userMessage
              : 'Could not open the venue check-in QR: $error',
        );
      }
    }
  }

  Future<void> _editBookingDeadlines() async {
    final session = await _sessionProvider.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      _showProfileMessage('Your session has expired.');
      return;
    }

    try {
      final settings = await _api.merchantBookingDeadlines(token);
      if (!mounted) return;
      final approvalMinutes = _deadlineInputValue(
        settings['approvalTimeoutMinutes'],
      );
      final paymentMinutes = _deadlineInputValue(
        settings['paymentTimeoutMinutes'],
      );
      final deadlines =
          await showDialog<
            ({int approvalTimeoutMinutes, int paymentTimeoutMinutes})
          >(
            context: context,
            builder: (_) => BookingDeadlineDialog(
              approvalValue: approvalMinutes.value,
              approvalUnit: approvalMinutes.unit,
              paymentValue: paymentMinutes.value,
              paymentUnit: paymentMinutes.unit,
            ),
          );
      if (deadlines == null || !mounted) return;
      await _saveBookingDeadlines(
        token,
        deadlines.approvalTimeoutMinutes,
        deadlines.paymentTimeoutMinutes,
      );
    } on Exception catch (error) {
      if (mounted) _showProfileMessage(error.toString());
    }
  }

  Future<void> _saveBookingDeadlines(
    String token,
    int approvalTimeoutMinutes,
    int paymentTimeoutMinutes,
  ) async {
    try {
      await _api.saveMerchantBookingDeadlines(
        token: token,
        approvalTimeoutMinutes: approvalTimeoutMinutes,
        paymentTimeoutMinutes: paymentTimeoutMinutes,
      );
      if (mounted) _showProfileMessage('Booking deadlines saved.');
    } on Exception catch (error) {
      if (mounted) _showProfileMessage(error.toString());
    }
  }

  void _showProfileMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  ({String value, String unit}) _deadlineInputValue(Object? raw) {
    final minutes = int.tryParse('$raw') ?? 15;
    if (minutes >= 60 && minutes % 60 == 0) {
      return (value: '${minutes ~/ 60}', unit: 'hours');
    }
    return (value: '$minutes', unit: 'minutes');
  }

  Widget _profileCard(String name, String email, String phone) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _profileLine),
    ),
    child: Row(
      children: [
        TappableProfileAvatar(
          radius: 34,
          backgroundColor: AppColors.softOrange,
          image: _profileImage,
          fallback: AppText(
            _initials(name),
            style: TextStyle(
              color: _profileInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                name.isEmpty ? 'Merchant account owner' : name,
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              AppText(
                'Merchant account',
                style: TextStyle(color: _profileMuted, fontSize: 12),
                localize: true,
              ),
              if (email.isNotEmpty)
                AppText(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _profileMuted),
                ),
              if (phone.isNotEmpty)
                AppText(
                  phone,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _profileMuted),
                ),
              if (email.isEmpty && phone.isEmpty)
                AppText(
                  'Add contact details to complete your account information.',
                  style: TextStyle(color: _profileMuted, fontSize: 12),
                  localize: true,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('merchant-profile-edit-account'),
                  onPressed: () => unawaited(
                    _handleSetting(_MerchantProfileSetting.editProfile),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const AppText('Edit account details', localize: true),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _performanceCard() => MerchantProfilePerformanceCard(
    performance: _performance,
    period: _performancePeriod,
    venueCount: _businesses.length,
    onPeriodChanged: (period) => setState(() => _performancePeriod = period),
    onEstimatedPaidTap: () => _navigateToManagement(3),
  );

  Widget _quickToolsCard() => _sectionCard(
    title: 'Manage your business',
    children: [
      _quickTool(
        icon: Icons.calendar_month_rounded,
        title: 'Bookings & payments',
        subtitle: 'Review requests, arrivals, and customer payments',
        color: const Color(0xFF1C69C9),
        onTap: () => _navigateToManagement(3),
      ),
      _quickTool(
        icon: Icons.storefront_outlined,
        title: 'Venues & listings',
        subtitle: 'Update venue details and published cards',
        color: const Color(0xFFE28A16),
        onTap: () => _navigateToManagement(1),
      ),
      _quickTool(
        icon: Icons.query_stats_rounded,
        title: 'Business analytics',
        subtitle: 'Compare bookings, revenue, and venue performance',
        color: const Color(0xFF7655C5),
        onTap: () => _navigateToManagement(0),
      ),
    ],
  );

  Widget _businessOverviewCard() {
    final businessName = '${_owner['businessName'] ?? ''}'.trim();
    final publishedNewsCardCount = _businesses
        .where(_hasPublishedNewsCard)
        .length;
    final reviewCounts = _businesses.map(_businessReviewCount).toList();
    final reviewCount = reviewCounts.fold<int>(
      0,
      (total, count) => total + count,
    );
    var weightedRatingTotal = 0.0;
    var ratingDataIsComplete = true;
    for (var index = 0; index < _businesses.length; index++) {
      final count = reviewCounts[index];
      if (count == 0) continue;
      final rating = _businessAverageRating(_businesses[index]);
      if (rating == null) {
        ratingDataIsComplete = false;
        continue;
      }
      weightedRatingTotal += rating * count;
    }
    final averageRating = reviewCount == 0 || !ratingDataIsComplete
        ? null
        : weightedRatingTotal / reviewCount;
    final recentBookings = [..._bookings]
      ..sort((first, second) {
        final firstDate = DateTime.tryParse(
          '${first['createdAt'] ?? first['date'] ?? ''}',
        );
        final secondDate = DateTime.tryParse(
          '${second['createdAt'] ?? second['date'] ?? ''}',
        );
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      });

    return _sectionCard(
      title: 'Your business at a glance',
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                businessName.isEmpty ? 'Add your business name' : businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (averageRating != null) ...[
              AppRatingStars(rating: averageRating, size: 14, spacing: 1),
              AppText(
                averageRating.toStringAsFixed(1),
                style: TextStyle(
                  color: _profileInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 3),
              AppText(
                '($reviewCount)',
                style: TextStyle(color: _profileMuted, fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              _businesses.isEmpty
                  ? Icons.info_outline_rounded
                  : Icons.campaign_outlined,
              size: 16,
              color: _businesses.isEmpty ? _profileMuted : _profileAccent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                _businesses.isEmpty
                    ? 'Add a venue to start accepting customer bookings.'
                    : '$publishedNewsCardCount of ${_businesses.length} venues have a published News Card',
                style: TextStyle(color: _profileMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        if (_businesses.isNotEmpty &&
            publishedNewsCardCount < _businesses.length) ...[
          const SizedBox(height: 3),
          AppText(
            'A published News Card helps eligible listings appear to customers.',
            style: TextStyle(color: _profileMuted, fontSize: 11),
            localize: true,
          ),
        ],
        if (reviewCount > 0) ...[
          const SizedBox(height: 3),
          AppText(
            '$reviewCount customer review${reviewCount == 1 ? '' : 's'} across your venues',
            style: TextStyle(color: _profileMuted, fontSize: 11),
            localize: true,
          ),
        ],
        const SizedBox(height: 3),
        TextButton.icon(
          key: const ValueKey('merchant-profile-manage-venues'),
          onPressed: () => _navigateToManagement(1),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const AppText('Manage venues and listings', localize: true),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        if (recentBookings.isNotEmpty) ...[
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('merchant-profile-recent-activity'),
            onTap: () => _navigateToManagement(3),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF7655C5),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: AppText(
                      'Latest booking · ${recentBookings.first['customerName'] ?? 'Customer'} · ${recentBookings.first['status'] ?? 'updated'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _profileMuted, fontSize: 12),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _profileMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _profileLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: TextStyle(
            color: _profileInk,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  Widget _quickTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: AppText(
        title,
        style: TextStyle(color: _profileInk, fontWeight: FontWeight.w800),
      ),
      subtitle: AppText(
        subtitle,
        style: TextStyle(color: _profileMuted, fontSize: 11),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: _profileMuted),
      onTap: onTap,
    ),
  );

  bool _hasPublishedNewsCard(Map<String, dynamic> business) {
    final value =
        business['hasPublishedNewsCard'] ?? business['has_published_news_card'];
    return value == true ||
        value == 1 ||
        value == '1' ||
        value == 'true' ||
        value == 'TRUE';
  }

  int _integer(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _businessReviewCount(Map<String, dynamic> business) {
    final count = _integer(business['reviewCount']);
    return count > 0 ? count : 0;
  }

  double? _businessAverageRating(Map<String, dynamic> business) {
    final rawRating = business['averageRating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse('$rawRating');
    if (rating == null || !rating.isFinite || rating < 0 || rating > 5) {
      return null;
    }
    return rating;
  }

  void _navigateToManagement(int index) {
    widget.onNavigate?.call(index);
    Navigator.of(context).pop();
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
