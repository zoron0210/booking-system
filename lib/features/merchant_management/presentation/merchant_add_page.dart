import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'package:myapp/core/app_card_styles.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/data/merchant_add_session.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_fitness_form_sections.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_news_cards_section.dart';
import 'package:myapp/core/rating_widgets.dart';
import 'package:myapp/core/skeleton_loader.dart';
import 'package:myapp/features/venues/data/venue_address_geocoder.dart';

part 'merchant_add_business_list.dart';
part 'merchant_add_news_management.dart';
part 'merchant_add_business_form.dart';

const _addNavy = AppColors.navy;
Color get _addInk => AppColors.ink;
Color get _addOrange => AppColors.accent;
Color get _addSoftOrange => AppColors.softOrange;
Color get _addMuted => AppColors.muted;
Color get _addLine => AppColors.border;

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty && item != 'null')
        .toList();
  }
  return const [];
}

class _MerchantBusinessFormPanel extends StatefulWidget {
  const _MerchantBusinessFormPanel({required this.builder});

  final Widget Function(BuildContext context, StateSetter setPanelState)
  builder;

  @override
  State<_MerchantBusinessFormPanel> createState() =>
      _MerchantBusinessFormPanelState();
}

class _MerchantBusinessFormPanelState
    extends State<_MerchantBusinessFormPanel> {
  void _setPanelState(VoidCallback callback) {
    if (!mounted) return;
    setState(callback);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _setPanelState);
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _SportSlotInput {
  _SportSlotInput({
    required String sportType,
    required String pricePerHour,
    required this.fullStudio,
    required this.slotCount,
    required String includedPlayers,
    required String additionalPlayerFee,
  }) : sportType = TextEditingController(text: sportType),
       pricePerHour = TextEditingController(text: pricePerHour),
       includedPlayers = TextEditingController(text: includedPlayers),
       additionalPlayerFee = TextEditingController(text: additionalPlayerFee);

  final TextEditingController sportType;
  final TextEditingController pricePerHour;
  final TextEditingController includedPlayers;
  final TextEditingController additionalPlayerFee;
  bool fullStudio;
  int slotCount;

  void dispose() {
    sportType.dispose();
    pricePerHour.dispose();
    includedPlayers.dispose();
    additionalPlayerFee.dispose();
  }
}

class MerchantAddPage extends StatefulWidget {
  const MerchantAddPage({
    super.key,
    required this.initialBusinessType,
    required this.businesses,
    required this.onBusinessesChanged,
    this.api,
    this.onSetBookingDeadlines,
    this.session,
  });

  final String? initialBusinessType;
  final List<Map<String, dynamic>> businesses;
  final Future<void> Function() onBusinessesChanged;
  final AuthApi? api;
  final Future<void> Function()? onSetBookingDeadlines;
  final MerchantAddSession? session;

  @override
  MerchantAddPageState createState() => MerchantAddPageState();
}

class MerchantAddPageState extends State<MerchantAddPage> {
  void _updateAddPageState(VoidCallback update) => setState(update);

  static const _categories = {
    'Sports': [
      'Tennis',
      'Pickleball',
      'Basketball',
      'Volleyball',
      'Badminton',
      'Football',
      'Futsal',
      'Table Tennis',
      'Squash',
    ],
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

  late final AuthApi _api;
  late final MerchantAddSession _session;
  bool _saving = false;
  String _selectedBusinessType = 'All';
  String _selectedAddSection = 'Booking cards';
  String _businessSearchQuery = '';
  final _businessSearchController = TextEditingController();
  final _addPageScrollController = ScrollController();
  List<Map<String, dynamic>> _newsPosts = [];
  bool _newsLoading = true;
  bool _newsPostsLoaded = false;
  String? _newsPostsLoadError;
  Future<void>? _newsPostsRequest;
  bool _showingBookingDeadlineReminder = false;
  final _addPageRefreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void dispose() {
    _businessSearchController.dispose();
    _addPageScrollController.dispose();
    super.dispose();
  }

  Future<void> refreshAndScrollToTop() async {
    final refresh = _addPageRefreshKey.currentState?.show();
    if (refresh != null) {
      await refresh;
    } else {
      await _refreshAddPage();
    }
    if (!mounted) return;
    if (_addPageScrollController.hasClients) {
      await _addPageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void openAddBusinessForm() {
    _openForm();
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _session = widget.session ?? AppMerchantAddSession();
    _loadNewsPosts();
    if (widget.onSetBookingDeadlines != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBookingDeadlineReminderIfNeeded();
      });
    }
  }

  Future<void> _showBookingDeadlineReminderIfNeeded() async {
    if (!mounted || _showingBookingDeadlineReminder) return;
    final reminderDismissed = await _session.bookingDeadlineReminderDismissed();
    if (!mounted || reminderDismissed) return;

    _showingBookingDeadlineReminder = true;
    var dontShowAgain = false;
    final setTime = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const ValueKey('booking-deadline-reminder'),
          title: const AppText('Set your booking time limits'),
          content: const AppText(
            'Choose how long customers have to wait for approval and make payment. You can change these limits later in Settings.',
          ),
          actions: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 40,
                  child: Checkbox(
                    key: const ValueKey(
                      'booking-deadline-reminder-dont-show-again',
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: dontShowAgain,
                    onChanged: (value) =>
                        setDialogState(() => dontShowAgain = value ?? false),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: AppText(
                    "Don't show again for 24 hours",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                TextButton(
                  key: const ValueKey('booking-deadline-reminder-cancel'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    fixedSize: const Size(52, 36),
                    minimumSize: const Size(52, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('booking-deadline-reminder-set-time'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    fixedSize: const Size(66, 36),
                    minimumSize: const Size(66, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const AppText('Set time'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    _showingBookingDeadlineReminder = false;

    if (!mounted) return;
    if (dontShowAgain) {
      try {
        await _session.dismissBookingDeadlineReminder();
      } on Exception catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: AppText(error.toString())));
        }
      }
    }
    if (setTime == true) {
      await widget.onSetBookingDeadlines?.call();
    }
  }

  @override
  void didUpdateWidget(covariant MerchantAddPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businesses != widget.businesses) {
      _loadNewsPosts();
    }
  }

  int? _id(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  int? _businessId(Map<String, dynamic> business) =>
      _id(business['id'] ?? business['businessId']);

  int? _postBusinessId(Map<String, dynamic> post) =>
      _id(post['businessId'] ?? post['business_id']);

  double? _mapCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Future<LatLng?> _chooseBusinessLocation({
    required double? latitude,
    required double? longitude,
    required String address,
  }) async {
    LatLng? selected = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
    String? lookupMessage;
    if (address.trim().isNotEmpty) {
      try {
        final addressLocation = await geocodeVenueAddress(address);
        if (addressLocation == null) {
          lookupMessage = 'Could not find this address. Tap the map to place the pin manually.';
        } else {
          selected = addressLocation;
        }
      } on Exception catch (error) {
        lookupMessage =
            'Could not look up the address ($error). Tap the map to place the pin manually.';
      }
    }
    if (!mounted) return null;
    final center = selected ?? const LatLng(10.3157, 123.8854);
    return showDialog<LatLng>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Pin court location', localize: true),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .58,
            child: Column(
              children: [
                const AppText(
                  'The address is pinned automatically. Tap the map to adjust it to the exact venue entrance.',
                  style: TextStyle(fontSize: 12),
                  localize: true,
                ),
                if (lookupMessage != null) ...[
                  const SizedBox(height: 6),
                  AppText(
                    lookupMessage,
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: selected == null ? 12 : 15,
                        onTap: (_, point) =>
                            setDialogState(() => selected = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.myapp',
                        ),
                        if (selected != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selected!,
                                width: 44,
                                height: 48,
                                child: Icon(
                                  Icons.location_pin,
                                  color: _addOrange,
                                  size: 42,
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
                  ),
                ),
                const SizedBox(height: 6),
                AppText(
                  selected == null
                      ? 'No map pin selected'
                      : '${selected!.latitude.toStringAsFixed(6)}, '
                            '${selected!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const AppText('Use this location', localize: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNewsPosts({bool force = false}) async {
    final activeRequest = _newsPostsRequest;
    if (activeRequest != null) {
      await activeRequest;
      if (force) await _loadNewsPosts();
      return;
    }

    late final Future<void> request;
    request = _fetchNewsPosts().whenComplete(() {
      if (identical(_newsPostsRequest, request)) _newsPostsRequest = null;
    });
    _newsPostsRequest = request;
    await request;
  }

  Future<void> _fetchNewsPosts() async {
    if (mounted) {
      setState(() {
        _newsLoading = true;
        _newsPostsLoadError = null;
      });
    }
    try {
      final token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in again.', 401);
      }
      final posts = (await _api.venues.merchantNewsPosts(token))
          .map((post) => post.toViewData())
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _newsPosts = posts;
          _newsPostsLoaded = true;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _newsPostsLoadError = error is AuthApiException
              ? error.userMessage
              : 'Could not load News Cards. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  Future<void> _refreshAddPage() async {
    await Future.wait<void>([
      widget.onBusinessesChanged(),
      _loadNewsPosts(force: true),
    ]);
  }

  Widget get _newsPostsLoadStatus {
    if (!_newsLoading && _newsPostsLoadError == null) {
      return const SizedBox.shrink();
    }
    if (_newsLoading && !_newsPostsLoaded) {
      return const Column(
        key: ValueKey('merchant-news-cards-loading-skeleton'),
        children: [
          SkeletonBlock(height: 112, borderRadius: 14),
          SizedBox(height: 6),
          SkeletonBlock(height: 112, borderRadius: 14),
        ],
      );
    }

    final showingPreviousData = _newsPostsLoaded && _newsPostsLoadError != null;
    final message = _newsLoading
        ? 'Refreshing News Cards…'
        : showingPreviousData
        ? 'Could not refresh News Cards. Showing the last successfully loaded cards. $_newsPostsLoadError'
        : 'Could not load News Cards. $_newsPostsLoadError';
    return Card(
      key: const ValueKey('merchant-news-cards-load-status'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_newsLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.cloud_off_outlined, color: _addOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(message, style: const TextStyle(height: 1.35)),
                  if (!_newsLoading) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      key: const ValueKey('merchant-news-cards-retry'),
                      onPressed: () => unawaited(_loadNewsPosts()),
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

  Widget get _publishingLifecycleNotice => Card(
    key: const ValueKey('merchant-publishing-lifecycle'),
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _addOrange),
          const SizedBox(width: 8),
          const Expanded(
            child: AppText(
              'Set up the business details first. Customers can see its Booking Card after you complete and publish a News Card with a title, venue update, and venue photo. Drafts and incomplete News Cards are not customer-visible.',
              style: TextStyle(fontSize: 12, height: 1.35),
              localize: true,
            ),
          ),
        ],
      ),
    ),
  );

  void _clearBusinessFilters() {
    _businessSearchController.clear();
    _updateAddPageState(() {
      _businessSearchQuery = '';
      _selectedBusinessType = 'All';
    });
  }

  Widget _emptyBusinessCards({
    required String title,
    required String message,
    required String actionLabel,
    required String actionKey,
    required VoidCallback onAction,
    IconData icon = Icons.storefront_outlined,
  }) => Card(
    key: ValueKey(actionKey),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: _addMuted),
          const SizedBox(height: 8),
          AppText(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            localize: true,
          ),
          const SizedBox(height: 4),
          AppText(
            message,
            style: TextStyle(color: _addMuted, height: 1.35),
            textAlign: TextAlign.center,
            localize: true,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: ValueKey('$actionKey-action'),
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: AppText(actionLabel, localize: true),
          ),
        ],
      ),
    ),
  );

  Widget _timePickerField({
    required BuildContext context,
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay> onChanged,
  }) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final selected = await showTimePicker(
        context: context,
        initialTime: value ?? TimeOfDay.now(),
      );
      if (selected != null) onChanged(selected);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: appLanguageText(label, label),
        prefixIcon: const Icon(Icons.schedule_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: AppText(
        value?.format(context) ?? 'Select time',
        style: TextStyle(
          color: value == null ? _addMuted : _addInk,
          fontWeight: value == null ? FontWeight.normal : FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _fitnessCategoryCard(
    MerchantFitnessCategoryInput category, {
    required ValueChanged<String> onDiscountChanged,
  }) => MerchantFitnessCategoryCard(
    category: category,
    onDiscountChanged: onDiscountChanged,
  );

  Widget _fitnessCoachCard(
    MerchantFitnessCoachInput coach, {
    required VoidCallback onPickImage,
    required VoidCallback onRemove,
  }) => MerchantFitnessCoachCard(
    coach: coach,
    onPickImage: onPickImage,
    onRemove: onRemove,
    profileImageProvider: coach.profileImageUrl == null
        ? null
        : _safeImageProvider(coach.profileImageUrl!),
  );

  String _formatTime(TimeOfDay value) {
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatHours(TimeOfDay? opening, TimeOfDay? closing) {
    if (opening == null || closing == null) return '';
    return '${_formatTime(opening)} - ${_formatTime(closing)}';
  }

  Widget _repeatableEventNeeds({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> values,
    required StateSetter setDialogState,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: appLanguageText(label, label),
          hintText: appLanguageText(hint, hint),
          suffixIcon: IconButton(
            tooltip: appLanguageText('Add', 'Add'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || values.contains(value)) return;
              setDialogState(() {
                values.add(value);
                controller.clear();
              });
            },
          ),
        ),
        onSubmitted: (_) {
          final value = controller.text.trim();
          if (value.isEmpty || values.contains(value)) return;
          setDialogState(() {
            values.add(value);
            controller.clear();
          });
        },
      ),
      if (values.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in values)
                InputChip(
                  label: AppText(value),
                  onDeleted: () => setDialogState(() => values.remove(value)),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 3),
    child: Align(
      alignment: Alignment.centerLeft,
      child: AppText(
        text,
        localize: true,
        style: TextStyle(
          color: _addMuted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    ),
  );

  Widget _businessReviewCard({
    required String name,
    required String type,
    required String category,
    required String address,
    required String hours,
    required String availableDays,
    required int imageCount,
    required bool complete,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: complete ? AppColors.successSurface : AppColors.softStatus,
      border: Border.all(
        color: complete ? AppColors.success : AppColors.warning,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              complete ? Icons.task_alt_rounded : Icons.rate_review_outlined,
              size: 19,
              color: complete ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                complete ? 'Ready to publish' : 'Finish required details',
                style: TextStyle(color: _addInk, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _reviewRow('Business type', type),
        _reviewRow('Venue name', name.isEmpty ? 'Not entered' : name),
        _reviewRow(
          'Categories',
          category.isEmpty ? 'Not configured' : category,
        ),
        _reviewRow('Address', address.isEmpty ? 'Not entered' : address),
        _reviewRow('Hours', hours.isEmpty ? 'Not selected' : hours),
        _reviewRow(
          'Available',
          availableDays.isEmpty ? 'Select at least one day' : availableDays,
        ),
        _reviewRow(
          'Photos',
          imageCount == 0 ? 'Required · none added' : '$imageCount added',
        ),
        const SizedBox(height: 6),
        AppText(
          complete
              ? 'Check the information above, then publish your booking card.'
              : 'Name, opening hours, at least one available day, address, and at least one venue photo are required. Amenity notes are optional.',
          style: TextStyle(color: _addMuted, fontSize: 11, height: 1.35),
        ),
      ],
    ),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: AppText(
            label,
            style: TextStyle(
              color: _addMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: AppText(
            value,
            style: TextStyle(
              color: _addInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    key: _addPageRefreshKey,
    onRefresh: _refreshAddPage,
    child: ListView(
      controller: _addPageScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const SizedBox(height: 6),
        _businessFilterAndSearch(),
        const SizedBox(height: 6),
        _addSectionTabs(),
        const SizedBox(height: 6),
        _publishingLifecycleNotice,
        _newsPostsLoadStatus,
        if (_selectedAddSection == 'News cards') ...[
          const SizedBox(height: 6),
          if (_newsPostsLoaded &&
              widget.businesses.isNotEmpty &&
              _filteredNewsCardBusinesses.isEmpty) ...[
            _emptyBusinessCards(
              title: 'No businesses match these filters',
              message:
                  'Try a different search or business type to find a News Card to complete.',
              actionLabel: 'Clear filters',
              actionKey: 'merchant-news-filter-no-results',
              icon: Icons.search_off_rounded,
              onAction: _clearBusinessFilters,
            ),
          ] else if (_newsPostsLoaded && widget.businesses.isEmpty) ...[
            _emptyBusinessCards(
              title: 'Add a business first',
              message: 'Each business needs its own News Card.',
              actionLabel: 'Add business',
              actionKey: 'merchant-news-needs-business',
              onAction: openAddBusinessForm,
            ),
          ] else if (_newsPostsLoaded)
            MerchantNewsCardsSection(
              businesses: _filteredNewsCardBusinesses,
              posts: _newsPosts,
              loading: false,
              onComplete: _openNewsFormForBusiness,
              onEdit: _openNewsForm,
              onDelete: _deleteNewsPost,
              onPublish: _publishNewsPost,
            ),
        ] else ...[
          const SizedBox(height: 6),
          if (_newsPostsLoaded && widget.businesses.isEmpty)
            _emptyBusinessCards(
              title: 'No businesses yet',
              message:
                  'Add your venue details, then create and publish its News Card to make the Booking Card available to customers.',
              actionLabel: 'Add your first business',
              actionKey: 'merchant-booking-cards-no-businesses',
              onAction: openAddBusinessForm,
            )
          else if (_newsPostsLoaded && _filteredNewsCardBusinesses.isEmpty)
            _emptyBusinessCards(
              title: 'No businesses match these filters',
              message: 'Clear your search or choose a different business type.',
              actionLabel: 'Clear filters',
              actionKey: 'merchant-booking-cards-filter-no-results',
              icon: Icons.search_off_rounded,
              onAction: _clearBusinessFilters,
            )
          else if (_newsPostsLoaded && _filteredBusinesses.isEmpty)
            _emptyBusinessCards(
              title: 'No Booking Cards are ready yet',
              message:
                  'Complete and publish a News Card with a title, venue update, and venue photo to make a business visible to customers.',
              actionLabel: 'Open News Cards',
              actionKey: 'merchant-booking-cards-not-ready',
              icon: Icons.pending_actions_rounded,
              onAction: () =>
                  _updateAddPageState(() => _selectedAddSection = 'News cards'),
            )
          else if (_newsPostsLoaded)
            for (final business in _filteredBusinesses) ...[
              _businessCard(business),
              const SizedBox(height: 6),
            ]
          else
            const SizedBox.shrink(),
        ],
      ],
    ),
  );

  String _formatPrice(dynamic value, {bool hourly = true}) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || amount <= 0) return '';
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return hourly ? '₱$formatted / hr' : '₱$formatted';
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

  List<String> _businessTags(dynamic value) {
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

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _addMuted),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _addMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _tag(IconData? icon, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _addOrange),
            const SizedBox(width: 6),
          ],
          AppText(
            label,
            style: TextStyle(
              color: _addOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _priceBox(
    String price, {
    String label = 'Price / hour',
    bool hasRatePeriods = false,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: _addLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            hasRatePeriods ? 'Rate schedule' : label,
            style: TextStyle(
              color: _addMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppText(
          price,
          style: TextStyle(color: _addInk, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  ImageProvider<Object>? _imageProvider(String value) {
    if (value.startsWith('data:image/')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    return NetworkImage(value);
  }

  ImageProvider<Object>? _safeImageProvider(String value) {
    try {
      return _imageProvider(value);
    } on FormatException {
      return null;
    }
  }

  String? _businessPrimaryImage(Map<String, dynamic> business) {
    final images = _businessImageUrls(business);
    return images.isEmpty ? null : images.first;
  }

  List<String> _businessImageUrls(Map<String, dynamic> business) {
    final value = business['imageUrls'] ?? business['image_urls'];
    if (value is List) {
      final images = value
          .whereType<String>()
          .where((image) => image.isNotEmpty)
          .toList();
      if (images.isNotEmpty) return images;
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          final images = decoded
              .whereType<String>()
              .where((image) => image.isNotEmpty)
              .toList();
          if (images.isNotEmpty) return images;
        }
      } on FormatException {
        // Use the legacy primary image field below.
      }
    }
    final legacyImage = business['imageUrl'] ?? business['image_url'];
    if (legacyImage is! String || legacyImage.isEmpty) return [];
    try {
      final decoded = jsonDecode(legacyImage);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((image) => image.isNotEmpty)
            .toList();
      }
    } on FormatException {
      return [legacyImage];
    }
    return [legacyImage];
  }

  String _dataUri(List<int> bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  String _formatRatePeriods(List<Map<String, dynamic>> periods) => periods
      .whereType<Map>()
      .map((period) {
        final start = period['start'] ?? '';
        final end = period['end'] ?? '';
        final price = _formatPrice(
          period['pricePerHour'] ?? period['price_per_hour'] ?? period['price'],
        );
        return '$start - $end${price.isEmpty ? '' : ' ($price)'}';
      })
      .join(', ');
}
