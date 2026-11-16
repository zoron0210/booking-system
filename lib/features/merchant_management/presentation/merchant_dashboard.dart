import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:myapp/core/app_card_styles.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/booking_approval_deadline.dart';
import 'package:myapp/core/booking_status.dart';
import 'package:myapp/core/live_updates_client.dart';
import 'package:myapp/core/premium_motion.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/data/merchant_booking_repository.dart';
import 'package:myapp/features/merchant_management/data/merchant_session_provider.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';
import 'package:myapp/features/bookings/presentation/fitness_booking_calendar.dart';
import 'package:myapp/core/input_formatters.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_add_page.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_payout_card.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_profile_dashboard.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_profile_dialogs.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_navigation_drawer.dart';
import 'package:myapp/features/social/presentation/public_user_profile.dart';
import 'package:myapp/core/scroll_aware_header.dart';
import 'package:myapp/core/skeleton_loader.dart';

part 'merchant_dashboard_analytics.dart';
part 'merchant_dashboard_analytics_section.dart';
part 'merchant_dashboard_business_cards.dart';
part 'merchant_dashboard_payout_details.dart';
part 'merchant_dashboard_fitness_memberships.dart';
part 'merchant_dashboard_payment_management.dart';
part 'merchant_dashboard_booking_management.dart';
part 'merchant_dashboard_matchmaking.dart';

const _merchantNavy = AppColors.navy;
final _managementTabsStyle = _analyticsFilterStyle.copyWith(
  textStyle: const WidgetStatePropertyAll(
    TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  ),
);
Color get _merchantInk => AppColors.ink;
Color get _merchantOrange => AppColors.accent;
Color get _merchantPage => AppColors.page;
Color get _merchantMuted => AppColors.muted;
Color get _merchantLine => AppColors.border;

