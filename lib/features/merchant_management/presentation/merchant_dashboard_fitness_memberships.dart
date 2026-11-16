part of 'merchant_dashboard.dart';

extension _MerchantDashboardFitnessMemberships on _MerchantDashboardPageState {
  Widget _fitnessMembershipManagementContent() {
    final today = DateUtils.dateOnly(DateTime.now());
    final memberships =
        <
          ({
            Map<String, dynamic> booking,
            DateTime startDate,
            DateTime endDate,
            String plan,
            String customerKey,
          })
        >[];

    for (final booking in _filteredPayoutBookings) {
      final planType = '${booking['fitnessPlanType'] ?? ''}'
          .trim()
          .toLowerCase();
      final isMonthly = planType == 'monthly' || planType == 'month';
      final isAnnual = {
        'annual',
        'annually',
        'year',
        'yearly',
      }.contains(planType);
      if (!isMonthly && !isAnnual) continue;
      if (!BookingStatusParser.isConfirmed(booking['status'])) continue;

      final startDate = DateTime.tryParse('${booking['date'] ?? ''}');
      final endDate = fitnessBookingEndDate(booking);
      if (startDate == null || endDate == null) continue;
      final start = DateUtils.dateOnly(startDate);
      if (start.isAfter(today) || endDate.isBefore(today)) continue;

      final customerId = '${booking['customerId'] ?? ''}'.trim();
      final customerEmail = '${booking['customerEmail'] ?? ''}'
          .trim()
          .toLowerCase();
      final customerName = '${booking['customerName'] ?? ''}'
          .trim()
          .toLowerCase();
      final customerKey = customerId.isNotEmpty
          ? 'id:$customerId'
          : customerEmail.isNotEmpty
          ? 'email:$customerEmail'
          : customerName.isNotEmpty
          ? 'name:$customerName'
          : 'booking:${booking['id'] ?? identityHashCode(booking)}';
      memberships.add((
        booking: booking,
        startDate: start,
        endDate: endDate,
        plan: isMonthly ? 'Monthly' : 'Annual',
        customerKey: customerKey,
      ));
    }

    final latestMembershipByCustomer =
        <String, (Map<String, dynamic>, DateTime, DateTime, String)>{};
    for (final membership in memberships) {
      final existing = latestMembershipByCustomer[membership.customerKey];
      if (existing == null || membership.startDate.isAfter(existing.$2)) {
        latestMembershipByCustomer[membership.customerKey] = (
          membership.booking,
          membership.startDate,
          membership.endDate,
          membership.plan,
        );
      }
    }
    final activeMemberships =
        latestMembershipByCustomer.values.where((membership) {
          if (_fitnessMembershipFilter == 1) return membership.$4 == 'Monthly';
          if (_fitnessMembershipFilter == 2) return membership.$4 == 'Annual';
          return true;
        }).toList()..sort(
          (first, second) => '${first.$1['customerName'] ?? ''}'
              .toLowerCase()
              .compareTo('${second.$1['customerName'] ?? ''}'.toLowerCase()),
        );

    String formattedDate(DateTime date) =>
        MaterialLocalizations.of(context).formatMediumDate(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Active fitness memberships',
                    style: TextStyle(
                      color: _merchantInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    localize: true,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${activeMemberships.length} active customers · valid today',
                    key: const ValueKey('merchant-fitness-active-count'),
                    style: TextStyle(color: _merchantMuted, fontSize: 11),
                    localize: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          key: const ValueKey('merchant-fitness-membership-plan-filter'),
          expandedInsets: EdgeInsets.zero,
          style: _managementTabsStyle,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              label: AppText('All plans', localize: true),
            ),
            ButtonSegment(value: 1, label: AppText('Monthly', localize: true)),
            ButtonSegment(value: 2, label: AppText('Annual', localize: true)),
          ],
          selected: {_fitnessMembershipFilter},
          onSelectionChanged: (selection) => _setAnalyticsState(
            () => _fitnessMembershipFilter = selection.first,
          ),
        ),
        const SizedBox(height: 8),
        if (activeMemberships.isEmpty)
          _emptyManagementState(
            icon: Icons.card_membership_outlined,
            emptyTitle: 'No active fitness memberships',
            emptyMessage:
                'Approved monthly and annual memberships valid today will appear here.',
            filteredTitle: 'No active memberships match your filters',
            filteredMessage:
                'Try clearing the business-type or search filter to see more fitness memberships.',
          )
        else
          Card(
            key: const ValueKey('merchant-fitness-active-membership-table'),
            elevation: 0,
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 520,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.35),
                    1: FlexColumnWidth(.75),
                    2: FlexColumnWidth(1.55),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: _merchantLine),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.page),
                      children: [
                        _fitnessMembershipTableCell('Customer', isHeader: true),
                        _fitnessMembershipTableCell(
                          'Membership',
                          isHeader: true,
                        ),
                        _fitnessMembershipTableCell(
                          'Valid date range',
                          isHeader: true,
                        ),
                      ],
                    ),
                    for (final membership in activeMemberships)
                      TableRow(
                        children: [
                          _fitnessMembershipTableCell(
                            '${membership.$1['customerName'] ?? 'Customer'}',
                            key: ValueKey(
                              'merchant-active-fitness-customer-${membership.$1['customerId'] ?? membership.$1['id']}',
                            ),
                            secondary:
                                '${membership.$1['customerEmail'] ?? ''}',
                          ),
                          _fitnessMembershipTableCell(membership.$4),
                          _fitnessMembershipTableCell(
                            '${formattedDate(membership.$2)} – '
                            '${formattedDate(membership.$3)}',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fitnessMembershipTableCell(
    String value, {
    Key? key,
    bool isHeader = false,
    String? secondary,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isHeader ? _merchantMuted : _merchantInk,
            fontSize: isHeader ? 10 : 11,
            fontWeight: isHeader ? FontWeight.w800 : FontWeight.w700,
          ),
          localize: isHeader,
        ),
        if (secondary != null && secondary.isNotEmpty) ...[
          const SizedBox(height: 2),
          AppText(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _merchantMuted, fontSize: 9),
          ),
        ],
      ],
    ),
  );
}
