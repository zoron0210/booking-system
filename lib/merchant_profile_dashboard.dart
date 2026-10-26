import 'dart:async';

import 'package:flutter/material.dart';

import 'features/activity_log/presentation/activity_log_routes.dart';
import 'features/merchant_management/domain/merchant_profile_performance.dart';
import 'features/merchant_management/data/merchant_session_provider.dart';
import 'features/merchant_management/presentation/merchant_profile_dialogs.dart';
import 'features/merchant_management/presentation/merchant_profile_performance_card.dart';
import 'app_bottom_navigation.dart';
import 'auth_api.dart';
import 'app_design_system.dart';
import 'app_preferences.dart';
import 'app_settings_page.dart';
import 'booking_notifications.dart';
import 'booking_push_notifications.dart';
import 'booking_transaction_notification_settings.dart';
import 'notification_settings_page.dart';
import 'news_feed.dart';
import 'profile_image_preview.dart';
import 'rating_widgets.dart';
import 'features/merchant_management/data/merchant_booking_repository.dart';

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
  helpCenter,
  termsOfService,
  switchToCustomerPortal,
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
    this.openBookingDeadlinesOnStart = false,
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
  final bool openBookingDeadlinesOnStart;
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

  Future<void> _switchToCustomerPortal() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await _api.switchMerchantPortalMode(
        token: token,
        mode: 'customer',
      );
      final customerToken = response['token'] as String?;
      if (customerToken == null || customerToken.isEmpty) {
        throw const AuthApiException(
          'The customer portal could not be opened.',
          500,
        );
      }
      await session.setApiToken(customerToken);
      await session.setRole('customer');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => NewsFeedPage(api: _api, onLogout: widget.onLogout),
        ),
        (_) => false,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: AppText(
              'You’re now browsing as a customer.',
              localize: true,
            ),
          ),
        );
    } on Exception catch (error) {
      if (mounted) {
        _showProfileMessage('Could not switch to customer portal: $error');
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
    final owner = _owner;
    final name = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
        .trim();
    final email = owner['email'] as String? ?? 'Account email';
    final phone = owner['phone'] as String? ?? 'Phone not provided';

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        leadingWidth: 56,
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
        actions: [
          IconButton(
            key: const ValueKey('merchant-profile-settings'),
            tooltip: appLanguageText('Settings', 'Settings'),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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
            _performanceCard(),
            const SizedBox(height: 6),
            _quickToolsCard(),
            const SizedBox(height: 6),
            _businessOverviewCard(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        merchantMode: true,
        selectedIndex: 4,
        onDestinationReselected: _refreshAndScrollToTop,
        onDestinationSelected: (index) {
          if (index == 4) return;
          widget.onNavigate?.call(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _openSettings() async {
    final setting = await showGeneralDialog<_MerchantProfileSetting>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(dialogContext).colorScheme.surface,
          elevation: 12,
          child: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width * .82,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: Color(0xFFFF8200),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            appLanguageText('Settings', 'Mga Setting'),
                            style: Theme.of(dialogContext).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: appLanguageText(
                            'Close settings',
                            'Close settings',
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Divider(height: 1, color: _profileLine),
                        const SizedBox(height: 6),
                        if (BookingNotifications.instance.isSupported ||
                            BookingPushNotifications.instance.isSupported)
                          ListTile(
                            key: const ValueKey(
                              'merchant-settings-notifications',
                            ),
                            leading: const Icon(
                              Icons.notifications_active_outlined,
                            ),
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
                            onTap: () =>
                                _openInAppNotificationSettings(dialogContext),
                          ),
                        ListTile(
                          key: const ValueKey(
                            'merchant-settings-switch-to-customer',
                          ),
                          leading: const Icon(Icons.switch_account_outlined),
                          title: const AppText(
                            'Switch to customer portal',
                            localize: true,
                          ),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.switchToCustomerPortal,
                          ),
                        ),
                        ListTile(
                          key: const ValueKey('merchant-settings-appearance'),
                          leading: const Icon(Icons.palette_outlined),
                          title: AppText(
                            appLanguageText(
                              'Appearance & language',
                              'Hitsura at wika',
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.appPreferences,
                          ),
                        ),
                        ListTile(
                          key: const ValueKey('merchant-settings-edit-profile'),
                          leading: const Icon(Icons.edit_outlined),
                          title: AppText(
                            appLanguageText(
                              'Edit profile',
                              'I-edit ang profile',
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.editProfile,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppText(
                              appLanguageText(
                                'VENUE TOOLS',
                                'MGA TOOL SA VENUE',
                              ),
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
                          key: const ValueKey(
                            'merchant-settings-venue-check-in',
                          ),
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
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.venueCheckIn,
                          ),
                        ),
                        ListTile(
                          key: const ValueKey(
                            'merchant-settings-booking-deadlines',
                          ),
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
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.bookingDeadlines,
                          ),
                        ),
                        ListTile(
                          key: const ValueKey('merchant-settings-activity-log'),
                          leading: const Icon(Icons.history_rounded),
                          title: AppText(
                            appLanguageText(
                              'Activity log',
                              'Tala ng aktibidad',
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.activityLog,
                          ),
                        ),
                        ListTile(
                          key: const ValueKey('merchant-settings-logout'),
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                          ),
                          title: AppText(
                            appLanguageText('Log out', 'Mag-log out'),
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            _MerchantProfileSetting.logOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _profileLine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        appLanguageText('SUPPORT', 'TULONG'),
                        style: TextStyle(
                          color: _profileMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: MerchantSupportSettingTile(
                            key: const ValueKey(
                              'merchant-settings-help-center',
                            ),
                            icon: Icons.help_outline_rounded,
                            title: appLanguageText(
                              'Help Center',
                              'Sentro ng Tulong',
                            ),
                            onTap: () => Navigator.pop(
                              dialogContext,
                              _MerchantProfileSetting.helpCenter,
                            ),
                          ),
                        ),
                        Expanded(
                          child: MerchantSupportSettingTile(
                            key: const ValueKey(
                              'merchant-settings-terms-of-service',
                            ),
                            icon: Icons.description_outlined,
                            title: appLanguageText(
                              'Terms of Service',
                              'Mga Tuntunin',
                            ),
                            onTap: () => Navigator.pop(
                              dialogContext,
                              _MerchantProfileSetting.termsOfService,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    if (!mounted || setting == null) return;
    await _handleSetting(setting);
  }

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
      case _MerchantProfileSetting.switchToCustomerPortal:
        await _switchToCustomerPortal();
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
              const SizedBox(height: 6),
              AppText(
                email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _profileMuted),
              ),
              AppText(
                phone,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _profileMuted),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: Colors.green),
                  SizedBox(width: 6),
                  AppText(
                    'Verified Host',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    localize: true,
                  ),
                ],
              ),
              if ('${_owner['businessName'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(
                  '${_owner['businessName']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
    title: 'Quick tools',
    children: [
      _quickTool(
        icon: Icons.calendar_month_rounded,
        title: 'Schedule',
        subtitle: 'Review booking requests and schedule',
        color: const Color(0xFF1C69C9),
        onTap: () => _navigateToManagement(3),
      ),
      _quickTool(
        icon: Icons.sell_outlined,
        title: 'Pricing / Promo',
        subtitle: 'Manage venues, pricing, and offers',
        color: const Color(0xFFE28A16),
        onTap: () => _navigateToManagement(1),
      ),
      _quickTool(
        icon: Icons.query_stats_rounded,
        title: 'Stats',
        subtitle: 'Open full performance analytics',
        color: const Color(0xFF7655C5),
        onTap: () => _navigateToManagement(0),
      ),
    ],
  );

  Widget _businessOverviewCard() {
    final businessName = '${_owner['businessName'] ?? ''}'.trim();
    final completionChecks = [
      businessName.isNotEmpty,
      '${_owner['address'] ?? ''}'.trim().isNotEmpty,
      _businesses.any(_businessHasImage),
      _businesses.isNotEmpty,
    ];
    final completed = completionChecks.where((value) => value).length;
    final ratings = _businesses
        .map((business) => _number(business['averageRating']))
        .where((rating) => rating > 0)
        .toList();
    final rating = ratings.isEmpty
        ? null
        : ratings.reduce((first, second) => first + second) / ratings.length;
    final openVenues = _businesses.where((business) {
      final availability = '${business['availability'] ?? ''}'.toLowerCase();
      return availability.contains('open') ||
          availability.contains('available');
    }).length;
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
      title: 'Business overview',
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
            if (rating != null) ...[
              AppRatingStars(rating: rating, size: 14, spacing: 1),
              AppText(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  color: _profileInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              openVenues > 0 ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: openVenues > 0 ? const Color(0xFF168B69) : _profileMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                _businesses.isEmpty
                    ? 'No venues added yet'
                    : '$openVenues of ${_businesses.length} venues marked open or available',
                style: TextStyle(color: _profileMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          'Profile completion · $completed/${completionChecks.length}',
          style: TextStyle(
            color: _profileInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: completed / completionChecks.length,
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: AppColors.surfaceVariant,
          color: const Color(0xFF1C69C9),
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

  bool _businessHasImage(Map<String, dynamic> business) {
    final image = '${business['imageUrl'] ?? business['image_url'] ?? ''}'
        .trim();
    final images = business['imageUrls'] ?? business['image_urls'];
    return image.isNotEmpty ||
        (images is List &&
            images.whereType<String>().any((value) => value.trim().isNotEmpty));
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

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
