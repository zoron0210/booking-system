part of 'merchant_dashboard.dart';

extension _MerchantDashboardBookingManagement on _MerchantDashboardPageState {
  Widget bookingManagementContent() {
    final requestBookings = _filteredPayoutBookings
        .where(_isPendingBooking)
        .toList();
    final activeBookings = _filteredPayoutBookings
        .where(_isApprovedBooking)
        .toList();
    final completedBookings = _filteredPayoutBookings
        .where(_isFinishedBooking)
        .toList();
    final bookings = switch (_bookingManagementTab) {
      0 => requestBookings,
      1 => activeBookings,
      _ => completedBookings,
    };
    final emptyMessage = switch (_bookingManagementTab) {
      0 => (
        Icons.inbox_outlined,
        'No booking requests',
        'New customer requests will appear here.',
      ),
      1 => (
        Icons.event_available_outlined,
        'No active bookings',
        'Approved bookings will appear here until their scheduled end.',
      ),
      _ => (
        Icons.task_alt_outlined,
        'No completed bookings',
        'Completed bookings will appear here after their scheduled end.',
      ),
    };
    return Column(
      children: [
        SegmentedButton<int>(
          key: const ValueKey('merchant-booking-management-status-tabs'),
          expandedInsets: EdgeInsets.zero,
          style: _managementTabsStyle,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 0,
              label: _bookingStatusCountLabel(
                title: 'Requests',
                count: requestBookings.length,
                semanticDefinition: 'pending or awaiting merchant approval',
                key: 'merchant-booking-count-requests',
              ),
            ),
            ButtonSegment(
              value: 1,
              label: _bookingStatusCountLabel(
                title: 'Active',
                count: activeBookings.length,
                semanticDefinition: 'approved or matchmaking-open',
                key: 'merchant-booking-count-active',
              ),
            ),
            ButtonSegment(
              value: 2,
              label: _bookingStatusCountLabel(
                title: 'Completed',
                count: completedBookings.length,
                semanticDefinition: 'finished, completed, or done',
                key: 'merchant-booking-count-completed',
              ),
            ),
          ],
          selected: {_bookingManagementTab},
          onSelectionChanged: (selection) {
            _setAnalyticsState(() => _bookingManagementTab = selection.first);
          },
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty)
          _emptyManagementState(
            icon: emptyMessage.$1,
            emptyTitle: emptyMessage.$2,
            emptyMessage: emptyMessage.$3,
            filteredTitle: switch (_bookingManagementTab) {
              0 => 'No requests match your filters',
              1 => 'No active bookings match your filters',
              _ => 'No completed bookings match your filters',
            },
            filteredMessage:
                'Try clearing the business-type or search filter to see more bookings.',
          )
        else
          for (final booking in bookings) ...[
            customerManagementBookingCard(
              booking,
              showDelete: _isMerchantDeletableBooking(booking),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Widget customerManagementContent() {
    final arrivalBookings = _filteredPayoutBookings
        .where(
          (booking) =>
              !BookingStatusParser.isCancelled(booking['status']) &&
              (_hasCheckedIn(booking) ||
                  _isApprovedBooking(booking) ||
                  _isFinishedBooking(booking)),
        )
        .toList();
    final bookings = switch (_customerArrivalTab) {
      0 => arrivalBookings.where(_hasCheckedIn).toList(),
      1 => arrivalBookings.where(_isNoShowBooking).toList(),
      _ =>
        arrivalBookings
            .where(
              (booking) =>
                  !_hasCheckedIn(booking) && !_isNoShowBooking(booking),
            )
            .toList(),
    };
    final emptyMessage = switch (_customerArrivalTab) {
      0 => (
        Icons.how_to_reg_outlined,
        'No customers have arrived',
        'Customers appear here after scanning the venue check-in QR.',
      ),
      1 => (
        Icons.event_busy_outlined,
        'No no-shows',
        'Bookings appear here after their scheduled end when the customer has not checked in.',
      ),
      _ => (
        Icons.hourglass_empty_rounded,
        'No upcoming arrivals',
        'Bookings awaiting their scheduled time or customer check-in appear here.',
      ),
    };
    return Column(
      children: [
        SegmentedButton<int>(
          key: const ValueKey('merchant-customer-arrival-tabs'),
          expandedInsets: EdgeInsets.zero,
          style: _managementTabsStyle,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 2,
              label: AppText('Awaiting arrival', localize: true),
            ),
            ButtonSegment(value: 0, label: AppText('Arrived', localize: true)),
            ButtonSegment(value: 1, label: AppText('No-show', localize: true)),
          ],
          selected: {_customerArrivalTab},
          onSelectionChanged: (selection) {
            _setAnalyticsState(() => _customerArrivalTab = selection.first);
          },
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty)
          _emptyManagementState(
            icon: emptyMessage.$1,
            emptyTitle: emptyMessage.$2,
            emptyMessage: emptyMessage.$3,
            filteredTitle: switch (_customerArrivalTab) {
              0 => 'No customers who match your filters have arrived',
              1 => 'No matching no-shows',
              _ => 'No upcoming arrivals match your filters',
            },
            filteredMessage:
                'Try clearing the business-type or search filter to see more arrivals.',
          ),
        for (final booking in bookings) ...[
          customerManagementBookingCard(
            booking,
            showDelete: _isMerchantDeletableBooking(booking),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget customerManagementBookingCard(
    Map<String, dynamic> booking, {
    bool showDelete = false,
  }) {
    final pending = _isPendingBooking(booking);
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    final canApprove =
        booking['bookingType'] == 'matchmaking' ||
        booking['paymentMethod'] != 'online' ||
        booking['paymentStatus'] == 'paid';
    final canDecline = _bookingAmountReceived(booking) <= 0;
    final checkedInAt = booking['checkedInAt'];
    final approvalDeadline = parseBookingApprovalDeadline(
      booking['approvalExpiresAt'],
    );
    return Card(
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '${booking['customerName'] ?? 'Customer'}',
              style: TextStyle(
                color: _merchantInk,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              localize: true,
            ),
            const SizedBox(height: 6),
            _payoutManagementInfoRow(
              'Booking type',
              '${booking['bookingType'] == 'matchmaking' ? 'Matchmaking booking' : 'Regular booking'} · '
                  '${booking['businessType'] ?? 'Booking'} · '
                  '${_bookingServiceLabel(booking)}',
            ),
            _payoutManagementInfoRow('Venue', booking['venueName']),
            _payoutManagementInfoRow(
              'Booking date and time',
              _bookingTimeRangeLabel(booking),
            ),
            if (!isEvent)
              _payoutManagementInfoRow(
                'Duration',
                _bookingDurationHoursLabel(booking['durationHours']),
              ),
            if ('${booking['fitnessPlanType'] ?? ''}'.isNotEmpty)
              _payoutManagementInfoRow(
                'Plan duration',
                _fitnessPlanDuration('${booking['fitnessPlanType']}'),
              ),
            _payoutManagementInfoRow(
              'Status',
              BookingStatusParser.label(booking['status']),
            ),
            if (pending && approvalDeadline != null)
              _payoutManagementInfoRow(
                'Approval deadline',
                formatBookingApprovalDeadline(approvalDeadline),
              ),
            if (_hasCheckedIn(booking)) ...[
              _payoutManagementInfoRow('Arrival status', 'Arrived'),
              _payoutManagementInfoRow('Check-in time', checkedInAt),
            ] else if (_isNoShowBooking(booking))
              _payoutManagementInfoRow(
                'Arrival status',
                'No-show · scheduled time ended',
              )
            else if (_isApprovedBooking(booking))
              _payoutManagementInfoRow('Arrival status', 'Awaiting arrival'),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('merchant-booking-view-${booking['id']}'),
                  onPressed: () => _showPayoutBookingDetails(booking),
                  icon: const Icon(Icons.visibility_outlined),
                  label: AppText(
                    pending ? 'Full details' : 'View booking',
                    localize: true,
                  ),
                ),
                if (pending)
                  FilledButton.icon(
                    key: ValueKey(
                      'merchant-booking-card-approve-${booking['id']}',
                    ),
                    onPressed: canApprove
                        ? () => _confirmMerchantBookingApproval(booking)
                        : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const AppText('Approve', localize: true),
                  ),
                if (pending)
                  OutlinedButton.icon(
                    key: ValueKey(
                      'merchant-booking-card-decline-${booking['id']}',
                    ),
                    onPressed: canDecline
                        ? () => _declineMerchantBooking(
                            (booking['id'] as num).toInt(),
                            matchmakingLobbyId:
                                booking['matchmakingLobbyId'] is num
                                ? (booking['matchmakingLobbyId'] as num)
                                      .toInt()
                                : null,
                          )
                        : null,
                    icon: const Icon(Icons.close_rounded),
                    label: const AppText('Decline', localize: true),
                  ),
                if (showDelete)
                  OutlinedButton.icon(
                    key: ValueKey('merchant-booking-delete-${booking['id']}'),
                    onPressed: () =>
                        _deleteCompletedBooking((booking['id'] as num).toInt()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const AppText('Delete', localize: true),
                  ),
              ],
            ),
            if (pending && (!canApprove || !canDecline)) ...[
              const SizedBox(height: 6),
              AppText(
                !canDecline
                    ? 'Return received payment before declining this booking.'
                    : 'Online bookings must be paid before they can be approved.',
                style: TextStyle(color: _merchantMuted, fontSize: 11),
                localize: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookingStatusCountLabel({
    required String title,
    required int count,
    required String semanticDefinition,
    required String key,
  }) => Semantics(
    key: ValueKey(key),
    label:
        '$title, $count ${count == 1 ? 'booking' : 'bookings'}; '
        '$semanticDefinition',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AppText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              localize: true,
            ),
          ),
          const SizedBox(width: 4),
          Badge(label: AppText('$count', localize: false)),
        ],
      ),
    ),
  );
}