class _MerchantDashboardLoadingSkeleton extends StatelessWidget {
  const _MerchantDashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('merchant-dashboard-loading-skeleton'),
    padding: const EdgeInsets.all(16),
    children: [
      const Row(
        children: [
          SkeletonBlock(width: 54, height: 54, borderRadius: 27),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 170, height: 18),
                SizedBox(height: 6),
                SkeletonBlock(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Row(
        children: [
          Expanded(child: SkeletonBlock(height: 92, borderRadius: 16)),
          SizedBox(width: 6),
          Expanded(child: SkeletonBlock(height: 92, borderRadius: 16)),
        ],
      ),
      const SizedBox(height: 6),
      const SkeletonBlock(height: 230, borderRadius: 18),
      const SizedBox(height: 6),
      const SkeletonBlock(height: 170, borderRadius: 18),
    ],
  );
}

class MerchantDashboardPage extends StatefulWidget {
  const MerchantDashboardPage({
    super.key,
    this.onLogout,
    this.api,
    this.sessionProvider,
    this.liveUpdatesClientFactory,
    this.onSwitchToCustomerPortal,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final MerchantSessionProvider? sessionProvider;
  final LiveUpdatesClient Function()? liveUpdatesClientFactory;
  final Future<void> Function(BuildContext context)? onSwitchToCustomerPortal;

  @override
  State<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends State<MerchantDashboardPage> {
  late final AuthApi _api;
  late final MerchantSessionProvider _sessionProvider;
  late final MerchantBookingRepository _merchantBookingRepository;
  late final LiveUpdatesClient Function() _liveUpdatesClientFactory;
  final _formKey = GlobalKey<FormState>();
  final _merchantAddPageKey = GlobalKey<MerchantAddPageState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _businessName = TextEditingController();
  final _businessType = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _address = TextEditingController();
  final _contactEmail = TextEditingController();
  final _designation = TextEditingController();
  final _venueSearchController = TextEditingController();
  final _payoutSearchController = TextEditingController();
  final _selectedCategories = <String>{};
  final _imagePicker = ImagePicker();
  String _facilityType = 'Indoor';
  String? _businessTypeValue;
  String? _selectedBookingType;
  String _venueSearchQuery = '';
  final _customCategories = <String>{};
  Map<String, dynamic> _owner = const {};
  String? _profileImage;
  String? _businessImage;
  bool _loading = true;
  bool _profileLoaded = false;
  String? _profileLoadError;
  bool _saving = false;
  List<Map<String, dynamic>> _businesses = [];
  bool _businessesLoading = true;
  bool _businessesLoaded = false;
  String? _businessesLoadError;
  List<Map<String, dynamic>> _bookings = [];
  bool _bookingsLoading = true;
  bool _bookingsLoaded = false;
  String? _bookingsLoadError;
  List<Map<String, dynamic>> _matchmakingRequests = [];
  bool _matchmakingLoading = true;
  bool _matchmakingLoaded = false;
  String? _matchmakingLoadError;
  final Set<int> _decidingMatchmakingRequests = <int>{};
  int _merchantTab = 0;
  int _payoutTab = 0;
  int _bookingManagementTab = 0;
  int _customerArrivalTab = 0;
  int _fitnessMembershipFilter = 0;
  int _paymentManagementTab = 0;
  String _payoutBookingType = 'All';
  String _payoutSearchQuery = '';
  double _managementSwipeDistance = 0;
  final _homeRefreshKey = GlobalKey<RefreshIndicatorState>();
  final _managementRefreshKey = GlobalKey<RefreshIndicatorState>();
  final _merchantRefreshGate = PremiumRefreshGate();
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _managementScrollController = ScrollController();
  Timer? _payoutRefreshTimer;
  LiveUpdatesClient? _payoutLiveUpdatesClient;
  StreamSubscription<Map<String, dynamic>>? _payoutLiveUpdatesSubscription;
  Future<void>? _profileRequest;
  Future<void>? _businessesRequest;
  Future<void>? _bookingsRequest;
  Future<void>? _matchmakingRequest;

  String _analyticsPeriod = 'Daily';
  String _analyticsView = 'Sales report';
  String _analyticsBookingType = 'All';
  String _venueComparisonMetric = 'Bookings';
  DateTimeRange? _analyticsDateRange;

  void _setAnalyticsState(VoidCallback callback) => setState(callback);

  List<Map<String, dynamic>> get _visibleBusinesses {
    return _businesses.where((business) {
      final enabled = business['enabled'];
      final isEnabled =
          enabled != false &&
          enabled != 0 &&
          enabled != '0' &&
          enabled != 'false' &&
          enabled != 'FALSE';
      return isEnabled &&
          (_selectedBookingType == null ||
              business['businessType'] == _selectedBookingType);
    }).toList();
  }

  List<Map<String, dynamic>> get _liveBusinesses =>
      _visibleBusinesses.where(_isLiveOnApp).toList();

  bool _isLiveOnApp(Map<String, dynamic> business) {
    final value = business['hasPublishedNewsCard'];
    return value == true ||
        value == 1 ||
        value == '1' ||
        value == 'true' ||
        value == 'TRUE';
  }

  static const _categoriesByBusinessType = {
    'Sports': ['Tennis', 'Pickleball', 'Basketball', 'Volleyball', 'Badminton'],
    'Event': ['Ballroom', 'Terrace', 'Private Dining', 'Garden'],
    'Fitness & Wellness': [
      'CrossFit',
      'Pilates',
      'Boxing',
      'Yoga',
      'Zumba',
      'Martial Arts',
    ],
  };

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _sessionProvider = widget.sessionProvider ?? AppMerchantSessionProvider();
    _merchantBookingRepository = AuthApiMerchantBookingRepository(api: _api);
    _liveUpdatesClientFactory =
        widget.liveUpdatesClientFactory ?? LiveUpdatesClient.new;
    _loadProfile();
  }

  @override
  void dispose() {
    _stopPayoutLiveUpdates();
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _businessName,
      _businessType,
      _registrationNumber,
      _address,
      _contactEmail,
      _designation,
      _venueSearchController,
      _payoutSearchController,
    ]) {
      controller.dispose();
    }
    _managementScrollController.dispose();
    _merchantAnalyticsUiStateFor(this).scrollController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() {
    final activeRequest = _profileRequest;
    if (activeRequest != null) return activeRequest;

    late final Future<void> request;
    request = _fetchProfile().whenComplete(() {
      if (identical(_profileRequest, request)) _profileRequest = null;
    });
    _profileRequest = request;
    return request;
  }

  Future<void> _fetchProfile() async {
    if (mounted) {
      setState(() {
        _profileLoadError = null;
        if (!_profileLoaded) _loading = true;
      });
    }
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await _api.merchantProfile(token);
      final rawProfile = response['profile'];
      if (rawProfile is! Map<String, dynamic>) {
        throw const FormatException(
          'The server returned an invalid merchant profile.',
        );
      }
      final profile = rawProfile;
      if (!mounted) return;
      setState(() {
        _owner = profile;
        _profileLoaded = true;
        _loading = false;
        _profileImage = profile['avatarUrl'] as String?;
        _businessImage = profile['businessImage'] as String?;
        _firstName.text = profile['firstName'] as String? ?? '';
        _lastName.text = profile['lastName'] as String? ?? '';
        _phone.text = profile['phone'] as String? ?? '';
        _businessName.text = profile['businessName'] as String? ?? '';
        _businessTypeValue = profile['businessType'] as String?;
        _businessType.text = _businessTypeValue ?? '';
        _registrationNumber.text =
            profile['registrationNumber'] as String? ?? '';
        _address.text = profile['address'] as String? ?? '';
        _contactEmail.text = profile['contactEmail'] as String? ?? '';
        _designation.text = profile['ownerDesignation'] as String? ?? '';
        _facilityType = profile['facilityType'] as String? ?? 'Indoor';
        _selectedCategories
          ..clear()
          ..addAll(
            (profile['categories'] as List<dynamic>? ?? []).whereType<String>(),
          );
        _customCategories
          ..clear()
          ..addAll(
            _selectedCategories.where(
              (category) =>
                  !(_categoriesByBusinessType[_businessTypeValue] ?? const [])
                      .contains(category),
            ),
          );
      });
      await Future.wait([
        _loadBusinesses(),
        _loadBookings(),
        _loadMatchmakingRequests(),
      ]);
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _profileLoadError = _merchantLoadFailureMessage(
            'merchant profile',
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _merchantLoadFailureMessage(String section, Object error) {
    if (error is AuthApiException) {
      if (error.statusCode == 401) {
        return 'Your merchant session may have expired. Sign in again, then retry.';
      }
      if (error.statusCode == 0 ||
          error.statusCode == 408 ||
          error.statusCode >= 500) {
        return error.userMessage;
      }
    }
    return 'We couldn’t load $section. Please try again.';
  }

  Widget _merchantSectionLoadStatus({
    required String key,
    required String title,
    required bool loading,
    required bool loaded,
    required String? error,
    required Future<void> Function() onRetry,
  }) {
    if (!loading && error == null) return const SizedBox.shrink();

    final showingPreviousData = loaded && error != null;
    final message = loading
        ? loaded
              ? 'Updating $title…'
              : 'Loading $title…'
        : showingPreviousData
        ? 'Could not refresh $title. Showing the last successfully loaded data. $error'
        : 'Could not load $title. $error';
    return Card(
      key: ValueKey('$key-load-status'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.cloud_off_outlined, color: _merchantOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    message,
                    style: TextStyle(color: _merchantInk, height: 1.35),
                  ),
                  if (!loading) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: ValueKey('$key-retry'),
                      onPressed: () => unawaited(onRetry()),
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const AppText('Retry', localize: true),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? true)) {
      final formContext = _formKey.currentContext;
      if (formContext != null) {
        BuildContext? firstInvalidContext;
        void visit(Element element) {
          if (firstInvalidContext != null) return;
          if (element is StatefulElement) {
            final state = element.state;
            if (state is FormFieldState<dynamic> && state.errorText != null) {
              firstInvalidContext = state.context;
              return;
            }
          }
          element.visitChildElements(visit);
        }

        (formContext as Element).visitChildElements(visit);
        final target = firstInvalidContext;
        if (target != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (target.mounted) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 250),
                alignment: .15,
              );
            }
          });
        }
      }
      return false;
    }
    setState(() => _saving = true);
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      await _api.saveMerchantProfile(
        token: token,
        profile: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'phone': _phone.text.trim(),
          'businessName': _businessName.text.trim(),
          'businessType': _businessType.text.trim(),
          'registrationNumber': _registrationNumber.text.trim(),
          'categories': _selectedCategories.toList(),
          'facilityType': _facilityType,
          'address': _address.text.trim(),
          'contactEmail': _contactEmail.text.trim(),
          'ownerDesignation': _designation.text.trim(),
          'profileImage': _profileImage,
          'businessImage': _businessImage,
        },
      );
      final accountEmail =
          (_owner['email'] as String?) ?? session.accountEmail ?? '';
      if (accountEmail.isNotEmpty) {
        await session.markMerchantProfileCompleted(accountEmail);
      }
      await _loadBusinesses(force: true);
      _showMessage('Merchant profile saved and ready for customer listings.');
      return true;
    } on Exception catch (error) {
      _showMessage('Could not save merchant profile: $error');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  Widget _merchantSectionNotice({
    required String key,
    required String title,
    required String message,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: appLanguageText('About $title', 'About $title'),
    visualDensity: VisualDensity.compact,
    padding: AppSpacing.buttonPadding,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    icon: const Icon(Icons.info_outline_rounded, size: 19),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(title),
        content: AppText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const AppText('Got it', localize: true),
          ),
        ],
      ),
    ),
  );

  Future<Map<String, dynamic>?> _openMerchantEditPanel() async {
    var panelProfileImage = _profileImage;
    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close merchant profile editor',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (panelContext, animation, secondaryAnimation) =>
          StatefulBuilder(
            builder: (panelContext, setPanelState) => Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: AppColors.surface,
                child: SizedBox(
                  width: MediaQuery.sizeOf(panelContext).width * .88,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: _merchantOrange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: AppText(
                                  'Edit merchant profile',
                                  style: TextStyle(
                                    color: _merchantInk,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  localize: true,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.pop(panelContext, false),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Column(
                            children: [
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final selected = await _pickProfileImage();
                                  if (selected == null) return;
                                  panelProfileImage = selected;
                                  if (mounted) setPanelState(() {});
                                },
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor: AppColors.softOrange,
                                  backgroundImage: _imageProvider(
                                    panelProfileImage,
                                  ),
                                  child: panelProfileImage == null
                                      ? Icon(
                                          Icons.add_a_photo_outlined,
                                          color: _merchantOrange,
                                          size: 25,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppText(
                                'Tap to upload avatar',
                                style: TextStyle(
                                  color: _merchantMuted,
                                  fontSize: 11,
                                ),
                                localize: true,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Form(
                                  key: _formKey,
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      6,
                                      20,
                                      20,
                                    ),
                                    children: [
                                      _field(
                                        _firstName,
                                        'First name',
                                        'First name',
                                      ),
                                      const SizedBox(height: 6),
                                      _field(
                                        _lastName,
                                        'Last name',
                                        'Last name',
                                      ),
                                      const SizedBox(height: 6),
                                      _field(
                                        _phone,
                                        'Direct contact phone',
                                        '09XX XXX XXXX',
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: const [
                                          PhilippineMobilePhoneFormatter(),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      _field(
                                        _address,
                                        'Address',
                                        'Address',
                                        required: false,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 6),
                                      _field(
                                        _contactEmail,
                                        'Official business email',
                                        'Business email',
                                        required: false,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  18,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(panelContext, false),
                                        child: const AppText(
                                          'Cancel',
                                          localize: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _saving
                                            ? null
                                            : () async {
                                                final didSave =
                                                    await _saveProfile();
                                                if (didSave &&
                                                    panelContext.mounted) {
                                                  Navigator.pop(
                                                    panelContext,
                                                    true,
                                                  );
                                                }
                                              },
                                        child: const AppText(
                                          'Save changes',
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
    if (saved == true && mounted) {
      await _loadProfile();
      return {'owner': _owner, 'profileImage': _profileImage};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _merchantPage,
      appBar: _MerchantDashboardHeader(state: this),
      drawer: MerchantNavigationDrawer(
        owner: _owner,
        profileImage: _imageProvider(_profileImage),
        selectedIndex: _merchantTab,
        pendingBookingCount: _bookingsLoaded
            ? _bookings.where(_isPendingBooking).length
            : -1,
        onDestinationSelected: _selectMerchantDestination,
        onSettingsSelected: _openMerchantSettings,
        onLogout: widget.onLogout,
        onHelpCenterSelected: _openMerchantHelpCenter,
        onTermsOfServiceSelected: _openMerchantTermsOfService,
      ),
      body: _loading
          ? const _MerchantDashboardLoadingSkeleton()
          : !_profileLoaded
          ? _merchantSectionLoadStatus(
              key: 'merchant-profile',
              title: 'merchant profile',
              loading: false,
              loaded: false,
              error: _profileLoadError,
              onRetry: _loadProfile,
            )
          : _profileLoadError != null
          ? Column(
              children: [
                _merchantSectionLoadStatus(
                  key: 'merchant-profile',
                  title: 'merchant profile',
                  loading: false,
                  loaded: true,
                  error: _profileLoadError,
                  onRetry: _loadProfile,
                ),
                Expanded(child: _MerchantDashboardContent(state: this)),
              ],
            )
          : _MerchantDashboardContent(state: this),
    );
  }

  Widget _merchantPayouts() => ScrollAwareHeader(
    header: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _managementFilters(),
    ),
    body: RefreshIndicator(
      key: _managementRefreshKey,
      onRefresh: _refreshMerchantBookings,
      displacement: 52,
      edgeOffset: 8,
      strokeWidth: 2.5,
      child: ListView(
        key: const ValueKey('merchant-management-list'),
        controller: _managementScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
        children: [
          SegmentedButton<int>(
            key: const ValueKey('merchant-management-tabs'),
            style: _managementTabsStyle,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                label: AppText('Booking', localize: true),
              ),
              ButtonSegment(
                value: 1,
                label: AppText('Customer', localize: true),
              ),
              ButtonSegment(
                value: 2,
                label: AppText('Payment', localize: true),
              ),
            ],
            selected: {_payoutTab},
            onSelectionChanged: (selection) {
              setState(() => _payoutTab = selection.first);
            },
          ),
          const SizedBox(height: 8),
          _managementWorkflowHeading(),
          const SizedBox(height: 6),
          if (_bookingsLoaded && _hasPayoutFilters)
            Row(
              children: [
                Expanded(
                  child: AppText(
                    '${_filteredPayoutBookings.length} bookings match your filters',
                    key: const ValueKey('merchant-management-result-count'),
                    style: TextStyle(color: _merchantMuted, fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('merchant-management-clear-filters'),
                  onPressed: _clearPayoutFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: const AppText('Clear filters', localize: true),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          if (_bookingsLoaded && _hasPayoutFilters) const SizedBox(height: 8),
          GestureDetector(
            key: const ValueKey('merchant-management-swipe-content'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _managementSwipeDistance = 0,
            onHorizontalDragUpdate: (details) {
              _managementSwipeDistance += details.delta.dx;
            },
            onHorizontalDragEnd: (_) {
              if (_managementSwipeDistance.abs() >= 48) {
                final direction = _managementSwipeDistance < 0 ? 1 : -1;
                final nextTab = _payoutTab + direction;
                if (nextTab >= 0 && nextTab <= 2) {
                  setState(() => _payoutTab = nextTab);
                }
              }
              _managementSwipeDistance = 0;
            },
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _merchantSectionLoadStatus(
                    key: 'merchant-bookings',
                    title: 'bookings and payment data',
                    loading: _bookingsLoading,
                    loaded: _bookingsLoaded,
                    error: _bookingsLoadError,
                    onRetry: _loadBookings,
                  ),
                  if (_bookingsLoaded)
                    _payoutTab == 1
                        ? _payoutBookingType == 'Fitness & Wellness'
                              ? _fitnessMembershipManagementContent()
                              : _customerManagementContent()
                        : _payoutTab == 2
                        ? _paymentManagementContent()
                        : _bookingManagementContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bookingManagementContent() =>
      _MerchantDashboardBookingManagement(this).bookingManagementContent();

  Widget _customerManagementContent() =>
      _MerchantDashboardBookingManagement(this).customerManagementContent();

  Widget _managementFilters() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 1, child: _payoutTypeFilter()),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: _payoutSearchBar()),
    ],
  );

  Widget _customerProfileIdentity(
    Map<String, dynamic> booking, {
    required double fontSize,
  }) {
    final customerId = (booking['customerId'] as num?)?.toInt();
    final avatarUrl = '${booking['customerAvatarUrl'] ?? ''}'.trim();
    final avatar = _imageProvider(avatarUrl);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: ValueKey('merchant-booking-customer-avatar-$customerId'),
          customBorder: const CircleBorder(),
          onTap: !socialProfileUiEnabled || customerId == null
              ? null
              : () => _openCustomerProfile(customerId),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.softOrange,
            backgroundImage: avatar,
            child: avatar == null
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AppText(
            '${booking['customerName'] ?? 'Customer'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _merchantInk,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
            localize: true,
          ),
        ),
      ],
    );
  }

  Future<void> _openCustomerProfile(int customerId) async {
    final session = await _sessionProvider.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty || !mounted) return;
    await openPublicUserProfile(
      context: context,
      api: _api,
      token: token,
      userId: customerId,
      onFollowChanged: _loadBookings,
    );
  }

  Widget _payoutManagementInfoRow(String label, dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: AppText(
              label,
              style: TextStyle(color: _merchantMuted, fontSize: 12),
              localize: true,
            ),
          ),
          Expanded(
            child: AppText(
              text,
              style: TextStyle(
                color: _merchantInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              localize: true,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredPayoutBookings {
    return _bookings.where((booking) {
      final matchesType =
          _payoutBookingType == 'All' ||
          booking['businessType'] == _payoutBookingType;
      if (!matchesType || _payoutSearchQuery.isEmpty) return matchesType;
      final searchable = [
        booking['customerName'],
        booking['customerId'],
        booking['customerEmail'],
        booking['venueName'],
        booking['businessName'],
        booking['businessType'],
        booking['date'],
        booking['status'],
        booking['paymentMethod'],
        booking['paymentStatus'],
        booking['id'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(_payoutSearchQuery);
    }).toList();
  }

  Widget _payoutSearchBar() => TextField(
    key: const ValueKey('merchant-payout-search'),
    controller: _payoutSearchController,
    onChanged: (value) =>
        setState(() => _payoutSearchQuery = value.trim().toLowerCase()),
    textInputAction: TextInputAction.search,
    style: TextStyle(color: _merchantInk, fontSize: 12),
    decoration: InputDecoration(
      hintText: appLanguageText('Search bookings', 'Search bookings'),
      hintStyle: TextStyle(color: _merchantMuted, fontSize: 11),
      prefixIcon: const Icon(Icons.search_rounded, size: 16),
      prefixIconConstraints: const BoxConstraints(minWidth: 30),
      suffixIcon: _payoutSearchQuery.isEmpty
          ? null
          : IconButton(
              key: const ValueKey('merchant-payout-search-clear'),
              tooltip: appLanguageText('Clear search', 'Clear search'),
              onPressed: () {
                _payoutSearchController.clear();
                setState(() => _payoutSearchQuery = '');
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantOrange, width: 1.5),
      ),
    ),
  );

  Widget _payoutTypeFilter() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('merchant-payout-type-filter'),
      initialValue: _payoutBookingType,
      isExpanded: true,
      icon: const SizedBox.shrink(),
      menuMaxHeight: (MediaQuery.sizeOf(context).height * .3)
          .clamp(180.0, 220.0)
          .toDouble(),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      style: TextStyle(
        color: _merchantInk,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      iconSize: 16,
      decoration: InputDecoration(
        hintText: appLanguageText('All', 'All'),
        prefixIcon: Icon(Icons.filter_list_rounded, size: 16),
        prefixIconConstraints: BoxConstraints(minWidth: 30),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        constraints: BoxConstraints(minHeight: 40, maxHeight: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantOrange, width: 1.5),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: AppText('All', maxLines: 1, localize: true),
        ),
        DropdownMenuItem(
          value: 'Sports',
          child: AppText('Sports', maxLines: 1, localize: true),
        ),
        DropdownMenuItem(
          value: 'Event',
          child: AppText('Event', maxLines: 1, localize: true),
        ),
        DropdownMenuItem(
          value: 'Fitness & Wellness',
          child: AppText('Fitness', maxLines: 1, localize: true),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _payoutBookingType = value);
        }
      },
    );
  }

  Widget _emptyManagementState({
    required IconData icon,
    required String emptyTitle,
    required String emptyMessage,
    required String filteredTitle,
    required String filteredMessage,
  }) {
    final filtered = _hasPayoutFilters;
    return _emptyPayoutCard(
      icon,
      filtered ? filteredTitle : emptyTitle,
      filtered ? filteredMessage : emptyMessage,
      onClearFilters: filtered ? _clearPayoutFilters : null,
    );
  }

  Widget _emptyPayoutCard(
    IconData icon,
    String title,
    String message, {
    VoidCallback? onClearFilters,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.softOrange,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: _merchantOrange, size: 32),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: TextStyle(
                      color: _merchantInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppText(message, style: TextStyle(color: _merchantInk)),
                  if (onClearFilters != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey(
                          'merchant-management-empty-clear-filters',
                        ),
                        onPressed: onClearFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 16,
                        ),
                        label: const AppText('Clear filters', localize: true),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPendingBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isPending(booking['status']) ||
      (booking['bookingType'] == 'matchmaking' &&
          booking['status'] == 'matchmaking_pending_merchant');

  bool _isFinishedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.parse(booking['status']) == BookingStatus.finished ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.completed ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.done;

  bool _isApprovedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isApproved(booking['status']) ||
      (booking['bookingType'] == 'matchmaking' &&
          booking['status'] == 'matchmaking_open');

  bool _isMerchantDeletableBooking(Map<String, dynamic> booking) =>
      '${booking['status'] ?? ''}'.trim().toLowerCase() == 'finished';

  bool _hasCheckedIn(Map<String, dynamic> booking) {
    final checkedInAt = booking['checkedInAt'];
    return checkedInAt != null && '$checkedInAt'.trim().isNotEmpty;
  }

  bool _isNoShowBooking(Map<String, dynamic> booking) =>
      !_hasCheckedIn(booking) && _isFinishedBooking(booking);

  Future<void> _showPayoutBookingDetails(
    Map<String, dynamic> booking, {
    bool paymentOnly = false,
  }) =>
      _MerchantDashboardPayoutDetails(this)
          .showPayoutBookingDetails(booking, paymentOnly: paymentOnly);

  String _formatPayoutTime(dynamic value) {
    final raw = '${value ?? ''}';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) return raw;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'AM' : 'PM'}';
  }

  String _bookingTimeRangeLabel(Map<String, dynamic> booking) {
    final date = DateTime.tryParse('${booking['date'] ?? ''}');
    final timeParts = '${booking['startTime'] ?? ''}'.split(':');
    final duration = _bookingAmount(booking['durationHours']);
    if (date == null ||
        timeParts.length < 2 ||
        duration <= 0 ||
        int.tryParse(timeParts[0]) == null ||
        int.tryParse(timeParts[1]) == null) {
      return '${booking['date'] ?? ''} ${_formatPayoutTime(booking['startTime'])}';
    }
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
    final end = start.add(Duration(minutes: (duration * 60).round()));
    final startDateLabel =
        '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    final endDateLabel =
        '${end.year.toString().padLeft(4, '0')}-'
        '${end.month.toString().padLeft(2, '0')}-'
        '${end.day.toString().padLeft(2, '0')}';
    final startTimeLabel = _formatPayoutTime(
      '${start.hour.toString().padLeft(2, '0')}:'
      '${start.minute.toString().padLeft(2, '0')}',
    );
    final endTimeLabel = _formatPayoutTime(
      '${end.hour.toString().padLeft(2, '0')}:'
      '${end.minute.toString().padLeft(2, '0')}',
    );
    return startDateLabel == endDateLabel
        ? '$startDateLabel · $startTimeLabel - $endTimeLabel'
        : '$startDateLabel $startTimeLabel - $endDateLabel $endTimeLabel';
  }

  String _bookingDurationHoursLabel(dynamic value) {
    final hours = _bookingAmount(value);
    final number = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : '$hours';
    return '$number ${hours == 1 ? 'hour' : 'hours'}';
  }

  String _fitnessPlanDuration(String planType) => switch (planType) {
    'monthly' => '1 month',
    'yearly' => '1 year',
    'session' => '1 session',
    _ => planType,
  };

  String _payoutPaymentLabel(dynamic value) => switch ('$value') {
    'cash_on_arrival' => 'Cash on arrival',
    'online' => 'Online',
    _ => '${value ?? ''}',
  };

  double _bookingAmount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  double _bookingAmountReceived(Map<String, dynamic> booking) {
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    final paidAmount = booking['paidAmount'];
    if (paidAmount != null) {
      final amount = _bookingAmount(paidAmount);
      if (amount > 0 || paymentStatus != 'paid') return amount;
    }
    if (paymentStatus == 'paid') return _bookingAmount(booking['total']);
    return 0;
  }

  String _bookingServiceLabel(Map<String, dynamic> booking) {
    final plan = '${booking['fitnessPlanType'] ?? ''}';
    final category = '${booking['fitnessCategory'] ?? ''}';
    final coach = '${booking['fitnessCoachName'] ?? ''}';
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    final eventType = '${booking['eventType'] ?? ''}';
    if (isEvent) {
      return eventType.isEmpty ? 'Event booking' : eventType;
    }
    if (plan.isNotEmpty) {
      final planLabel = '${plan[0].toUpperCase()}${plan.substring(1)} plan';
      return '${category.isEmpty ? booking['sportType'] : category} · '
          '$planLabel${coach.isEmpty ? '' : ' · Coach $coach'}';
    }
    final area =
        booking['occupiesFullStudio'] == true ||
            booking['occupiesFullStudio'] == 1
        ? 'Whole studio'
        : _bookingSlotLabel(booking);
    return '${booking['sportType'] ?? 'Sport'} · $area';
  }

  String _bookingSlotLabel(Map<String, dynamic> booking) {
    final slots = booking['slotNumbers'];
    if (slots is List && slots.isNotEmpty) {
      final labels = slots.map((slot) => '$slot').join(', ');
      return slots.length > 1 ? 'Slots $labels' : 'Slot $labels';
    }
    return 'Slot ${booking['slotNumber'] ?? '—'}';
  }

  Widget _merchantHome() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final horizontalPadding = wide ? 28.0 : 20.0;
      final businesses = _visibleBusinesses.where(_venueMatchesSearch).toList();
      return ScrollAwareHeader(
        header: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            0,
          ),
          child: _venueSearchBar(),
        ),
        body: RefreshIndicator(
          key: _homeRefreshKey,
          onRefresh: _refreshMerchantDashboardData,
          displacement: 52,
          edgeOffset: 8,
          strokeWidth: 2.5,
          child: ListView(
            controller: _homeScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.medium,
              horizontalPadding,
              32,
            ),
            children: [
              _merchantSectionLoadStatus(
                key: 'merchant-businesses',
                title: 'businesses',
                loading: _businessesLoading,
                loaded: _businessesLoaded,
                error: _businessesLoadError,
                onRetry: _loadBusinesses,
              ),
              _merchantSectionLoadStatus(
                key: 'merchant-matchmaking',
                title: 'matchmaking requests',
                loading: _matchmakingLoading,
                loaded: _matchmakingLoaded,
                error: _matchmakingLoadError,
                onRetry: _loadMatchmakingRequests,
              ),
              if (_matchmakingLoaded) ...[
                _matchmakingQueueCard(),
                const SizedBox(height: AppSpacing.medium),
              ],
              if (_businessesLoaded) ...[
                _venueSwitcher(),
                const SizedBox(height: AppSpacing.medium),
                if (businesses.isEmpty)
                  _emptyBusinesses()
                else
                  _businessGrid(businesses, wide),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _venueSearchBar() {
    return TextField(
      controller: _venueSearchController,
      onChanged: (value) =>
          setState(() => _venueSearchQuery = value.trim().toLowerCase()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: appLanguageText(
          'Search your venues...',
          'Search your venues...',
        ),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _venueSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: appLanguageText('Clear search', 'Clear search'),
                onPressed: () {
                  _venueSearchController.clear();
                  setState(() => _venueSearchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _merchantLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _merchantLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _merchantOrange, width: 1.5),
        ),
      ),
    );
  }

  bool _venueMatchesSearch(Map<String, dynamic> business) {
    if (_venueSearchQuery.isEmpty) return true;
    final searchable = [
      business['name'],
      business['category'],
      business['businessType'],
      business['address'],
      business['facilityType'],
      business['details'],
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(_venueSearchQuery);
  }

  Widget _businessCard(Map<String, dynamic> business) =>
      _merchantBusinessCard(business);

  Widget _businessGrid(List<Map<String, dynamic>> businesses, bool wide) {
    if (!wide) {
      return Column(
        children: [
          for (final business in businesses) ...[
            _businessCard(business),
            const SizedBox(height: 6),
          ],
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: businesses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: .58,
      ),
      itemBuilder: (context, index) => _businessCard(businesses[index]),
    );
  }

  Widget _emptyBusinesses() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(Icons.storefront_outlined, size: 42, color: _merchantMuted),
        SizedBox(height: 6),
        AppText(
          'No businesses added yet',
          style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w800),
          localize: true,
        ),
        SizedBox(height: 6),
        AppText(
          'Add a venue to publish it for customers.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _merchantMuted),
          localize: true,
        ),
      ],
    ),
  );

  bool get _hasPayoutFilters =>
      _payoutSearchQuery.isNotEmpty || _payoutBookingType != 'All';

  void _clearPayoutFilters() {
    _payoutSearchController.clear();
    setState(() {
      _payoutSearchQuery = '';
      _payoutBookingType = 'All';
    });
  }

  Widget _managementWorkflowHeading() {
    final (title, description) = switch (_payoutTab) {
      0 => (
        'Booking requests & status',
        'Requests are pending; Active includes approved bookings; Completed includes finished, completed, and done bookings.',
      ),
      1 when _payoutBookingType == 'Fitness & Wellness' => (
        'Fitness memberships',
        'View active monthly and annual memberships, or switch to another business type for customer arrivals.',
      ),
      1 => (
        'Customer arrivals',
        'Track customers who are awaiting arrival, checked in, or marked as no-shows.',
      ),
      _ => (
        'Payments, earnings & refunds',
        'Review booking payments, collected earnings, and refund status.',
      ),
    };
    return Padding(
      key: const ValueKey('merchant-management-workflow-heading'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: TextStyle(
              color: _merchantInk,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            localize: true,
          ),
          const SizedBox(height: 2),
          AppText(
            description,
            style: TextStyle(color: _merchantMuted, fontSize: 11, height: 1.3),
            localize: true,
          ),
        ],
      ),
    );
  }

  Future<void> _switchBookingType() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const AppText('Switch booking type', localize: true),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const AppText('All booking types', localize: true),
          ),
          for (final type in const ['Sports', 'Fitness & Wellness', 'Event'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, type),
              child: Row(
                children: [
                  Icon(
                    type == 'Sports'
                        ? Icons.sports_tennis_rounded
                        : type == 'Event'
                        ? Icons.auto_awesome_rounded
                        : Icons.fitness_center_rounded,
                    color: _merchantOrange,
                  ),
                  const SizedBox(width: 6),
                  AppText(type == 'Fitness & Wellness' ? 'Fitness' : type),
                  const Spacer(),
                  if (_selectedBookingType == type)
                    const Icon(Icons.check_rounded, color: Colors.green),
                ],
              ),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedBookingType = selected.isEmpty ? null : selected;
    });
  }

  Widget _venueSwitcher() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: _merchantLine),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          Icons.circle,
          color: _liveBusinesses.isEmpty ? _merchantOrange : Colors.green,
          size: 9,
        ),
        const SizedBox(width: 6),
        AppText(
          '${_liveBusinesses.length} Live ${_liveBusinesses.length == 1 ? 'Venue' : 'Venues'}',
          style: TextStyle(
            color: _merchantInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          localize: true,
        ),
        const SizedBox(width: 6),
        AppText(
          _visibleBusinesses.length == _liveBusinesses.length
              ? '• Live on App'
              : '• Setup needed',
          style: TextStyle(color: _merchantMuted, fontSize: 11.5),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _switchBookingType,
          style: OutlinedButton.styleFrom(
            foregroundColor: _merchantOrange,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: _merchantLine),
            padding: AppSpacing.buttonPadding,
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: AppText(
            _selectedBookingType == 'Fitness & Wellness'
                ? 'Fitness'
                : _selectedBookingType ?? 'Switch Type',
          ),
        ),
      ],
    ),
  );

  String? _businessText(Map<String, dynamic> business, List<String> keys) {
    for (final key in keys) {
      final value = business[key] ?? business[_snakeCase(key)];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  String _snakeCase(String value) =>
      value.replaceAllMapped(RegExp(r'([A-Z])'), (match) {
        return '_${match.group(1)!.toLowerCase()}';
      });

  void _selectMerchantDestination(int index) {
    if (index == 2) {
      _openMerchantMessages();
      return;
    }
    if (index == 4) {
      _openMerchantProfile();
      return;
    }
    if (_merchantTab == index) {
      unawaited(_refreshAndScrollToTop());
      return;
    }
    setState(() => _merchantTab = index);
    if (index == 0) {
      unawaited(_loadMatchmakingRequests());
    }
    if (index == 3) {
      _startPayoutLiveUpdates();
    } else {
      _stopPayoutLiveUpdates();
    }
  }

  void _openMerchantPayouts(int tab) {
    setState(() => _payoutTab = tab);
    _selectMerchantDestination(3);
  }

  Future<void> _refreshMerchantDashboardData() =>
      _merchantRefreshGate.run(() async {
        await Future.wait([
          _loadBusinesses(),
          _loadBookings(),
          _loadMatchmakingRequests(),
        ]);
      });

  Future<void> _refreshMerchantBookings() =>
      _merchantRefreshGate.run(_loadBookings);

  void _startPayoutLiveUpdates() {
    if (_payoutLiveUpdatesClient != null) return;
    final client = _liveUpdatesClientFactory();
    _payoutLiveUpdatesClient = client;
    _payoutLiveUpdatesSubscription = client.events.listen(
      (event) {
        if (event['type'] == 'dashboard.updated' &&
            mounted &&
            _merchantTab == 3) {
          unawaited(_loadBookings());
        }
      },
      onError: (_, _) => _startPayoutPollingFallback(client),
      onDone: () => _startPayoutPollingFallback(client),
    );
    unawaited(_connectPayoutLiveUpdates(client));
  }

  Future<void> _connectPayoutLiveUpdates(LiveUpdatesClient client) async {
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (!mounted || client != _payoutLiveUpdatesClient || _merchantTab != 3) {
        await client.close();
        return;
      }
      if (token == null || token.isEmpty) {
        _stopPayoutLiveUpdates();
        return;
      }
      await client.connect(token);
      if (!mounted || client != _payoutLiveUpdatesClient || _merchantTab != 3) {
        await client.close();
        return;
      }
      _payoutRefreshTimer?.cancel();
      _payoutRefreshTimer = null;
    } on Object {
      _startPayoutPollingFallback(client);
    }
  }

  void _startPayoutPollingFallback(LiveUpdatesClient client) {
    if (!mounted ||
        client != _payoutLiveUpdatesClient ||
        _merchantTab != 3 ||
        _payoutRefreshTimer != null) {
      return;
    }
    _payoutRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_loadBookings()),
    );
  }

  void _stopPayoutLiveUpdates() {
    final client = _payoutLiveUpdatesClient;
    _payoutRefreshTimer?.cancel();
    _payoutRefreshTimer = null;
    _payoutLiveUpdatesClient = null;
    unawaited(_payoutLiveUpdatesSubscription?.cancel());
    _payoutLiveUpdatesSubscription = null;
    if (client != null) unawaited(client.close());
  }

  Future<void> _refreshAndScrollToTop() async {
    final refreshKey = switch (_merchantTab) {
      0 => _merchantAnalyticsUiStateFor(this).refreshKey,
      1 => null,
      3 => _managementRefreshKey,
      _ => _homeRefreshKey,
    };
    if (_merchantTab == 1) {
      await _merchantAddPageKey.currentState?.refreshAndScrollToTop();
      return;
    }

    final refresh = refreshKey?.currentState?.show();
    if (refresh != null) {
      await refresh;
    } else if (_merchantTab == 3) {
      await _refreshMerchantBookings();
    } else {
      await _refreshMerchantDashboardData();
    }

    if (!mounted) return;
    switch (_merchantTab) {
      case 0:
      case 3:
        break;
      default:
        return;
    }

    final controller = switch (_merchantTab) {
      0 => _merchantAnalyticsUiStateFor(this).scrollController,
      3 => _managementScrollController,
      _ => null,
    };
    if (controller?.hasClients == true) {
      await controller!.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _openMerchantProfile() {
    _pushMerchantProfile();
  }

  void _openMerchantSettings() {
    _pushMerchantProfile(openSettingsOnStart: true);
  }

  void _openMerchantHelpCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MerchantSupportDetailPage(
          title: 'Help Center',
          icon: Icons.help_outline_rounded,
          message:
              'Help articles and contact options will be available here soon.',
        ),
      ),
    );
  }

  void _openMerchantTermsOfService() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MerchantSupportDetailPage(
          title: 'Terms of Service',
          icon: Icons.description_outlined,
          message: 'The official Terms of Service will be available here soon.',
        ),
      ),
    );
  }

  void _pushMerchantProfile({bool openSettingsOnStart = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProfileDashboardPage(
          owner: _owner,
          profileImage: _imageProvider(_profileImage),
          venueCount: _businesses.length,
          bookings: _bookings,
          businesses: _businesses,
          onEditProfile: _openMerchantEditPanel,
          onLogout: widget.onLogout ?? (_) async {},
          api: _api,
          bookingRepository: _merchantBookingRepository,
          sessionProvider: _sessionProvider,
          onNavigate: _navigateFromMerchantProfile,
          onSwitchToCustomerPortal: widget.onSwitchToCustomerPortal,
          openSettingsOnStart: openSettingsOnStart,
        ),
      ),
    );
  }

  Future<void> _openMerchantBookingDeadlineSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProfileDashboardPage(
          owner: _owner,
          profileImage: _imageProvider(_profileImage),
          venueCount: _businesses.length,
          bookings: _bookings,
          businesses: _businesses,
          onEditProfile: _openMerchantEditPanel,
          onLogout: widget.onLogout ?? (_) async {},
          api: _api,
          bookingRepository: _merchantBookingRepository,
          sessionProvider: _sessionProvider,
          onNavigate: _navigateFromMerchantProfile,
          openBookingDeadlinesOnStart: true,
          onSwitchToCustomerPortal: widget.onSwitchToCustomerPortal,
        ),
      ),
    );
  }

  void _navigateFromMerchantProfile(int index) {
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMerchantMessages();
      });
      return;
    }
    setState(() => _merchantTab = index);
  }

  void _openMerchantMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesDashboardPage(
          owner: _owner,
          api: _api,
          onFooterNavigate: _navigateFromMerchantMessages,
          onSettingsSelected: _openMerchantSettingsFromMessages,
          onLogout: widget.onLogout,
          onHelpCenterSelected: _openMerchantHelpCenter,
          onTermsOfServiceSelected: _openMerchantTermsOfService,
        ),
      ),
    );
  }

  void _openMerchantSettingsFromMessages() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openMerchantSettings();
    });
  }

  void _navigateFromMerchantMessages(int index) {
    setState(() => _merchantTab = index);
    Navigator.of(context).pop();
    if (index == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMerchantProfile();
      });
    }
  }

  Future<void> _loadBusinesses({bool force = false}) async {
    final activeRequest = _businessesRequest;
    if (activeRequest != null) {
      await activeRequest;
      if (force) await _loadBusinesses();
      return;
    }

    late final Future<void> request;
    request = _fetchBusinesses().whenComplete(() {
      if (identical(_businessesRequest, request)) _businessesRequest = null;
    });
    _businessesRequest = request;
    return request;
  }

  Future<void> _fetchBusinesses() async {
    if (mounted) {
      setState(() {
        _businessesLoading = true;
        _businessesLoadError = null;
      });
    }
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final businesses = await _api.merchantBusinesses(token);
      if (mounted) {
        setState(() {
          _businesses = businesses;
          _businessesLoaded = true;
          _businessesLoading = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _businessesLoading = false;
          _businessesLoadError = _merchantLoadFailureMessage(
            'businesses',
            error,
          );
        });
      }
    }
  }

  Future<void> _loadBookings({bool force = false}) async {
    final activeRequest = _bookingsRequest;
    if (activeRequest != null) {
      await activeRequest;
      if (force) await _loadBookings();
      return;
    }

    late final Future<void> request;
    request = _fetchBookings().whenComplete(() {
      if (identical(_bookingsRequest, request)) {
        _bookingsRequest = null;
      }
    });
    _bookingsRequest = request;
    await request;
  }

  Future<void> _fetchBookings() async {
    if (mounted) {
      setState(() {
        _bookingsLoading = true;
        _bookingsLoadError = null;
      });
    }
    try {
      final bookings = await _merchantBookingRepository.loadBookings();
      if (mounted) {
        setState(() {
          final checkedInBookingIds = _bookings
              .where(
                (booking) =>
                    booking['checkedInAt'] != null &&
                    '${booking['checkedInAt']}'.trim().isNotEmpty,
              )
              .map((booking) => '${booking['id']}')
              .toSet();
          final newCheckInRecorded = bookings.any(
            (booking) =>
                booking['checkedInAt'] != null &&
                '${booking['checkedInAt']}'.trim().isNotEmpty &&
                !checkedInBookingIds.contains('${booking['id']}'),
          );
          _bookings = bookings;
          _bookingsLoaded = true;
          _bookingsLoading = false;
          if (newCheckInRecorded && _merchantTab == 3 && _payoutTab == 1) {
            _customerArrivalTab = 0;
          }
          if (_analyticsBookingType != 'All' &&
              !bookings.any((booking) {
                final type =
                    '${booking['businessType'] ?? booking['business_type'] ?? ''}'
                        .trim();
                return type.toLowerCase() ==
                    _analyticsBookingType.toLowerCase();
              })) {
            _analyticsBookingType = 'All';
          }
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _bookingsLoading = false;
          _bookingsLoadError = _merchantLoadFailureMessage(
            'bookings and payment data',
            error,
          );
        });
      }
    }
  }

  Future<void> _approveMerchantBooking(
    int bookingId, {
    int? matchmakingLobbyId,
  }) async {
    try {
      if (matchmakingLobbyId != null) {
        await _merchantBookingRepository.approveMatchmakingBooking(
          matchmakingLobbyId,
        );
      } else {
        await _merchantBookingRepository.approveBooking(bookingId);
      }
      await _loadBookings(force: true);
      _showMessage('Booking approved. The customer will be notified.');
    } on Exception catch (error) {
      _showMessage('Could not approve booking: $error');
    }
  }

  Future<void> _confirmMerchantBookingApproval(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id'] is num
        ? (booking['id'] as num).toInt()
        : int.tryParse('${booking['id'] ?? ''}');
    if (bookingId == null) {
      _showMessage('Could not approve this booking: invalid booking ID.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Approve booking request?', localize: true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _payoutManagementInfoRow(
              'Customer',
              booking['customerName'] ?? 'Customer',
            ),
            _payoutManagementInfoRow('Venue', booking['venueName'] ?? 'Venue'),
            _payoutManagementInfoRow(
              'Schedule',
              _bookingTimeRangeLabel(booking),
            ),
            _payoutManagementInfoRow(
              'Booking total',
              '\u{20B1} ${_bookingAmount(booking['total']).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            const AppText(
              'The customer will be notified after approval.',
              localize: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep request', localize: true),
          ),
          FilledButton(
            key: const ValueKey('merchant-booking-card-approve-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Approve booking', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _approveMerchantBooking(
      bookingId,
      matchmakingLobbyId: booking['matchmakingLobbyId'] is num
          ? (booking['matchmakingLobbyId'] as num).toInt()
          : null,
    );
  }

  Future<void> _declineMerchantBooking(
    int bookingId, {
    int? matchmakingLobbyId,
  }) async {
    final formKey = GlobalKey<FormState>();
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Decline booking?', localize: true),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Please provide a reason. The customer will receive it in Messages.',
                localize: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('merchant-booking-decline-reason'),
                autofocus: true,
                maxLength: 1000,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason for decline',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a reason to continue.'
                    : null,
                onSaved: (value) => reason = value?.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep booking', localize: true),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              formKey.currentState?.save();
              Navigator.pop(context, true);
            },
            child: const AppText('Decline booking', localize: true),
          ),
        ],
      ),
    );
    final declineReason = reason?.trim();
    if (confirmed != true || declineReason == null || declineReason.isEmpty) {
      return;
    }
    try {
      if (matchmakingLobbyId != null) {
        await _merchantBookingRepository.declineMatchmakingBooking(
          matchmakingLobbyId,
          reason: declineReason,
        );
      } else {
        await _merchantBookingRepository.declineBooking(
          bookingId,
          reason: declineReason,
        );
      }
      await _loadBookings(force: true);
      _showMessage('Booking declined.');
    } on Exception catch (error) {
      _showMessage('Could not decline booking: $error');
    }
  }

  Future<void> _deleteCompletedBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete completed booking?', localize: true),
        content: const AppText(
          'This permanently deletes the booking and its attendance and review '
          'records. This action cannot be undone.',
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
      await _merchantBookingRepository.deleteCompletedBooking(bookingId);
      await _loadBookings(force: true);
      if (mounted) _showMessage('Completed booking permanently deleted.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not delete completed booking: $error');
    }
  }

  Future<void> _setCashOnArrivalPaymentStatus(
    Map<String, dynamic> booking,
    String paymentStatus,
  ) async {
    try {
      await _merchantBookingRepository.setCashOnArrivalPaymentStatus(
        (booking['id'] as num).toInt(),
        paymentStatus: paymentStatus,
      );
      await _loadBookings(force: true);
      _showMessage(
        paymentStatus == 'partial'
            ? 'Cash downpayment recorded.'
            : 'Remaining balance marked as paid.',
      );
    } on Exception catch (error) {
      _showMessage('Could not update payment status: $error');
    }
  }

  // Kept temporarily for compatibility with older hot-reload state.
  // ignore: unused_element
  Future<void> _addBusiness() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final details = TextEditingController();
    final pricePerHour = TextEditingController();
    final imagePicker = ImagePicker();
    final formKey = GlobalKey<FormState>();
    const bookingTypes = ['Sports', 'Event', 'Fitness & Wellness'];
    String type = bookingTypes.contains(_businessTypeValue)
        ? _businessTypeValue!
        : 'Sports';
    String category =
        (_categoriesByBusinessType[type] ?? const ['Other']).first;
    String facility = 'Indoor';
    String? image;
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Add business', localize: true),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Booking type',
                            'Booking type',
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Sports',
                            child: AppText('Sports', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Event',
                            child: AppText('Event', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Fitness & Wellness',
                            child: AppText(
                              'Fitness & Wellness',
                              localize: true,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            type = value;
                            category =
                                (_categoriesByBusinessType[type] ??
                                        const ['Other'])
                                    .first;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Category', 'Category'),
                        ),
                        items:
                            <String>{
                                  ...(_categoriesByBusinessType[type] ??
                                      const []),
                                  'Other',
                                }
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: AppText(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
                      ),
                      TextFormField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Business name',
                            'Business name',
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter a name for your business.'
                            : null,
                      ),
                      TextFormField(
                        controller: address,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Address', 'Address'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please add your business address.'
                            : null,
                      ),
                      TextFormField(
                        controller: pricePerHour,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Price per hour',
                            'Price per hour',
                          ),
                          prefixText: '₱ ',
                          hintText: '300.00',
                        ),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          return price == null || price <= 0
                              ? 'Enter a price greater than ₱0.'
                              : null;
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: facility,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Facility type',
                            'Facility type',
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Indoor',
                            child: AppText('Indoor', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Outdoor',
                            child: AppText('Outdoor', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Covered',
                            child: AppText('Covered', localize: true),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => facility = value);
                          }
                        },
                      ),
                      TextField(
                        controller: details,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Details (optional)',
                            'Details (optional)',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await imagePicker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1400,
                            maxHeight: 900,
                            imageQuality: 75,
                          );
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          setDialogState(() => image = _dataUri(bytes));
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: AppText(
                          image == null ? 'Add image' : 'Image selected',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final session = await _sessionProvider.load();
                final token = session.apiToken;
                if (token == null || token.isEmpty) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                  _showMessage(
                    'Your session has expired. Please log in again.',
                  );
                  return;
                }
                await _api.createMerchantBusiness(
                  token: token,
                  business: {
                    'businessType': type,
                    'name': name.text.trim(),
                    'category': category,
                    'address': address.text.trim(),
                    'pricePerHour': double.parse(pricePerHour.text.trim()),
                    'facilityType': facility,
                    'details': details.text.trim(),
                    'imageUrl': image,
                  },
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const AppText('Add business', localize: true),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    address.dispose();
    details.dispose();
    pricePerHour.dispose();
    if (added == true) {
      await _loadBusinesses(force: true);
      if (mounted) {
        setState(() => _merchantTab = 0);
        _showMessage('Business added. You can finish setting it up in Add.');
      }
    }
  }

  Future<String?> _pickProfileImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      final dataUri = _dataUri(bytes);
      if (mounted) setState(() => _profileImage = dataUri);
      return dataUri;
    } on Exception catch (error) {
      _showMessage('Could not select avatar: $error');
      return null;
    }
  }

  String _dataUri(List<int> bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  ImageProvider<Object>? _imageProvider(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    return NetworkImage(value);
  }

  List<String> _businessImages(Map<String, dynamic> business) {
    final raw = business['imageUrls'] ?? business['image_urls'];
    final images = <String>[];
    if (raw is List) {
      images.addAll(raw.whereType<String>().where((value) => value.isNotEmpty));
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((value) => value.isNotEmpty),
          );
        }
      } on FormatException {
        // Ignore malformed optional gallery data and use the legacy image.
      }
    }
    if (images.isEmpty) {
      final legacy = _businessText(business, ['imageUrl', 'image_url']);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacy);
          if (decoded is List) {
            images.addAll(
              decoded.whereType<String>().where((value) => value.isNotEmpty),
            );
          }
        } on FormatException {
          images.add(legacy);
        }
        if (images.isEmpty) images.add(legacy);
      }
    }
    return images;
  }

  Widget _imageCarousel(List<String> images) {
    final controller = PageController(initialPage: 100000);
    var currentIndex = 0;
    return StatefulBuilder(
      builder: (context, setState) => Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: (index) {
              setState(() => currentIndex = index % images.length);
            },
            itemBuilder: (_, index) => Image(
              image: _imageProvider(images[index % images.length])!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => ColoredBox(
                color: AppColors.softOrange,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: _merchantOrange,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: AppText(
                  '${currentIndex + 1} of ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  localize: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImageGallery(
    BuildContext context,
    List<String> images,
  ) async {
    var currentIndex = 0;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: 100000),
                  itemCount: 1000000,
                  onPageChanged: (index) {
                    setDialogState(() => currentIndex = index % images.length);
                  },
                  itemBuilder: (_, index) => Center(
                    child: Image(
                      image: _imageProvider(images[index % images.length])!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: AppText(
                          '${currentIndex + 1} of ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          localize: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    decoration: InputDecoration(
      labelText: appLanguageText(label, label),
      hintText: appLanguageText(hint, hint),
      filled: true,
      fillColor: _merchantPage,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _merchantLine),
      ),
    ),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? 'Please enter $label.'
              : null
        : null,
  );
}

class _MerchantDashboardHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _MerchantDashboardHeader({required this.state});

  final _MerchantDashboardPageState state;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
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
    title: _headerTitle,
    backgroundColor: _merchantPage,
    surfaceTintColor: Colors.transparent,
    foregroundColor: _merchantInk,
    elevation: 0,
    scrolledUnderElevation: 0,
  );

  Widget get _headerTitle {
    switch (state._merchantTab) {
      case 0:
        final businessName = '${state._owner['businessName'] ?? ''}'.trim();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'Merchant Dashboard',
              style: AppTypography.pageTitle,
              localize: true,
            ),
            AppText(
              businessName.isEmpty ? 'Your business at a glance' : businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _merchantMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              localize: true,
            ),
          ],
        );
      case 1:
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: AppText(
                      'Add business',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.pageTitle,
                      localize: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  state._merchantSectionNotice(
                    key: 'merchant-add-info',
                    title: 'Add business',
                    message: 'Complete a News Card for each business before its Booking Card is published.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: () =>
                  state._merchantAddPageKey.currentState?.openAddBusinessForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Add', localize: true),
              style: FilledButton.styleFrom(
                backgroundColor: _merchantOrange,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size(0, 38),
                padding: AppSpacing.buttonPadding,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      case 3:
        return Row(
          children: [
            Flexible(
              child: AppText(
                'Bookings & payments',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.pageTitle,
                localize: true,
              ),
            ),
            state._merchantSectionNotice(
              key: 'merchant-payouts-info',
              title: 'Bookings & payments',
              message: 'Manage booking requests and track your earnings.',
            ),
          ],
        );
      default:
        return AppText(switch (state._merchantTab) {
          0 => 'Merchant Dashboard',
          1 => 'Add business',
          3 => 'Management',
          _ => 'Merchant Dashboard',
        });
    }
  }
}

class _MerchantDashboardContent extends StatelessWidget {
  const _MerchantDashboardContent({required this.state});

  final _MerchantDashboardPageState state;

  @override
  Widget build(BuildContext context) {
    if (state._merchantTab == 1) {
      return Column(
        children: [
          state._merchantSectionLoadStatus(
            key: 'merchant-businesses',
            title: 'businesses',
            loading: state._businessesLoading,
            loaded: state._businessesLoaded,
            error: state._businessesLoadError,
            onRetry: state._loadBusinesses,
          ),
          if (state._businessesLoaded)
            Expanded(
              child: MerchantAddPage(
                key: state._merchantAddPageKey,
                initialBusinessType: state._businessTypeValue,
                businesses: state._businesses,
                onBusinessesChanged: () => state._loadBusinesses(force: true),
                onSetBookingDeadlines:
                    state._openMerchantBookingDeadlineSettings,
              ),
            ),
        ],
      );
    }
    if (state._merchantTab == 3) {
      return state._merchantPayouts();
    }
    if (state._merchantTab == 2 || state._merchantTab == 4) {
      return const SizedBox.shrink();
    }
    if (state._merchantTab == 0) return state._merchantAnalyticsDashboard();
    return state._merchantHome();
  }
}
