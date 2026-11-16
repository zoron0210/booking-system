part of 'merchant_add_page.dart';

extension _MerchantAddBusinessForm on MerchantAddPageState {
  Future<void> _openForm([Map<String, dynamic>? editingBusiness]) async {
    final editing = editingBusiness != null;
    final name = TextEditingController();
    final address = TextEditingController();
    var locationManuallySelected = false;
    double? latitude = _mapCoordinate(
      editingBusiness?['latitude'] ?? editingBusiness?['lat'],
    );
    double? longitude = _mapCoordinate(
      editingBusiness?['longitude'] ?? editingBusiness?['lng'],
    );
    final visitUrl = TextEditingController();
    final price = TextEditingController();
    final totalSlots = TextEditingController(
      text:
          '${editingBusiness?['slotCount'] ?? editingBusiness?['slot_count'] ?? 1}',
    );
    final includedPlayers = TextEditingController();
    final additionalPlayerFee = TextEditingController();
    final details = TextEditingController();
    final categoryOther = TextEditingController();
    final amenityOther = TextEditingController();
    final eventTypeOther = TextEditingController();
    final eventAttendanceMin = TextEditingController();
    final eventAttendanceMax = TextEditingController();
    final accessibilityInput = TextEditingController();
    final parkingInput = TextEditingController();
    final securityInput = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const types = ['Sports', 'Event', 'Fitness & Wellness'];
    String type = types.contains(editingBusiness?['businessType'])
        ? editingBusiness!['businessType'] as String
        : types.contains(widget.initialBusinessType)
        ? widget.initialBusinessType!
        : 'Sports';
    final existingMatchmaking = editingBusiness?['allowMatchmaking'];
    var allowMatchmaking =
        existingMatchmaking == null ||
        existingMatchmaking == true ||
        existingMatchmaking == 1 ||
        existingMatchmaking == '1';
    final existingCategory = editingBusiness?['category'] as String?;
    String category =
        {
          ...MerchantAddPageState._categories[type]!,
          'Other',
        }.contains(existingCategory)
        ? existingCategory ?? MerchantAddPageState._categories[type]!.first
        : 'Other';
    if (category == 'Other' && existingCategory != null) {
      categoryOther.text = existingCategory == 'Other' ? '' : existingCategory;
    }
    String facility = editingBusiness?['facilityType'] as String? ?? 'Indoor';
    TimeOfDay? parseTime(dynamic value) {
      final text = '$value'.trim();
      final match = RegExp(
        r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) {
        return null;
      }
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (match.group(3)!.toUpperCase() == 'PM' && hour != 12) hour += 12;
      if (match.group(3)!.toUpperCase() == 'AM' && hour == 12) hour = 0;
      return hour < 24 && minute < 60
          ? TimeOfDay(hour: hour, minute: minute)
          : null;
    }

    (TimeOfDay?, TimeOfDay?) parseHours(String? value) {
      if (value == null) return (null, null);
      final parts = value.split(' - ');
      return parts.length == 2
          ? (parseTime(parts[0]), parseTime(parts[1]))
          : (null, null);
    }

    final availableDays = <String>{..._weekdays};
    final existingAvailability = editingBusiness?['availability'] as String?;
    if (existingAvailability != null &&
        existingAvailability.trim().isNotEmpty) {
      availableDays
        ..clear()
        ..addAll(existingAvailability.split(',').map((day) => day.trim()));
    }
    final hours = parseHours(editingBusiness?['hours'] as String?);
    TimeOfDay? openingTime = hours.$1;
    TimeOfDay? closingTime = hours.$2;
    final sportSlots = <_SportSlotInput>[];
    final fitnessCategories = <MerchantFitnessCategoryInput>[];
    final fitnessCoaches = <MerchantFitnessCoachInput>[];
    final amenities = <String>{};
    final eventTypes = <String>[];
    final accessibilityNeeds = <String>[];
    final parkingNeeds = <String>[];
    final securityNeeds = <String>[];
    const eventTypeOptions = [
      'Conference',
      'Wedding',
      'Workshop',
      'Corporate meeting',
      'Birthday',
      'Seminar',
      'Party',
      'Other',
    ];
    const amenityOptions = [
      'Parking',
      'Pet-friendly',
      'Restroom',
      'Shower',
      'Store',
      'Other',
    ];
    final images = <String>[];
    final existingBusinessLogo =
        editingBusiness?['businessLogoUrl'] ??
        editingBusiness?['business_logo_url'];
    var businessLogoUrl = existingBusinessLogo is String
        ? existingBusinessLogo
        : null;
    final existingImages =
        editingBusiness?['imageUrls'] ?? editingBusiness?['image_urls'];
    if (existingImages is List) {
      images.addAll(
        existingImages.whereType<String>().where((value) => value.isNotEmpty),
      );
    } else if (existingImages is String && existingImages.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingImages);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((value) => value.isNotEmpty),
          );
        }
      } on FormatException {
        // Fall back to the legacy single-image field below.
      }
    }
    if (images.isEmpty) {
      final legacyImage = editingBusiness?['imageUrl'] as String?;
      if (legacyImage != null && legacyImage.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyImage);
          if (decoded is List) {
            images.addAll(
              decoded.whereType<String>().where((value) => value.isNotEmpty),
            );
          }
        } on FormatException {
          images.add(legacyImage);
        }
        if (images.isEmpty) images.add(legacyImage);
      }
    }
    name.text = editingBusiness?['name'] as String? ?? '';
    address.text = editingBusiness?['address'] as String? ?? '';
    final originalAddress = address.text.trim();
    visitUrl.text =
        editingBusiness?['visitUrl'] as String? ??
        editingBusiness?['visit_url'] as String? ??
        '';
    final existingPrice = type == 'Event'
        ? (editingBusiness?['eventFee'] ??
              editingBusiness?['event_fee'] ??
              editingBusiness?['pricePerHour'] ??
              editingBusiness?['price_per_hour'])
        : (editingBusiness?['pricePerHour'] ??
              editingBusiness?['price_per_hour'] ??
              editingBusiness?['price'] ??
              editingBusiness?['hourlyRate']);
    price.text = existingPrice?.toString() ?? '';
    includedPlayers.text =
        '${editingBusiness?['includedPlayers'] ?? editingBusiness?['included_players'] ?? ''}';
    additionalPlayerFee.text =
        '${editingBusiness?['additionalPlayerFee'] ?? editingBusiness?['additional_player_fee'] ?? ''}';
    details.text = editingBusiness?['details'] as String? ?? '';
    dynamic existingEventTypes = editingBusiness?['eventTypes'];
    if (existingEventTypes is String) {
      try {
        existingEventTypes = jsonDecode(existingEventTypes);
      } on FormatException {
        existingEventTypes = null;
      }
    }
    if (existingEventTypes is List) {
      eventTypes.addAll(existingEventTypes.whereType<String>());
    }
    eventAttendanceMin.text =
        '${editingBusiness?['attendanceMin'] ?? editingBusiness?['estimatedAttendanceMin'] ?? ''}';
    eventAttendanceMax.text =
        '${editingBusiness?['attendanceMax'] ?? editingBusiness?['estimatedAttendanceMax'] ?? ''}';
    accessibilityNeeds.addAll(
      _stringList(editingBusiness?['accessibilityNeeds']),
    );
    parkingNeeds.addAll(_stringList(editingBusiness?['parkingNeeds']));
    securityNeeds.addAll(_stringList(editingBusiness?['securityNeeds']));
    String eventDetailValue(String label) {
      final match = RegExp(
        '^${RegExp.escape(label)}:\\s*(.*)\$',
        multiLine: true,
      ).firstMatch(details.text);
      return match?.group(1)?.trim() ?? '';
    }

    if (editing && type == 'Event') {
      if (eventTypes.isEmpty) {
        eventTypes.addAll(
          eventDetailValue('Event types')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      if (eventTypes.isEmpty) {
        eventTypes.addAll(
          eventDetailValue('Event type')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      final customEventType = eventTypes
          .where(
            (value) => !eventTypeOptions.contains(value) || value == 'Other',
          )
          .firstWhere((value) => value != 'Other', orElse: () => '');
      if (customEventType.isNotEmpty) {
        eventTypes
          ..remove(customEventType)
          ..remove('Other')
          ..add('Other');
        eventTypeOther.text = customEventType;
      }
      final attendance = eventDetailValue('Estimated attendance')
          .replaceAll('guests', '')
          .trim()
          .split('-')
          .map((value) => value.trim())
          .toList();
      if (eventAttendanceMin.text.isEmpty && attendance.isNotEmpty) {
        eventAttendanceMin.text = attendance.first;
      }
      if (eventAttendanceMax.text.isEmpty && attendance.length > 1) {
        eventAttendanceMax.text = attendance[1];
      }
      List<String> parseNeeds(String label) =>
          eventDetailValue(label)
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      if (accessibilityNeeds.isEmpty) {
        accessibilityNeeds.addAll(parseNeeds('Accessibility needs'));
      }
      if (parkingNeeds.isEmpty) {
        parkingNeeds.addAll(parseNeeds('Parking needs'));
      }
      if (securityNeeds.isEmpty) {
        securityNeeds.addAll(parseNeeds('Security needs'));
      }
      const eventLabels = [
        'Event type:',
        'Event types:',
        'Estimated attendance:',
        'Accessibility needs:',
        'Parking needs:',
        'Security needs:',
      ];
      details.text = details.text
          .split('\n')
          .where((line) => !eventLabels.any((label) => line.startsWith(label)))
          .join('\n')
          .trim();
    }
    dynamic existingAmenities = editingBusiness?['tags'];
    if (existingAmenities is String) {
      try {
        existingAmenities = jsonDecode(existingAmenities);
      } on FormatException {
        existingAmenities = null;
      }
    }
    if (existingAmenities is List) {
      amenities.addAll(existingAmenities.whereType<String>());
      final customAmenities = amenities
          .where((value) => !amenityOptions.contains(value))
          .toList();
      if (customAmenities.isNotEmpty) {
        amenities
          ..removeAll(customAmenities)
          ..add('Other');
        amenityOther.text = customAmenities.join(', ');
      }
    }
    dynamic rawSportsSlots =
        editingBusiness?['sportsSlots'] ??
        editingBusiness?['sports_slots_json'];
    if (rawSportsSlots is String) {
      try {
        rawSportsSlots = jsonDecode(rawSportsSlots);
      } on FormatException {
        rawSportsSlots = null;
      }
    }
    if (rawSportsSlots is List) {
      for (final item in rawSportsSlots.whereType<Map>()) {
        sportSlots.add(
          _SportSlotInput(
            sportType: '${item['sportType'] ?? ''}',
            pricePerHour: '${item['pricePerHour'] ?? ''}',
            fullStudio: item['fullStudio'] == true,
            slotCount: int.tryParse('${item['slotCount']}') ?? 1,
            includedPlayers:
                '${item['includedPlayers'] ?? includedPlayers.text}',
            additionalPlayerFee:
                '${item['additionalPlayerFee'] ?? additionalPlayerFee.text}',
          ),
        );
      }
    }
    if (sportSlots.isEmpty && editingBusiness != null && type == 'Sports') {
      final total = int.tryParse(totalSlots.text) ?? 1;
      sportSlots.add(
        _SportSlotInput(
          sportType: category == 'Other' ? categoryOther.text.trim() : category,
          pricePerHour: price.text,
          fullStudio: true,
          slotCount: total,
          includedPlayers: includedPlayers.text,
          additionalPlayerFee: additionalPlayerFee.text,
        ),
      );
    }
    List<dynamic> decodeJsonList(dynamic value) {
      if (value is List) return value;
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded;
        } on FormatException {
          return const [];
        }
      }
      return const [];
    }

    final existingFitnessCategories = decodeJsonList(
      editingBusiness?['fitnessCategories'] ??
          editingBusiness?['fitness_categories_json'],
    );
    for (final item in existingFitnessCategories.whereType<Map>()) {
      final discountType = '${item['yearlyDiscountType'] ?? 'none'}';
      fitnessCategories.add(
        MerchantFitnessCategoryInput(
          category: '${item['category'] ?? item['name'] ?? ''}',
          sessionPrice: '${item['sessionPrice'] ?? ''}',
          monthlyPrice: '${item['monthlyPrice'] ?? ''}',
          yearlyPrice: '${item['yearlyPrice'] ?? ''}',
          yearlyDiscountType:
              const {'none', 'freeMonths', 'percentage'}.contains(discountType)
              ? discountType
              : 'none',
          yearlyDiscountValue: '${item['yearlyDiscountValue'] ?? ''}',
        ),
      );
    }
    if (fitnessCategories.isNotEmpty && type == 'Fitness & Wellness') {
      categoryOther.clear();
    }
    if (fitnessCategories.isEmpty &&
        editingBusiness != null &&
        type == 'Fitness & Wellness') {
      fitnessCategories.add(
        MerchantFitnessCategoryInput(
          category: existingCategory == 'Other'
              ? categoryOther.text.trim()
              : existingCategory ?? '',
          sessionPrice: price.text,
        ),
      );
    }
    for (final item in decodeJsonList(
      editingBusiness?['fitnessCoaches'] ??
          editingBusiness?['fitness_coaches_json'],
    ).whereType<Map>()) {
      fitnessCoaches.add(
        MerchantFitnessCoachInput(
          name: '${item['name'] ?? ''}',
          monthlyPrice: '${item['monthlyPrice'] ?? ''}',
          profileImageUrl: '${item['profileImageUrl'] ?? ''}'.trim().isEmpty
              ? null
              : '${item['profileImageUrl']}',
        ),
      );
    }
    if (type == 'Sports') categoryOther.clear();
    String? validationMessage;
    var submitted = false;
    var panelOpen = true;
    var scheduleValidationAttempted = false;
    final businessBasicsKey = GlobalKey();
    final scheduleSectionKey = GlobalKey();
    final reviewSectionKey = GlobalKey();
    final sportsSelectionKey = GlobalKey();
    final sportsSectionKey = GlobalKey();
    final eventTypesKey = GlobalKey();
    final eventSectionKey = GlobalKey();
    final eventAttendanceKey = GlobalKey();
    final fitnessCategoriesKey = GlobalKey();
    final fitnessSectionKey = GlobalKey();
    final fitnessCoachesKey = GlobalKey();
    final imageInputKey = GlobalKey();
    final venueNameKey = GlobalKey();
    final categoryOtherKey = GlobalKey();
    final amenityOtherKey = GlobalKey();
    final addressKey = GlobalKey();
    final openingTimeKey = GlobalKey();
    final closingTimeKey = GlobalKey();
    final availableDaysKey = GlobalKey();

    bool scheduleComplete() =>
        openingTime != null &&
        closingTime != null &&
        address.text.trim().isNotEmpty &&
        availableDays.isNotEmpty;

    bool positiveAmount(String value) {
      final amount = double.tryParse(value.trim());
      return amount != null &&
          amount.isFinite &&
          amount > 0 &&
          amount <= 99999999.99;
    }

    bool bookingDetailsComplete() {
      if (amenities.contains('Other') && amenityOther.text.trim().isEmpty) {
        return false;
      }
      if (type == 'Sports') {
        final capacity = int.tryParse(totalSlots.text.trim());
        final names = sportSlots
            .map((sport) => sport.sportType.text.trim().toLowerCase())
            .toList();
        return capacity != null &&
            capacity > 0 &&
            capacity <= 100 &&
            sportSlots.isNotEmpty &&
            names.every((name) => name.isNotEmpty) &&
            names.toSet().length == names.length &&
            sportSlots.every((sport) {
              final included = sport.includedPlayers.text.trim();
              final extra = sport.additionalPlayerFee.text.trim();
              final includedCount = int.tryParse(included);
              final extraFee = double.tryParse(extra);
              return positiveAmount(sport.pricePerHour.text) &&
                  sport.slotCount > 0 &&
                  sport.slotCount <= capacity &&
                  (included.isEmpty ||
                      (includedCount != null &&
                          includedCount > 0 &&
                          includedCount <= 1000)) &&
                  (extra.isEmpty ||
                      (extraFee != null &&
                          extraFee.isFinite &&
                          extraFee > 0 &&
                          extraFee <= 99999999.99 &&
                          includedCount != null &&
                          includedCount > 0));
            });
      }
      if (type == 'Fitness & Wellness') {
        final names = fitnessCategories
            .map((item) => item.category.text.trim().toLowerCase())
            .toList();
        final categoriesReady =
            fitnessCategories.isNotEmpty &&
            names.every((name) => name.isNotEmpty) &&
            names.toSet().length == names.length &&
            fitnessCategories.every((item) {
              if (!positiveAmount(item.sessionPrice.text) ||
                  !positiveAmount(item.monthlyPrice.text) ||
                  !positiveAmount(item.yearlyPrice.text)) {
                return false;
              }
              final discountValue = item.yearlyDiscountValue.text.trim();
              if (item.yearlyDiscountType == 'none') {
                return discountValue.isEmpty;
              }
              final discount = double.tryParse(discountValue);
              if (discount == null || !discount.isFinite || discount <= 0) {
                return false;
              }
              return item.yearlyDiscountType == 'freeMonths'
                  ? discount <= 11 && discount == discount.roundToDouble()
                  : item.yearlyDiscountType == 'percentage' && discount <= 100;
            });
        final coachesReady = fitnessCoaches.every((coach) {
          final coachName = coach.name.text.trim();
          return coachName.isNotEmpty &&
              positiveAmount(coach.monthlyPrice.text) &&
              (coach.profileImageUrl?.length ?? 0) <= 400000;
        });
        return categoriesReady && coachesReady;
      }
      if (type == 'Event') {
        final minimum = int.tryParse(eventAttendanceMin.text.trim());
        final maximum = int.tryParse(eventAttendanceMax.text.trim());
        return positiveAmount(price.text) &&
            eventTypes.isNotEmpty &&
            (category != 'Other' || categoryOther.text.trim().isNotEmpty) &&
            (!eventTypes.contains('Other') ||
                eventTypeOther.text.trim().isNotEmpty) &&
            minimum != null &&
            maximum != null &&
            minimum > 0 &&
            maximum >= minimum;
      }
      return positiveAmount(price.text) &&
          (category != 'Other' || categoryOther.text.trim().isNotEmpty);
    }

    void scrollToContext(BuildContext? target) {
      if (target == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (panelOpen && target.mounted) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
            alignment: .15,
          );
        }
      });
    }

    void scrollToFirstInvalidField() {
      final formContext = formKey.currentContext;
      if (formContext == null) return;
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
      scrollToContext(firstInvalidContext);
    }

    void scrollToKey(GlobalKey key) => scrollToContext(key.currentContext);

    Widget inlineRequiredError(String message) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppText(
          message,
          localize: true,
          style: TextStyle(
            color: AppColors.errorText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    Widget setupShortcut({
      required String title,
      required String key,
      required IconData icon,
      required GlobalKey target,
    }) => ActionChip(
      key: ValueKey('business-setup-step-$key'),
      avatar: Icon(icon, size: 16),
      label: AppText(title, localize: true),
      onPressed: () => scrollToKey(target),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final added = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: editing
          ? 'Close edit business panel'
          : 'Close add business panel',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => _MerchantBusinessFormPanel(
        builder: (context, setDialogState) => PopScope<bool>(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) panelOpen = false;
          },
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: MediaQuery.sizeOf(context).width < 600 ? .94 : .52,
                heightFactor: 1,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 12, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  editing
                                      ? Icons.edit_outlined
                                      : Icons.add_business_rounded,
                                  color: _addOrange,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: AppText(
                                    editing ? 'Edit business' : 'Add business',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: appLanguageText('Close', 'Close'),
                                  onPressed: () {
                                    panelOpen = false;
                                    Navigator.pop(dialogContext, false);
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            AppText(
                              editing
                                  ? 'Update this venue for customers'
                                  : 'Publish a new venue for customers',
                              style: TextStyle(
                                color: _addMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              visualDensity: VisualDensity.compact,
                              textSelectionTheme: TextSelectionThemeData(
                                cursorColor: AppColors.accent,
                                selectionColor: AppColors.softOrange,
                                selectionHandleColor: AppColors.accent,
                              ),
                              textTheme: Theme.of(context).textTheme.copyWith(
                                bodyLarge: TextStyle(
                                  color: _addInk,
                                  fontSize: 14,
                                ),
                                bodyMedium: TextStyle(
                                  color: _addInk,
                                  fontSize: 13,
                                ),
                                bodySmall: TextStyle(
                                  color: _addMuted,
                                  fontSize: 11,
                                ),
                              ),
                              inputDecorationTheme: InputDecorationTheme(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                labelStyle: TextStyle(
                                  color: _addMuted,
                                  fontSize: 13,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: _addInk,
                                  fontSize: 13,
                                ),
                                hintStyle: TextStyle(
                                  color: _addMuted,
                                  fontSize: 12,
                                ),
                                helperStyle: TextStyle(fontSize: 11),
                                errorStyle: TextStyle(fontSize: 11),
                                prefixStyle: TextStyle(
                                  color: _addInk,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            child: SingleChildScrollView(
                              key: const ValueKey('business-setup-scroll'),
                              child: Form(
                                key: formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (validationMessage != null) ...[
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorSurface,
                                          border: Border.all(
                                            color: AppColors.errorBorder,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.error_outline_rounded,
                                              color: AppColors.errorText,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: AppText(
                                                validationMessage!,
                                                style: TextStyle(
                                                  color: AppColors.errorText,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: appLanguageText(
                                                'Dismiss validation message',
                                                'Dismiss validation message',
                                              ),
                                              onPressed: () => setDialogState(
                                                () => validationMessage = null,
                                              ),
                                              icon: Icon(
                                                Icons.close,
                                                color: AppColors.errorText,
                                                size: 18,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.softOrange.withValues(
                                          alpha: 0.18,
                                        ),
                                        border: Border.all(
                                          color: AppColors.softOrange,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 16,
                                            color: _addOrange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: AppText(
                                              'Use this to describe the venue, set how it is booked, and share opening hours so customers can understand it quickly.',
                                              style: TextStyle(
                                                color: _addInk,
                                                fontSize: 11,
                                                height: 1.35,
                                              ),
                                              localize: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    KeyedSubtree(
                                      key: businessBasicsKey,
                                      child: _sectionLabel('BUSINESS BASICS'),
                                    ),
                                    Container(
                                      key: const ValueKey(
                                        'business-setup-section-guide',
                                      ),
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        border: Border.all(color: _addLine),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const AppText(
                                            'Setup sections',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                            localize: true,
                                          ),
                                          const AppText(
                                            'Use these shortcuts to move through the form. Publish checks required fields and scrolls to the first item to fix.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.35,
                                            ),
                                            localize: true,
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 0,
                                            children: [
                                              setupShortcut(
                                                title: 'Basics',
                                                key: 'basics',
                                                icon: Icons.storefront_outlined,
                                                target: businessBasicsKey,
                                              ),
                                              setupShortcut(
                                                title: 'Booking details',
                                                key: 'booking-details',
                                                icon: Icons
                                                    .event_available_outlined,
                                                target: switch (type) {
                                                  'Sports' => sportsSectionKey,
                                                  'Event' => eventSectionKey,
                                                  _ => fitnessSectionKey,
                                                },
                                              ),
                                              setupShortcut(
                                                title: 'Hours & location',
                                                key: 'schedule',
                                                icon: Icons.schedule_rounded,
                                                target: scheduleSectionKey,
                                              ),
                                              setupShortcut(
                                                title: 'Venue photos',
                                                key: 'photos',
                                                icon: Icons
                                                    .photo_library_outlined,
                                                target: imageInputKey,
                                              ),
                                              setupShortcut(
                                                title: 'Review',
                                                key: 'review',
                                                icon: Icons.fact_check_outlined,
                                                target: reviewSectionKey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: type,
                                      decoration: InputDecoration(
                                        labelText: appLanguageText(
                                          'Booking type',
                                          'Booking type',
                                        ),
                                      ),
                                      items: [
                                        for (final item in types)
                                          DropdownMenuItem(
                                            value: item,
                                            child: AppText(item),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setDialogState(() {
                                          type = value;
                                          category = MerchantAddPageState
                                              ._categories[type]!
                                              .first;
                                        });
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 2,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          type == 'Sports'
                                              ? 'This is for a sport, court, or facility customers can book.'
                                              : type == 'Event'
                                              ? 'This is for an event venue or gathering space customers can reserve.'
                                              : 'This is for a fitness class, session, or wellness service customers can book.',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (type != 'Sports' &&
                                        type != 'Fitness & Wellness')
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: category,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Category / activity',
                                            'Category / activity',
                                          ),
                                        ),
                                        items: [
                                          for (final item in {
                                            ...MerchantAddPageState
                                                ._categories[type]!,
                                            'Other',
                                          })
                                            DropdownMenuItem(
                                              value: item,
                                              child: AppText(item),
                                            ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setDialogState(
                                              () => category = value,
                                            );
                                          }
                                        },
                                      ),
                                    if (type != 'Sports' &&
                                        type != 'Fitness & Wellness' &&
                                        category == 'Other')
                                      TextFormField(
                                        key: categoryOtherKey,
                                        controller: categoryOther,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Custom category (required)',
                                            'Custom category (required)',
                                          ),
                                          hintText: appLanguageText(
                                            'Enter the venue category',
                                            'Enter the venue category',
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Please enter a custom venue category.'
                                            : null,
                                      ),
                                    TextFormField(
                                      key: venueNameKey,
                                      controller: name,
                                      decoration: InputDecoration(
                                        labelText: appLanguageText(
                                          'Venue name (required)',
                                          'Venue name (required)',
                                        ),
                                      ),
                                      onChanged: (_) => setDialogState(() {
                                        locationManuallySelected = false;
                                      }),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Please enter the name customers will see for this venue.'
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: AppText(
                                        'Business logo / brand mark (optional)',
                                        style: TextStyle(
                                          color: _addInk,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: AppText(
                                        'This brand mark is separate from the venue photos.',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: SizedBox(
                                            width: 68,
                                            height: 68,
                                            child:
                                                businessLogoUrl == null ||
                                                    businessLogoUrl!
                                                        .trim()
                                                        .isEmpty
                                                ? ColoredBox(
                                                    color: AppColors
                                                        .surfaceVariant,
                                                    child: Icon(
                                                      Icons.storefront_rounded,
                                                      color: _addMuted,
                                                    ),
                                                  )
                                                : Image(
                                                    image:
                                                        _safeImageProvider(
                                                          businessLogoUrl!,
                                                        ) ??
                                                        const AssetImage(
                                                          'assets/court/pickle-court.jpg',
                                                        ),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        ColoredBox(
                                                          color: AppColors
                                                              .surfaceVariant,
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            color: _addMuted,
                                                          ),
                                                        ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              OutlinedButton.icon(
                                                key: const ValueKey(
                                                  'merchant-business-logo-picker',
                                                ),
                                                onPressed: () async {
                                                  try {
                                                    final file =
                                                        await ImagePicker()
                                                            .pickImage(
                                                              source:
                                                                  ImageSource
                                                                      .gallery,
                                                              maxWidth: 800,
                                                              maxHeight: 800,
                                                              imageQuality: 80,
                                                            );
                                                    if (file == null) return;
                                                    final selectedLogo =
                                                        _dataUri(
                                                          await file
                                                              .readAsBytes(),
                                                        );
                                                    if (panelOpen &&
                                                        context.mounted) {
                                                      setDialogState(
                                                        () => businessLogoUrl =
                                                            selectedLogo,
                                                      );
                                                    }
                                                  } on Exception catch (error) {
                                                    if (panelOpen &&
                                                        context.mounted) {
                                                      setDialogState(
                                                        () => validationMessage =
                                                            'Could not load the selected logo: $error',
                                                      );
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                ),
                                                label: AppText(
                                                  businessLogoUrl == null ||
                                                          businessLogoUrl!
                                                              .trim()
                                                              .isEmpty
                                                      ? 'Add logo'
                                                      : 'Change logo',
                                                ),
                                              ),
                                              if (businessLogoUrl != null &&
                                                  businessLogoUrl!
                                                      .trim()
                                                      .isNotEmpty)
                                                TextButton(
                                                  onPressed: () =>
                                                      setDialogState(
                                                        () => businessLogoUrl =
                                                            null,
                                                      ),
                                                  child: const AppText(
                                                    'Remove',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (type == 'Sports') ...[
                                      SwitchListTile(
                                        key: const ValueKey(
                                          'merchant-allow-matchmaking',
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                        title: const AppText(
                                          'Allow Player Matchmaking',
                                          localize: true,
                                        ),
                                        subtitle: const AppText(
                                          'Let customers host public games and find teammates at this venue.',
                                          localize: true,
                                        ),
                                        value: allowMatchmaking,
                                        onChanged: (value) => setDialogState(
                                          () => allowMatchmaking = value,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      KeyedSubtree(
                                        key: sportsSectionKey,
                                        child: _sectionLabel(
                                          'SPORTS, SLOTS & RATES',
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          'Use this to set how many booking slots this venue has. Choose whole-court or split small slots for each sport.',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                          localize: true,
                                        ),
                                      ),
                                      TextFormField(
                                        controller: totalSlots,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Total venue slots (required)',
                                            'Total venue slots (required)',
                                          ),
                                          hintText: 'e.g. 5',
                                        ),
                                        validator: (value) {
                                          final count = int.tryParse(
                                            value?.trim() ?? '',
                                          );
                                          return count == null ||
                                                  count < 1 ||
                                                  count > 100
                                              ? 'Enter a number of slots from 1 to 100.'
                                              : null;
                                        },
                                        onChanged: (value) {
                                          final count = int.tryParse(value);
                                          if (count == null ||
                                              count < 1 ||
                                              count > 100) {
                                            return;
                                          }
                                          setDialogState(() {
                                            for (final sport in sportSlots) {
                                              if (sport.fullStudio) {
                                                sport.slotCount = count;
                                              } else if (sport.slotCount >
                                                  count) {
                                                sport.slotCount = count;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        key: sportsSelectionKey,
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          'Choose at least one sport. Each selected sport needs its own rate and slot setup.',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                          localize: true,
                                        ),
                                      ),
                                      for (final sportType
                                          in <String>{
                                            ...MerchantAddPageState
                                                ._categories['Sports']!,
                                            ...sportSlots.map(
                                              (sport) => sport.sportType.text,
                                            ),
                                          }.toList()..sort(
                                            (left, right) =>
                                                left.compareTo(right),
                                          ))
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: AppText(sportType),
                                          value: sportSlots.any(
                                            (sport) =>
                                                sport.sportType.text ==
                                                sportType,
                                          ),
                                          onChanged: (checked) {
                                            setDialogState(() {
                                              if (checked == true) {
                                                final usesWholeStudio = !const {
                                                  'Badminton',
                                                  'Tennis',
                                                  'Pickleball',
                                                  'Table Tennis',
                                                  'Squash',
                                                }.contains(sportType);
                                                sportSlots.add(
                                                  _SportSlotInput(
                                                    sportType: sportType,
                                                    pricePerHour: '',
                                                    fullStudio: usesWholeStudio,
                                                    slotCount: usesWholeStudio
                                                        ? (int.tryParse(
                                                                totalSlots.text,
                                                              ) ??
                                                              1)
                                                        : (int.tryParse(
                                                                totalSlots.text,
                                                              ) ??
                                                              1),
                                                    includedPlayers: '',
                                                    additionalPlayerFee: '',
                                                  ),
                                                );
                                              } else {
                                                sportSlots.removeWhere((sport) {
                                                  if (sport.sportType.text !=
                                                      sportType) {
                                                    return false;
                                                  }
                                                  sport.dispose();
                                                  return true;
                                                });
                                              }
                                            });
                                          },
                                        ),
                                      TextFormField(
                                        key: categoryOtherKey,
                                        controller: categoryOther,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Other sport (optional)',
                                            'Other sport (optional)',
                                          ),
                                          hintText: 'e.g. Squash',
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            final customSport = categoryOther
                                                .text
                                                .trim();
                                            if (customSport.isEmpty) return;
                                            if (sportSlots.any(
                                              (sport) =>
                                                  sport.sportType.text
                                                      .toLowerCase() ==
                                                  customSport.toLowerCase(),
                                            )) {
                                              setDialogState(
                                                () => validationMessage = 'That sport is already selected.',
                                              );
                                              return;
                                            }
                                            setDialogState(() {
                                              validationMessage = null;
                                              sportSlots.add(
                                                _SportSlotInput(
                                                  sportType: customSport,
                                                  pricePerHour: '',
                                                  fullStudio: true,
                                                  slotCount:
                                                      int.tryParse(
                                                        totalSlots.text,
                                                      ) ??
                                                      1,
                                                  includedPlayers: '',
                                                  additionalPlayerFee: '',
                                                ),
                                              );
                                              categoryOther.clear();
                                            });
                                          },
                                          icon: const Icon(Icons.add_rounded),
                                          label: const AppText(
                                            'Add other sport',
                                            localize: true,
                                          ),
                                        ),
                                      ),
                                      if (sportSlots.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: AppText(
                                              'Chosen categories: ${sportSlots.map((sport) => sport.sportType.text).join(', ')}',
                                              style: TextStyle(
                                                color: _addInk,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              localize: true,
                                            ),
                                          ),
                                        ),
                                      for (
                                        var index = 0;
                                        index < sportSlots.length;
                                        index++
                                      ) ...[
                                        const SizedBox(height: 6),
                                        Builder(
                                          builder: (context) {
                                            final sport = sportSlots[index];
                                            final capacity =
                                                int.tryParse(totalSlots.text) ??
                                                1;
                                            return Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant,
                                                border: Border.all(
                                                  color: AppColors.border,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: AppText(
                                                          sport.sportType.text,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  TextFormField(
                                                    controller:
                                                        sport.pricePerHour,
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          appLanguageText(
                                                            'Price per hour (required)',
                                                            'Price per hour (required)',
                                                          ),
                                                      prefixText: '₱ ',
                                                    ),
                                                    validator: (value) {
                                                      final amount =
                                                          double.tryParse(
                                                            value?.trim() ?? '',
                                                          );
                                                      return amount == null ||
                                                              amount <= 0
                                                          ? 'Enter a price greater than ₱0.'
                                                          : null;
                                                    },
                                                  ),
                                                  DropdownButtonFormField<bool>(
                                                    isExpanded: true,
                                                    initialValue:
                                                        sport.fullStudio,
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          appLanguageText(
                                                            'Space used by this sport',
                                                            'Space used by this sport',
                                                          ),
                                                    ),
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value: true,
                                                        child: AppText(
                                                          'Whole venue / full court',
                                                          localize: true,
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: false,
                                                        child: AppText(
                                                          'Split into small slots',
                                                          localize: true,
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (value) {
                                                      if (value == null) return;
                                                      setDialogState(() {
                                                        sport.fullStudio =
                                                            value;
                                                        sport.slotCount = value
                                                            ? capacity
                                                            : 1;
                                                      });
                                                    },
                                                  ),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 12,
                                                            top: 2,
                                                          ),
                                                      child: AppText(
                                                        sport.fullStudio
                                                            ? 'One booking blocks all small slots.'
                                                            : 'Customers book one available small slot.',
                                                        style: TextStyle(
                                                          color: _addMuted,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (!sport.fullStudio)
                                                    DropdownButtonFormField<
                                                      int
                                                    >(
                                                      initialValue: sport
                                                          .slotCount
                                                          .clamp(1, capacity)
                                                          .toInt(),
                                                      decoration:
                                                          InputDecoration(
                                                            labelText:
                                                                appLanguageText(
                                                                  'Number of small slots',
                                                                  'Number of small slots',
                                                                ),
                                                          ),
                                                      items: [
                                                        for (
                                                          var slot = 1;
                                                          slot <= capacity;
                                                          slot++
                                                        )
                                                          DropdownMenuItem(
                                                            value: slot,
                                                            child: AppText(
                                                              '$slot slot${slot == 1 ? '' : 's'}',
                                                              localize: true,
                                                            ),
                                                          ),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          setDialogState(
                                                            () =>
                                                                sport.slotCount =
                                                                    value,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  const SizedBox(height: 6),
                                                  Builder(
                                                    builder: (context) {
                                                      final includedPlayersField =
                                                          TextFormField(
                                                            controller: sport
                                                                .includedPlayers,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            decoration:
                                                                InputDecoration(
                                                                  labelText:
                                                                      appLanguageText(
                                                                        'Included players (optional)',
                                                                        'Included players (optional)',
                                                                      ),
                                                                ),
                                                            validator: (value) {
                                                              final raw =
                                                                  value
                                                                      ?.trim() ??
                                                                  '';
                                                              if (raw.isEmpty) {
                                                                return null;
                                                              }
                                                              final count =
                                                                  int.tryParse(
                                                                    raw,
                                                                  );
                                                              return count ==
                                                                          null ||
                                                                      count <
                                                                          1 ||
                                                                      count >
                                                                          1000
                                                                  ? 'Enter a whole number from 1 to 1,000.'
                                                                  : null;
                                                            },
                                                          );
                                                      final extraPlayerFeeField = TextFormField(
                                                        controller: sport
                                                            .additionalPlayerFee,
                                                        keyboardType:
                                                            const TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                        decoration:
                                                            InputDecoration(
                                                              labelText:
                                                                  appLanguageText(
                                                                    'Fee / extra player (optional)',
                                                                    'Fee / extra player (optional)',
                                                                  ),
                                                              prefixText: '₱ ',
                                                            ),
                                                        validator: (value) {
                                                          final raw =
                                                              value?.trim() ??
                                                              '';
                                                          if (raw.isEmpty) {
                                                            return null;
                                                          }
                                                          final fee =
                                                              double.tryParse(
                                                                raw,
                                                              );
                                                          return fee == null ||
                                                                  !fee.isFinite ||
                                                                  fee <= 0 ||
                                                                  fee >
                                                                      99999999.99
                                                              ? 'Enter a fee greater than ₱0.'
                                                              : null;
                                                        },
                                                      );
                                                      if (MediaQuery.sizeOf(
                                                            context,
                                                          ).width <
                                                          440) {
                                                        return Column(
                                                          children: [
                                                            includedPlayersField,
                                                            const SizedBox(
                                                              height: 6,
                                                            ),
                                                            extraPlayerFeeField,
                                                          ],
                                                        );
                                                      }
                                                      return Row(
                                                        children: [
                                                          Expanded(
                                                            child:
                                                                includedPlayersField,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Expanded(
                                                            child:
                                                                extraPlayerFeeField,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                    if (type == 'Fitness & Wellness') ...[
                                      const SizedBox(height: 6),
                                      KeyedSubtree(
                                        key: fitnessSectionKey,
                                        child: _sectionLabel(
                                          'FITNESS CATEGORIES & PRICES',
                                        ),
                                      ),
                                      Align(
                                        key: fitnessCategoriesKey,
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          'Choose at least one activity (up to 20), then set its session, monthly, and yearly prices. Yearly offers may include an optional discount.',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                          localize: true,
                                        ),
                                      ),
                                      for (final fitnessCategory
                                          in <String>{
                                            ...MerchantAddPageState
                                                ._categories['Fitness & Wellness']!,
                                            ...fitnessCategories.map(
                                              (item) => item.category.text,
                                            ),
                                          }.toList()..sort(
                                            (left, right) =>
                                                left.compareTo(right),
                                          ))
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: AppText(fitnessCategory),
                                          value: fitnessCategories.any(
                                            (item) =>
                                                item.category.text
                                                    .toLowerCase() ==
                                                fitnessCategory.toLowerCase(),
                                          ),
                                          onChanged:
                                              !fitnessCategories.any(
                                                    (item) =>
                                                        item.category.text
                                                            .toLowerCase() ==
                                                        fitnessCategory
                                                            .toLowerCase(),
                                                  ) &&
                                                  fitnessCategories.length >= 20
                                              ? null
                                              : (checked) {
                                                  setDialogState(() {
                                                    if (checked == true) {
                                                      fitnessCategories.add(
                                                        MerchantFitnessCategoryInput(
                                                          category:
                                                              fitnessCategory,
                                                        ),
                                                      );
                                                    } else {
                                                      fitnessCategories.removeWhere((
                                                        item,
                                                      ) {
                                                        if (item.category.text
                                                                .toLowerCase() !=
                                                            fitnessCategory
                                                                .toLowerCase()) {
                                                          return false;
                                                        }
                                                        item.dispose();
                                                        return true;
                                                      });
                                                    }
                                                  });
                                                },
                                        ),
                                      TextField(
                                        key: categoryOtherKey,
                                        controller: categoryOther,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Other fitness category',
                                            'Other fitness category',
                                          ),
                                          hintText: 'e.g. Strength training',
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed:
                                              fitnessCategories.length >= 20
                                              ? null
                                              : () {
                                                  final custom = categoryOther
                                                      .text
                                                      .trim();
                                                  if (custom.isEmpty) return;
                                                  if (fitnessCategories.any(
                                                    (item) =>
                                                        item.category.text
                                                            .toLowerCase() ==
                                                        custom.toLowerCase(),
                                                  )) {
                                                    setDialogState(
                                                      () => validationMessage = 'That fitness category is already selected.',
                                                    );
                                                    return;
                                                  }
                                                  setDialogState(() {
                                                    fitnessCategories.add(
                                                      MerchantFitnessCategoryInput(
                                                        category: custom,
                                                      ),
                                                    );
                                                    categoryOther.clear();
                                                    validationMessage = null;
                                                  });
                                                },
                                          icon: const Icon(Icons.add_rounded),
                                          label: const AppText(
                                            'Add other category',
                                            localize: true,
                                          ),
                                        ),
                                      ),
                                      if (fitnessCategories.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: AppText(
                                              'Chosen categories: ${fitnessCategories.map((item) => item.category.text).join(', ')}',
                                              style: TextStyle(
                                                color: _addInk,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              localize: true,
                                            ),
                                          ),
                                        ),
                                      for (
                                        var index = 0;
                                        index < fitnessCategories.length;
                                        index++
                                      ) ...[
                                        const SizedBox(height: 6),
                                        _fitnessCategoryCard(
                                          fitnessCategories[index],
                                          onDiscountChanged: (value) =>
                                              setDialogState(() {
                                                fitnessCategories[index]
                                                        .yearlyDiscountType =
                                                    value;
                                                if (value == 'none') {
                                                  fitnessCategories[index]
                                                      .yearlyDiscountValue
                                                      .clear();
                                                }
                                              }),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      KeyedSubtree(
                                        key: fitnessCoachesKey,
                                        child: _sectionLabel(
                                          'COACH STAFF (OPTIONAL)',
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          'Add up to 20 coaches with optional profile photos and individual monthly prices.',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                          localize: true,
                                        ),
                                      ),
                                      for (
                                        var index = 0;
                                        index < fitnessCoaches.length;
                                        index++
                                      ) ...[
                                        const SizedBox(height: 6),
                                        _fitnessCoachCard(
                                          fitnessCoaches[index],
                                          onPickImage: () async {
                                            try {
                                              final picked = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 600,
                                                    maxHeight: 600,
                                                    imageQuality: 55,
                                                  );
                                              if (picked == null) return;
                                              final image = _dataUri(
                                                await picked.readAsBytes(),
                                              );
                                              if (panelOpen &&
                                                  context.mounted) {
                                                setDialogState(
                                                  () =>
                                                      fitnessCoaches[index]
                                                              .profileImageUrl =
                                                          image,
                                                );
                                              }
                                            } on Exception catch (error) {
                                              if (panelOpen &&
                                                  context.mounted) {
                                                setDialogState(
                                                  () => validationMessage =
                                                      'Could not load the coach profile image: $error',
                                                );
                                              }
                                            }
                                          },
                                          onRemove: () {
                                            final coach = fitnessCoaches
                                                .removeAt(index);
                                            coach.dispose();
                                            setDialogState(() {});
                                          },
                                        ),
                                      ],
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: fitnessCoaches.length >= 20
                                              ? null
                                              : () => setDialogState(
                                                  () => fitnessCoaches.add(
                                                    MerchantFitnessCoachInput(),
                                                  ),
                                                ),
                                          icon: const Icon(
                                            Icons.person_add_alt_1,
                                          ),
                                          label: const AppText(
                                            'Add coach',
                                            localize: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (type == 'Event') ...[
                                      const SizedBox(height: 6),
                                      KeyedSubtree(
                                        key: eventSectionKey,
                                        child: _sectionLabel(
                                          'EVENT BOOKING DETAILS',
                                        ),
                                      ),
                                      Align(
                                        key: eventTypesKey,
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          'Event types this venue can hold (required)',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                          localize: true,
                                        ),
                                      ),
                                      KeyedSubtree(
                                        key: eventAttendanceKey,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            for (final option
                                                in eventTypeOptions)
                                              FilterChip(
                                                label: AppText(
                                                  option,
                                                  style: TextStyle(
                                                    color:
                                                        eventTypes.contains(
                                                          option,
                                                        )
                                                        ? _addOrange
                                                        : _addInk,
                                                    fontWeight:
                                                        eventTypes.contains(
                                                          option,
                                                        )
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                  ),
                                                ),
                                                selected: eventTypes.contains(
                                                  option,
                                                ),
                                                showCheckmark: false,
                                                selectedColor: _addSoftOrange,
                                                backgroundColor:
                                                    AppColors.surface,
                                                shape: const StadiumBorder(),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                checkmarkColor: _addOrange,
                                                side: BorderSide(
                                                  color:
                                                      eventTypes.contains(
                                                        option,
                                                      )
                                                      ? _addOrange
                                                      : _addLine,
                                                ),
                                                onSelected: (selected) =>
                                                    setDialogState(() {
                                                      if (selected) {
                                                        eventTypes.add(option);
                                                      } else {
                                                        eventTypes.remove(
                                                          option,
                                                        );
                                                        if (option == 'Other') {
                                                          eventTypeOther
                                                              .clear();
                                                        }
                                                      }
                                                    }),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (eventTypes.contains('Other'))
                                        TextFormField(
                                          controller: eventTypeOther,
                                          decoration: InputDecoration(
                                            labelText: appLanguageText(
                                              'Other event type',
                                              'Other event type',
                                            ),
                                            hintText: appLanguageText(
                                              'Enter another event type',
                                              'Enter another event type',
                                            ),
                                          ),
                                          validator: (value) =>
                                              value == null ||
                                                  value.trim().isEmpty
                                              ? 'Enter the other event type.'
                                              : null,
                                        ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: eventAttendanceMin,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: appLanguageText(
                                                  'Minimum guests (required)',
                                                  'Minimum guests (required)',
                                                ),
                                                hintText: '40',
                                              ),
                                              validator: (value) {
                                                final minimum = int.tryParse(
                                                  value?.trim() ?? '',
                                                );
                                                return minimum == null ||
                                                        minimum < 1
                                                    ? 'Enter a minimum of at least 1 guest.'
                                                    : null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextFormField(
                                              controller: eventAttendanceMax,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: appLanguageText(
                                                  'Maximum guests (required)',
                                                  'Maximum guests (required)',
                                                ),
                                                hintText: '250',
                                              ),
                                              validator: (value) {
                                                final maximum = int.tryParse(
                                                  value?.trim() ?? '',
                                                );
                                                final minimum = int.tryParse(
                                                  eventAttendanceMin.text
                                                      .trim(),
                                                );
                                                return maximum == null ||
                                                        minimum == null ||
                                                        maximum < minimum
                                                    ? 'Enter a maximum equal to or above the minimum.'
                                                    : null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      _repeatableEventNeeds(
                                        label: 'Accessibility needs (optional)',
                                        hint: 'Wheelchair ramp or specialized seating',
                                        controller: accessibilityInput,
                                        values: accessibilityNeeds,
                                        setDialogState: setDialogState,
                                      ),
                                      _repeatableEventNeeds(
                                        label: 'Parking needs (optional)',
                                        hint: 'Reserved parking or VIP parking',
                                        controller: parkingInput,
                                        values: parkingNeeds,
                                        setDialogState: setDialogState,
                                      ),
                                      _repeatableEventNeeds(
                                        label: 'Security needs (optional)',
                                        hint: 'Dedicated security personnel or VIP access',
                                        controller: securityInput,
                                        values: securityNeeds,
                                        setDialogState: setDialogState,
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    KeyedSubtree(
                                      key: scheduleSectionKey,
                                      child: _sectionLabel(
                                        'SCHEDULE AND PRICING',
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: KeyedSubtree(
                                            key: openingTimeKey,
                                            child: _timePickerField(
                                              context: context,
                                              label: 'Opens (required)',
                                              value: openingTime,
                                              onChanged: (value) =>
                                                  panelOpen && context.mounted
                                                  ? setDialogState(
                                                      () => openingTime = value,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: KeyedSubtree(
                                            key: closingTimeKey,
                                            child: _timePickerField(
                                              context: context,
                                              label: 'Closes (required)',
                                              value: closingTime,
                                              onChanged: (value) =>
                                                  panelOpen && context.mounted
                                                  ? setDialogState(
                                                      () => closingTime = value,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (scheduleValidationAttempted &&
                                        openingTime == null)
                                      inlineRequiredError(
                                        'Choose an opening time.',
                                      ),
                                    if (scheduleValidationAttempted &&
                                        closingTime == null)
                                      inlineRequiredError(
                                        'Choose a closing time.',
                                      ),
                                    TextFormField(
                                      controller: address,
                                      key: addressKey,
                                      decoration: InputDecoration(
                                        labelText: appLanguageText(
                                          'Venue address (required)',
                                          'Venue address (required)',
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        labelStyle: TextStyle(fontSize: 13),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onChanged: (_) => setDialogState(() {}),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Please add the venue’s street address and city.'
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final location =
                                                  await _chooseBusinessLocation(
                                                    latitude: latitude,
                                                    longitude: longitude,
                                                    address: address.text,
                                                  );
                                              if (location != null &&
                                                  panelOpen) {
                                                setDialogState(() {
                                                  latitude = location.latitude;
                                                  longitude =
                                                      location.longitude;
                                                  locationManuallySelected =
                                                      true;
                                                });
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.location_on_outlined,
                                              size: 18,
                                            ),
                                            label: AppText(
                                              latitude == null ||
                                                      longitude == null
                                                  ? 'Preview / adjust map pin'
                                                  : 'Adjust map pin',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: AppSpacing.buttonPadding,
                                              minimumSize: const Size(0, 34),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              textStyle: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          if (latitude != null &&
                                              longitude != null)
                                            TextButton(
                                              onPressed: () =>
                                                  setDialogState(() {
                                                    latitude = null;
                                                    longitude = null;
                                                  }),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    AppSpacing.buttonPadding,
                                                minimumSize: const Size(0, 30),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              child: const AppText(
                                                'Clear pin',
                                                localize: true,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: AppText(
                                          latitude == null || longitude == null
                                              ? 'We’ll pin the map from this address when you publish. You can adjust it here.'
                                              : 'Pinned at ${latitude!.toStringAsFixed(5)}, '
                                                    '${longitude!.toStringAsFixed(5)}',
                                          style: TextStyle(
                                            color: _addMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: visitUrl,
                                      keyboardType: TextInputType.url,
                                      decoration: InputDecoration(
                                        labelText: appLanguageText(
                                          'Visit link (optional)',
                                          'Visit link (optional)',
                                        ),
                                        hintText: 'https://example.com',
                                        helperText: appLanguageText(
                                          'Customers open this link from Visit.',
                                          'Customers open this link from Visit.',
                                        ),
                                      ),
                                      validator: (value) {
                                        final text = value?.trim() ?? '';
                                        if (text.isEmpty) return null;
                                        final uri = Uri.tryParse(text);
                                        if (uri == null ||
                                            !uri.hasScheme ||
                                            (uri.scheme != 'http' &&
                                                uri.scheme != 'https') ||
                                            uri.host.isEmpty) {
                                          return 'Enter a full web address beginning with http:// or https://.';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (type == 'Event')
                                      TextFormField(
                                        controller: price,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Fee per event booking (required)',
                                            'Fee per event booking (required)',
                                          ),
                                          prefixText: '₱ ',
                                          hintText:
                                              '25000 (one complete event)',
                                        ),
                                        validator: (value) {
                                          final amount = double.tryParse(
                                            value?.trim() ?? '',
                                          );
                                          return amount == null || amount <= 0
                                              ? 'Enter an event fee greater than ₱0.'
                                              : null;
                                        },
                                      ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            color: _addInk,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: AppText(
                                              'Availability / booking schedule',
                                              style: TextStyle(
                                                color: _addMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              localize: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      key: availableDaysKey,
                                      alignment: Alignment.centerLeft,
                                      child: AppText(
                                        'Available days (required · choose at least one)',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        localize: true,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final day in _weekdays)
                                            FilterChip(
                                              label: AppText(
                                                day,
                                                style: TextStyle(
                                                  color:
                                                      availableDays.contains(
                                                        day,
                                                      )
                                                      ? _addOrange
                                                      : _addInk,
                                                  fontWeight:
                                                      availableDays.contains(
                                                        day,
                                                      )
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                              selected: availableDays.contains(
                                                day,
                                              ),
                                              showCheckmark: false,
                                              selectedColor: _addSoftOrange,
                                              backgroundColor:
                                                  AppColors.surface,
                                              shape: const StadiumBorder(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              checkmarkColor: _addOrange,
                                              side: BorderSide(
                                                color:
                                                    availableDays.contains(day)
                                                    ? _addOrange
                                                    : _addLine,
                                              ),
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    availableDays.add(day);
                                                  } else {
                                                    availableDays.remove(day);
                                                  }
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (scheduleValidationAttempted &&
                                        availableDays.isEmpty)
                                      inlineRequiredError(
                                        'Choose at least one available day.',
                                      ),
                                    const SizedBox(height: 6),
                                    _sectionLabel('FACILITY DETAILS'),
                                    DropdownButtonFormField<String>(
                                      initialValue: facility,
                                      decoration: InputDecoration(
                                        labelText: type == 'Sports'
                                            ? 'Court / field type'
                                            : type == 'Event'
                                            ? 'Event space type'
                                            : 'Studio / wellness space type',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Indoor',
                                          child: AppText(
                                            'Indoor',
                                            localize: true,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Outdoor',
                                          child: AppText(
                                            'Outdoor',
                                            localize: true,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Covered',
                                          child: AppText(
                                            'Covered',
                                            localize: true,
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(
                                            () => facility = value,
                                          );
                                        }
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: _sectionLabel(
                                        'AMENITIES (OPTIONAL)',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final amenity in amenityOptions)
                                            FilterChip(
                                              label: AppText(
                                                amenity,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      amenities.contains(
                                                        amenity,
                                                      )
                                                      ? _addOrange
                                                      : _addInk,
                                                  fontWeight:
                                                      amenities.contains(
                                                        amenity,
                                                      )
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                              selected: amenities.contains(
                                                amenity,
                                              ),
                                              showCheckmark: false,
                                              selectedColor: _addSoftOrange,
                                              backgroundColor:
                                                  AppColors.surface,
                                              shape: const StadiumBorder(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              checkmarkColor: _addOrange,
                                              side: BorderSide(
                                                color:
                                                    amenities.contains(amenity)
                                                    ? _addOrange
                                                    : _addLine,
                                              ),
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    amenities.add(amenity);
                                                  } else {
                                                    amenities.remove(amenity);
                                                    if (amenity == 'Other') {
                                                      amenityOther.clear();
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (amenities.contains('Other'))
                                      TextField(
                                        key: amenityOtherKey,
                                        controller: amenityOther,
                                        decoration: InputDecoration(
                                          labelText: appLanguageText(
                                            'Other amenity',
                                            'Other amenity',
                                          ),
                                          hintText: appLanguageText(
                                            'Example: Water station',
                                            'Example: Water station',
                                          ),
                                        ),
                                      ),
                                    TextField(
                                      controller: details,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        labelText: type == 'Sports'
                                            ? 'Court or facility details (optional)'
                                            : type == 'Event'
                                            ? 'Additional event venue details (optional)'
                                            : 'Classes, sessions & capacity',
                                        hintText: type == 'Event'
                                            ? 'Example: Banquet package • 250 guests'
                                            : type == 'Fitness & Wellness'
                                            ? 'Example: 12 classes today • 20 participants/session'
                                            : 'Example: 2 courts • Equipment included',
                                      ),
                                    ),
                                    TextButton.icon(
                                      key: imageInputKey,
                                      onPressed: () async {
                                        try {
                                          final picked = await ImagePicker()
                                              .pickMultiImage(
                                                maxWidth: 700,
                                                maxHeight: 500,
                                                imageQuality: 50,
                                              );
                                          if (picked.isEmpty) return;
                                          final selected = <String>[];
                                          for (final file in picked.take(3)) {
                                            selected.add(
                                              _dataUri(
                                                await file.readAsBytes(),
                                              ),
                                            );
                                          }
                                          if (panelOpen && context.mounted) {
                                            setDialogState(
                                              () => images
                                                ..clear()
                                                ..addAll(selected),
                                            );
                                          }
                                        } on Exception catch (error) {
                                          if (panelOpen && context.mounted) {
                                            setDialogState(
                                              () => validationMessage =
                                                  'Could not load the selected images: $error',
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.add_a_photo_outlined,
                                      ),
                                      label: AppText(
                                        images.isEmpty
                                            ? 'Add images'
                                            : '${images.length} images selected',
                                      ),
                                    ),
                                    if (images.isNotEmpty)
                                      SizedBox(
                                        height: 72,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (
                                              var index = 0;
                                              index < images.length;
                                              index++
                                            ) ...[
                                              Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Image(
                                                      image: _imageProvider(
                                                        images[index],
                                                      )!,
                                                      width: 72,
                                                      height: 72,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    left: 4,
                                                    bottom: 4,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black54,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 2,
                                                            ),
                                                        child: AppText(
                                                          '${index + 1} of ${images.length}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                          localize: true,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (index < images.length - 1)
                                                const SizedBox(width: 6),
                                            ],
                                          ],
                                        ),
                                      ),
                                    KeyedSubtree(
                                      key: reviewSectionKey,
                                      child: _businessReviewCard(
                                        name: name.text.trim(),
                                        type: type,
                                        category: type == 'Sports'
                                            ? sportSlots
                                                  .map(
                                                    (sport) =>
                                                        sport.sportType.text,
                                                  )
                                                  .where(
                                                    (value) => value.isNotEmpty,
                                                  )
                                                  .join(', ')
                                            : type == 'Fitness & Wellness'
                                            ? fitnessCategories
                                                  .map(
                                                    (item) =>
                                                        item.category.text,
                                                  )
                                                  .where(
                                                    (value) => value.isNotEmpty,
                                                  )
                                                  .join(', ')
                                            : category == 'Other'
                                            ? categoryOther.text.trim()
                                            : category,
                                        address: address.text.trim(),
                                        hours: _formatHours(
                                          openingTime,
                                          closingTime,
                                        ),
                                        availableDays: _weekdays
                                            .where(availableDays.contains)
                                            .join(', '),
                                        imageCount: images.length,
                                        complete:
                                            name.text.trim().isNotEmpty &&
                                            scheduleComplete() &&
                                            images.isNotEmpty &&
                                            bookingDetailsComplete(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton(
                              onPressed: () {
                                panelOpen = false;
                                Navigator.pop(dialogContext, false);
                              },
                              style: TextButton.styleFrom(
                                textStyle: const TextStyle(fontSize: 13),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: const AppText('Cancel', localize: true),
                            ),
                            FilledButton(
                              key: const ValueKey('business-setup-publish'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _addNavy,
                                foregroundColor:
                                    AppColors.contrastingForeground(_addNavy),
                                minimumSize: const Size(128, 36),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () async {
                                setDialogState(() {
                                  validationMessage = null;
                                  scheduleValidationAttempted = true;
                                });
                                if (name.text.trim().isEmpty) {
                                  setDialogState(() {
                                    validationMessage = 'Please enter a venue name before publishing.';
                                  });
                                  scrollToKey(venueNameKey);
                                  return;
                                }
                                if (images.isEmpty) {
                                  setDialogState(
                                    () => validationMessage = 'Add at least one venue image before publishing the Booking Card.',
                                  );
                                  scrollToKey(imageInputKey);
                                  return;
                                }
                                final fieldsValid =
                                    formKey.currentState?.validate() ?? false;
                                if (openingTime == null) {
                                  setDialogState(
                                    () => validationMessage =
                                        'Please choose an opening time.',
                                  );
                                  scrollToKey(openingTimeKey);
                                  return;
                                }
                                if (closingTime == null) {
                                  setDialogState(
                                    () => validationMessage =
                                        'Please choose a closing time.',
                                  );
                                  scrollToKey(closingTimeKey);
                                  return;
                                }
                                if (!fieldsValid) {
                                  scrollToFirstInvalidField();
                                  return;
                                }
                                if (availableDays.isEmpty) {
                                  setDialogState(
                                    () => validationMessage =
                                        'Choose at least one available day.',
                                  );
                                  scrollToKey(availableDaysKey);
                                  return;
                                }
                                if (type == 'Sports') {
                                  final capacity = int.tryParse(
                                    totalSlots.text.trim(),
                                  );
                                  final names = sportSlots
                                      .map(
                                        (sport) => sport.sportType.text
                                            .trim()
                                            .toLowerCase(),
                                      )
                                      .toList();
                                  final invalidSportConfig =
                                      capacity == null ||
                                      capacity < 1 ||
                                      capacity > 100 ||
                                      sportSlots.isEmpty ||
                                      names.any((name) => name.isEmpty) ||
                                      names.toSet().length != names.length ||
                                      sportSlots.any((sport) {
                                        final rate = double.tryParse(
                                          sport.pricePerHour.text.trim(),
                                        );
                                        final includedCount = int.tryParse(
                                          sport.includedPlayers.text.trim(),
                                        );
                                        final extraFee = double.tryParse(
                                          sport.additionalPlayerFee.text.trim(),
                                        );
                                        return rate == null ||
                                            rate <= 0 ||
                                            sport.slotCount < 1 ||
                                            sport.slotCount > capacity ||
                                            (sport.includedPlayers.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                (includedCount == null ||
                                                    includedCount < 1 ||
                                                    includedCount > 1000)) ||
                                            (sport.additionalPlayerFee.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                (extraFee == null ||
                                                    !extraFee.isFinite ||
                                                    extraFee <= 0 ||
                                                    extraFee > 99999999.99 ||
                                                    includedCount == null ||
                                                    includedCount < 1));
                                      });
                                  if (invalidSportConfig) {
                                    setDialogState(
                                      () => validationMessage = 'Please check each sport’s name and price, and make sure its slots fit within the studio capacity.',
                                    );
                                    scrollToKey(sportsSelectionKey);
                                    return;
                                  }
                                }
                                if (type == 'Fitness & Wellness') {
                                  final names = fitnessCategories
                                      .map(
                                        (item) => item.category.text
                                            .trim()
                                            .toLowerCase(),
                                      )
                                      .toList();
                                  final invalidCategory =
                                      fitnessCategories.isEmpty ||
                                      names.any((name) => name.isEmpty) ||
                                      names.toSet().length != names.length ||
                                      fitnessCategories.any((item) {
                                        final prices =
                                            [
                                              item.sessionPrice.text,
                                              item.monthlyPrice.text,
                                              item.yearlyPrice.text,
                                            ].map(
                                              (value) =>
                                                  double.tryParse(value.trim()),
                                            );
                                        if (prices.any(
                                          (value) =>
                                              value == null ||
                                              !value.isFinite ||
                                              value <= 0 ||
                                              value > 99999999.99,
                                        )) {
                                          return true;
                                        }
                                        final discountValue = item
                                            .yearlyDiscountValue
                                            .text
                                            .trim();
                                        if (item.yearlyDiscountType == 'none') {
                                          return discountValue.isNotEmpty;
                                        }
                                        final discount = double.tryParse(
                                          discountValue,
                                        );
                                        if (discount == null ||
                                            !discount.isFinite ||
                                            discount <= 0) {
                                          return true;
                                        }
                                        return item.yearlyDiscountType ==
                                                'freeMonths'
                                            ? discount > 11 ||
                                                  discount !=
                                                      discount.roundToDouble()
                                            : discount > 100;
                                      });
                                  if (invalidCategory) {
                                    setDialogState(
                                      () => validationMessage = 'Please choose at least one different fitness category and enter a price for each plan. Check any yearly discount as well.',
                                    );
                                    scrollToKey(fitnessCategoriesKey);
                                    return;
                                  }
                                  final coachNames = fitnessCoaches
                                      .map(
                                        (coach) => coach.name.text
                                            .trim()
                                            .toLowerCase(),
                                      )
                                      .toList();
                                  final invalidCoach =
                                      coachNames.any((name) => name.isEmpty) ||
                                      fitnessCoaches.any((coach) {
                                        final amount = double.tryParse(
                                          coach.monthlyPrice.text.trim(),
                                        );
                                        return amount == null ||
                                            !amount.isFinite ||
                                            amount <= 0 ||
                                            amount > 99999999.99 ||
                                            (coach.profileImageUrl?.length ??
                                                    0) >
                                                400000;
                                      });
                                  if (invalidCoach) {
                                    setDialogState(
                                      () => validationMessage = 'Please enter each coach’s name and a monthly price greater than ₱0.',
                                    );
                                    scrollToKey(fitnessCoachesKey);
                                    return;
                                  }
                                }
                                if (availableDays.isEmpty) {
                                  setDialogState(
                                    () => validationMessage = 'Please choose at least one day when your venue is open.',
                                  );
                                  scrollToKey(availableDaysKey);
                                  return;
                                }
                                if (type == 'Event') {
                                  final minimum = int.tryParse(
                                    eventAttendanceMin.text.trim(),
                                  );
                                  final maximum = int.tryParse(
                                    eventAttendanceMax.text.trim(),
                                  );
                                  if (eventTypes.isEmpty) {
                                    setDialogState(
                                      () => validationMessage = 'Please choose at least one type of event your venue can host.',
                                    );
                                    scrollToKey(eventTypesKey);
                                    return;
                                  }
                                  if (eventTypes.contains('Other') &&
                                      eventTypeOther.text.trim().isEmpty) {
                                    setDialogState(
                                      () => validationMessage =
                                          'Please enter the custom event type.',
                                    );
                                    scrollToKey(eventTypesKey);
                                    return;
                                  }
                                  if (minimum == null ||
                                      maximum == null ||
                                      minimum < 1 ||
                                      maximum < minimum) {
                                    setDialogState(
                                      () => validationMessage = 'Please enter a minimum guest count and a maximum that is at least as high.',
                                    );
                                    scrollToKey(eventAttendanceKey);
                                    return;
                                  }
                                }
                                if (type != 'Sports' &&
                                    type != 'Fitness & Wellness' &&
                                    category == 'Other' &&
                                    categoryOther.text.trim().isEmpty) {
                                  setDialogState(
                                    () => validationMessage = 'Please enter a name for the custom category.',
                                  );
                                  scrollToKey(categoryOtherKey);
                                  return;
                                }
                                if (amenities.contains('Other') &&
                                    amenityOther.text.trim().isEmpty) {
                                  setDialogState(
                                    () => validationMessage = 'Enter the other amenity before saving.',
                                  );
                                  scrollToKey(amenityOtherKey);
                                  return;
                                }
                                setDialogState(() => _saving = true);
                                try {
                                  final selectedEventTypes = eventTypes
                                      .map(
                                        (value) => value == 'Other'
                                            ? eventTypeOther.text.trim()
                                            : value,
                                      )
                                      .where((value) => value.isNotEmpty)
                                      .toList();
                                  final selectedCategory = type == 'Sports'
                                      ? sportSlots.first.sportType.text.trim()
                                      : type == 'Fitness & Wellness'
                                      ? fitnessCategories.first.category.text
                                            .trim()
                                      : category == 'Other'
                                      ? categoryOther.text.trim()
                                      : category;
                                  final selectedAmenities = amenities
                                      .map(
                                        (value) => value == 'Other'
                                            ? amenityOther.text.trim()
                                            : value,
                                      )
                                      .where((value) => value.isNotEmpty)
                                      .toList();
                                  final submittedDetails = type == 'Event'
                                      ? [
                                          if (eventTypes.isNotEmpty)
                                            'Event types: ${selectedEventTypes.join(', ')}',
                                          if (eventAttendanceMin.text
                                                  .trim()
                                                  .isNotEmpty ||
                                              eventAttendanceMax.text
                                                  .trim()
                                                  .isNotEmpty)
                                            'Estimated attendance: ${eventAttendanceMin.text.trim().isEmpty ? '?' : eventAttendanceMin.text.trim()} - ${eventAttendanceMax.text.trim().isEmpty ? '?' : eventAttendanceMax.text.trim()} guests',
                                          if (accessibilityNeeds.isNotEmpty)
                                            'Accessibility needs: ${accessibilityNeeds.join(', ')}',
                                          if (parkingNeeds.isNotEmpty)
                                            'Parking needs: ${parkingNeeds.join(', ')}',
                                          if (securityNeeds.isNotEmpty)
                                            'Security needs: ${securityNeeds.join(', ')}',
                                          if (details.text.trim().isNotEmpty)
                                            details.text.trim(),
                                        ].join('\n')
                                      : details.text.trim();
                                  final token = await _session.loadApiToken();
                                  if (token == null || token.isEmpty) {
                                    throw const AuthApiException(
                                      'Your session has expired.',
                                      401,
                                    );
                                  }
                                  var submittedLatitude = latitude;
                                  var submittedLongitude = longitude;
                                  final addressChanged =
                                      address.text.trim() != originalAddress;
                                  if (!locationManuallySelected &&
                                      (submittedLatitude == null ||
                                          submittedLongitude == null ||
                                          addressChanged)) {
                                    final addressLocation =
                                        await geocodeVenueAddress(
                                          address.text.trim(),
                                        );
                                    if (addressLocation == null) {
                                      setDialogState(
                                        () => validationMessage = 'Could not locate this address. Check it or use Preview / adjust map pin to place the venue manually.',
                                      );
                                      scrollToKey(addressKey);
                                      return;
                                    }
                                    submittedLatitude =
                                        addressLocation.latitude;
                                    submittedLongitude =
                                        addressLocation.longitude;
                                  }
                                  final payload = <String, dynamic>{
                                    'businessType': type,
                                    'allowMatchmaking': type == 'Sports'
                                        ? allowMatchmaking
                                        : true,
                                    'name': name.text.trim(),
                                    'category': selectedCategory,
                                    'address': address.text.trim(),
                                    'latitude': submittedLatitude,
                                    'longitude': submittedLongitude,
                                    'visitUrl': visitUrl.text.trim(),
                                    'pricePerHour': type == 'Event'
                                        ? double.parse(price.text.trim())
                                        : type == 'Sports'
                                        ? double.parse(
                                            sportSlots.first.pricePerHour.text
                                                .trim(),
                                          )
                                        : type == 'Fitness & Wellness'
                                        ? double.parse(
                                            fitnessCategories
                                                .first
                                                .sessionPrice
                                                .text
                                                .trim(),
                                          )
                                        : double.parse(price.text.trim()),
                                    'slotCount': type == 'Sports'
                                        ? int.parse(totalSlots.text.trim())
                                        : 1,
                                    'sportsSlots': type == 'Sports'
                                        ? [
                                            for (final sport in sportSlots)
                                              {
                                                'sportType': sport
                                                    .sportType
                                                    .text
                                                    .trim(),
                                                'pricePerHour': double.parse(
                                                  sport.pricePerHour.text
                                                      .trim(),
                                                ),
                                                'fullStudio': sport.fullStudio,
                                                'slotCount': sport.fullStudio
                                                    ? int.parse(
                                                        totalSlots.text.trim(),
                                                      )
                                                    : sport.slotCount,
                                                'includedPlayers':
                                                    int.tryParse(
                                                      sport.includedPlayers.text
                                                          .trim(),
                                                    ) ??
                                                    0,
                                                'additionalPlayerFee':
                                                    double.tryParse(
                                                      sport
                                                          .additionalPlayerFee
                                                          .text
                                                          .trim(),
                                                    ) ??
                                                    0,
                                              },
                                          ]
                                        : const [],
                                    'eventFee': type == 'Event'
                                        ? double.parse(price.text.trim())
                                        : 0,
                                    'includedPlayers': 0,
                                    'additionalPlayerFee': 0,
                                    'ratePeriods': const [],
                                    'fitnessCategories':
                                        type == 'Fitness & Wellness'
                                        ? [
                                            for (final item
                                                in fitnessCategories)
                                              {
                                                'category': item.category.text
                                                    .trim(),
                                                'sessionPrice': double.parse(
                                                  item.sessionPrice.text.trim(),
                                                ),
                                                'monthlyPrice': double.parse(
                                                  item.monthlyPrice.text.trim(),
                                                ),
                                                'yearlyPrice': double.parse(
                                                  item.yearlyPrice.text.trim(),
                                                ),
                                                'yearlyDiscountType':
                                                    item.yearlyDiscountType,
                                                'yearlyDiscountValue':
                                                    item.yearlyDiscountType ==
                                                        'none'
                                                    ? null
                                                    : double.parse(
                                                        item
                                                            .yearlyDiscountValue
                                                            .text
                                                            .trim(),
                                                      ),
                                              },
                                          ]
                                        : const [],
                                    'fitnessCoaches':
                                        type == 'Fitness & Wellness'
                                        ? [
                                            for (final coach in fitnessCoaches)
                                              {
                                                'name': coach.name.text.trim(),
                                                'monthlyPrice': double.parse(
                                                  coach.monthlyPrice.text
                                                      .trim(),
                                                ),
                                                'profileImageUrl':
                                                    coach.profileImageUrl,
                                              },
                                          ]
                                        : const [],
                                    'hours': _formatHours(
                                      openingTime,
                                      closingTime,
                                    ),
                                    'availability': _weekdays
                                        .where(availableDays.contains)
                                        .join(', '),
                                    'tags': selectedAmenities,
                                    'facilityType': facility,
                                    'details': submittedDetails,
                                    'eventTypes': type == 'Event'
                                        ? selectedEventTypes
                                        : const [],
                                    'attendanceMin': type == 'Event'
                                        ? int.tryParse(
                                            eventAttendanceMin.text.trim(),
                                          )
                                        : null,
                                    'attendanceMax': type == 'Event'
                                        ? int.tryParse(
                                            eventAttendanceMax.text.trim(),
                                          )
                                        : null,
                                    'accessibilityNeeds': type == 'Event'
                                        ? accessibilityNeeds
                                        : const [],
                                    'parkingNeeds': type == 'Event'
                                        ? parkingNeeds
                                        : const [],
                                    'securityNeeds': type == 'Event'
                                        ? securityNeeds
                                        : const [],
                                    'imageUrl': images.isEmpty
                                        ? null
                                        : jsonEncode(images),
                                    'imageUrls': images,
                                    'businessLogoUrl': businessLogoUrl,
                                  };
                                  if (editing) {
                                    await _api.updateMerchantBusiness(
                                      token: token,
                                      id: _businessId(editingBusiness)!,
                                      business: payload,
                                    );
                                  } else {
                                    await _api.createMerchantBusiness(
                                      token: token,
                                      business: payload,
                                    );
                                    await widget.onBusinessesChanged();
                                    await _loadNewsPosts(force: true);
                                    if (mounted) {
                                      _updateAddPageState(
                                        () =>
                                            _selectedAddSection = 'News cards',
                                      );
                                    }
                                  }
                                  if (dialogContext.mounted) {
                                    submitted = true;
                                    await Navigator.of(dialogContext)
                                        .maybePop(true);
                                  }
                                } on Exception catch (error) {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => validationMessage =
                                          'Could not ${editing ? 'update' : 'add'} business: $error',
                                    );
                                  }
                                } finally {
                                  if (!submitted && dialogContext.mounted) {
                                    setDialogState(() => _saving = false);
                                  }
                                }
                              },
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : AppText(
                                      editing
                                          ? 'Save changes'
                                          : 'Publish booking card',
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
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeInOutCubic)),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                      reverseCurve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
          ),
    );
    // Let the dialog route finish its reverse animation before disposing the
    // controllers used by its form widgets.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    address.dispose();
    visitUrl.dispose();
    price.dispose();
    totalSlots.dispose();
    includedPlayers.dispose();
    additionalPlayerFee.dispose();
    details.dispose();
    categoryOther.dispose();
    amenityOther.dispose();
    eventTypeOther.dispose();
    eventAttendanceMin.dispose();
    eventAttendanceMax.dispose();
    accessibilityInput.dispose();
    parkingInput.dispose();
    securityInput.dispose();
    for (final sport in sportSlots) {
      sport.dispose();
    }
    for (final item in fitnessCategories) {
      item.dispose();
    }
    for (final coach in fitnessCoaches) {
      coach.dispose();
    }
    if (added == true && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await widget.onBusinessesChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            editing ? 'Business updated.' : 'Business added and published.',
          ),
        ),
      );
    }
  }
}
