part of 'merchant_dashboard.dart';

extension _MerchantDashboardPaymentManagement on _MerchantDashboardPageState {
  Widget _paymentManagementContent() {
    final bookings = _filteredPayoutBookings;
    final paymentBookings = bookings
        .where((booking) => !BookingStatusParser.isCancelled(booking['status']))
        .toList();
    final refundBookings = bookings.where((booking) {
      return BookingStatusParser.isCancelled(booking['status']) &&
          '${booking['paymentRefundStatus'] ?? 'not_requested'}' !=
              'not_requested';
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          key: const ValueKey('merchant-payment-management-tabs'),
          style: _analyticsFilterStyle,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: AppText('Payments', localize: true)),
            ButtonSegment(value: 1, label: AppText('Earnings', localize: true)),
            ButtonSegment(value: 2, label: AppText('Refunds', localize: true)),
          ],
          selected: {_paymentManagementTab},
          onSelectionChanged: (selection) {
            _setAnalyticsState(() => _paymentManagementTab = selection.first);
          },
        ),
        const SizedBox(height: 8),
        if (_paymentManagementTab == 0)
          if (paymentBookings.isEmpty)
            _emptyManagementState(
              icon: Icons.payments_outlined,
              emptyTitle: 'No booking payments',
              emptyMessage: 'Payments for customer bookings will appear here.',
              filteredTitle: 'No booking payments match your filters',
              filteredMessage: 'Try clearing the business-type or search filter to see more payments.',
            )
          else ...[
            _paymentOverviewCard(paymentBookings),
            const SizedBox(height: 8),
            for (final booking in paymentBookings) ...[
              _paymentManagementBookingCard(booking),
              const SizedBox(height: 8),
            ],
          ]
        else if (_paymentManagementTab == 1)
          if (bookings.isEmpty && _hasPayoutFilters)
            _emptyManagementState(
              icon: Icons.payments_outlined,
              emptyTitle: 'No booking payments',
              emptyMessage: 'Payments for customer bookings will appear here.',
              filteredTitle: 'No earnings match your filters',
              filteredMessage: 'Try clearing the business-type or search filter to see earnings.',
            )
          else
            _paymentEarningsContent(bookings)
        else if (refundBookings.isEmpty)
          _emptyManagementState(
            icon: Icons.currency_exchange_rounded,
            emptyTitle: 'No refunds to review',
            emptyMessage:
                'Refund updates for cancelled bookings will appear here.',
            filteredTitle: 'No refunds match your filters',
            filteredMessage: 'Try clearing the business-type or search filter to see more refund updates.',
          )
        else
          for (final booking in refundBookings) ...[
            _paymentRefundBookingCard(booking),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Widget _paymentOverviewCard(List<Map<String, dynamic>> bookings) {
    final received = bookings.fold<double>(
      0,
      (sum, booking) => sum + _bookingAmountReceived(booking),
    );
    final balanceDue = bookings.fold<double>(0, (sum, booking) {
      final amount = _bookingAmount(booking['total']);
      final amountReceived = _bookingAmountReceived(booking);
      return sum + (amount - amountReceived).clamp(0, amount).toDouble();
    });
    return MerchantPayoutCard(
      bookingCount: bookings.length,
      received: received,
      balanceDue: balanceDue,
    );
  }

  Widget _paymentEarningsContent(List<Map<String, dynamic>> bookings) {
    final grossCollected = bookings.fold<double>(
      0,
      (sum, booking) => sum + _bookingAmountReceived(booking),
    );
    final refunded = bookings.fold<double>(0, (sum, booking) {
      return sum +
          ('${booking['paymentRefundStatus'] ?? ''}' == 'succeeded'
              ? _bookingAmountReceived(booking)
              : 0);
    });
    final cashReturnDue = bookings.fold<double>(0, (sum, booking) {
      return sum +
          ('${booking['paymentRefundStatus'] ?? ''}' == 'manual_cash_return'
              ? _bookingAmountReceived(booking)
              : 0);
    });
    final netEarnings = (grossCollected - refunded - cashReturnDue)
        .clamp(0, grossCollected)
        .toDouble();
    final outstanding = bookings.fold<double>(0, (sum, booking) {
      final status = '${booking['status'] ?? ''}'.toLowerCase();
      if (BookingStatusParser.isCancelled(status) || status == 'pending') {
        return sum;
      }
      final due =
          _bookingAmount(booking['total']) - _bookingAmountReceived(booking);
      return sum + due.clamp(0, double.infinity).toDouble();
    });
    final onlineCollected = bookings
        .where((booking) => booking['paymentMethod'] == 'online')
        .fold<double>(
          0,
          (sum, booking) => sum + _bookingAmountReceived(booking),
        );
    final cashCollected = bookings
        .where((booking) => booking['paymentMethod'] == 'cash_on_arrival')
        .fold<double>(
          0,
          (sum, booking) => sum + _bookingAmountReceived(booking),
        );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _paymentEarningsMetric(
                'Net earnings',
                netEarnings,
                Icons.account_balance_wallet_outlined,
                const ValueKey('merchant-payment-net-earnings'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _paymentEarningsMetric(
                'Collected',
                grossCollected,
                Icons.payments_outlined,
                const ValueKey('merchant-payment-gross-collected'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _paymentEarningsMetric(
                'Refunded',
                refunded,
                Icons.currency_exchange_rounded,
                const ValueKey('merchant-payment-refunded-total'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _paymentEarningsMetric(
                'Balance due',
                outstanding,
                Icons.hourglass_bottom_rounded,
                const ValueKey('merchant-payment-outstanding'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText(
                  'Collected by payment method',
                  style: TextStyle(
                    color: _merchantInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 8),
                _payoutManagementInfoRow(
                  'Online payments',
                  '\u{20B1} ${onlineCollected.toStringAsFixed(2)}',
                ),
                _payoutManagementInfoRow(
                  'Cash on arrival',
                  '\u{20B1} ${cashCollected.toStringAsFixed(2)}',
                ),
                _payoutManagementInfoRow(
                  'Cash return due',
                  '\u{20B1} ${cashReturnDue.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentEarningsMetric(
    String label,
    double amount,
    IconData icon,
    Key key,
  ) => Card(
    key: key,
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: _merchantOrange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  label,
                  style: TextStyle(color: _merchantMuted, fontSize: 11),
                  localize: true,
                ),
                const SizedBox(height: 3),
                AppText(
                  '\u{20B1} ${amount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _merchantInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _paymentRefundBookingCard(Map<String, dynamic> booking) {
    final refundStatus = '${booking['paymentRefundStatus'] ?? 'not_requested'}';
    return Card(
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _customerProfileIdentity(booking, fontSize: 15),
            const SizedBox(height: 5),
            _payoutManagementInfoRow(
              'Booking',
              '#${booking['id']} · ${booking['venueName'] ?? 'Venue'}',
            ),
            _payoutManagementInfoRow(
              'Payment received',
              '\u{20B1} ${_bookingAmountReceived(booking).toStringAsFixed(2)}',
            ),
            _payoutManagementInfoRow(
              'Payment method',
              _payoutPaymentLabel(booking['paymentMethod']),
            ),
            _payoutManagementInfoRow(
              'Refund status',
              _paymentRefundLabel(refundStatus),
            ),
            if ('${booking['paymentReference'] ?? ''}'.isNotEmpty)
              _payoutManagementInfoRow(
                'Payment reference',
                booking['paymentReference'],
              ),
            if ('${booking['paymentRefundId'] ?? ''}'.isNotEmpty)
              _payoutManagementInfoRow(
                'Refund reference',
                booking['paymentRefundId'],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('merchant-refund-view-${booking['id']}'),
                onPressed: () =>
                    _showPayoutBookingDetails(booking, paymentOnly: true),
                icon: const Icon(Icons.visibility_outlined),
                label: const AppText('View refund', localize: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _paymentRefundLabel(String status) => switch (status) {
    'pending' => 'Refund processing',
    'succeeded' => 'Refund completed',
    'failed' => 'Refund failed · contact support',
    'not_eligible' => 'Not eligible for refund',
    'manual_cash_return' => 'Manual cash return required',
    'not_requested' => 'No refund requested',
    _ => status,
  };

  Widget _paymentManagementBookingCard(Map<String, dynamic> booking) {
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    final isCashOnArrival = booking['paymentMethod'] == 'cash_on_arrival';
    final isCancelled = BookingStatusParser.isCancelled(booking['status']);
    final isPendingApproval =
        '${booking['status'] ?? ''}'.toLowerCase() == 'pending';
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    final isOnlinePaymentDue =
        !isCancelled &&
        !isPendingApproval &&
        booking['paymentMethod'] == 'online' &&
        paymentStatus != 'paid';
    final paid = paymentStatus == 'paid';
    final received = _bookingAmountReceived(booking);
    final total = _bookingAmount(booking['total']);
    final downpayment = _bookingAmount(booking['downpayment']);
    final balance = (total - received).clamp(0, total).toDouble();
    final paymentStatusLabel = isCancelled
        ? 'Cancelled'
        : isPendingApproval
        ? 'Awaiting approval'
        : isOnlinePaymentDue
        ? 'Awaiting customer payment'
        : paid
        ? 'Fully paid'
        : paymentStatus == 'partial'
        ? 'Downpayment received'
        : 'Unpaid';
    final statusColor = isCancelled
        ? AppColors.muted
        : isPendingApproval
        ? AppColors.warning
        : isOnlinePaymentDue
        ? AppColors.warning
        : paid
        ? AppColors.success
        : paymentStatus == 'partial'
        ? AppColors.warning
        : _merchantOrange;
    final dueLabel = isCancelled
        ? 'No balance due'
        : isPendingApproval
        ? 'Payment after approval'
        : isOnlinePaymentDue
        ? 'Online payment due'
        : isCashOnArrival && paymentStatus == 'unpaid'
        ? 'Cash downpayment due'
        : 'Balance due';
    final dueAmount = isCancelled
        ? 0.0
        : isCashOnArrival && paymentStatus == 'unpaid'
        ? downpayment
        : balance;
    return Card(
      key: ValueKey('merchant-payment-card-${booking['id']}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _customerProfileIdentity(booking, fontSize: 16),
                    const SizedBox(height: 3),
                    AppText(
                      '#${booking['id']} · ${booking['venueName'] ?? 'Venue'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _merchantMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      localize: true,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .3),
                    ),
                  ),
                  child: AppText(
                    paymentStatusLabel,
                    maxLines: 1,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    localize: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Booking total',
                          style: TextStyle(
                            color: _merchantMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          localize: true,
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          '\u{20B1} ${total.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _merchantInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 38, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          dueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _merchantMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          localize: true,
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          '\u{20B1} ${dueAmount.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dueAmount > 0
                                ? _merchantOrange
                                : AppColors.success,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _payoutManagementInfoRow(
              'Payment method',
              _payoutPaymentLabel(booking['paymentMethod']),
            ),
            _payoutManagementInfoRow(
              isEvent ? 'Event schedule' : 'Booking date',
              isEvent ? _bookingTimeRangeLabel(booking) : booking['date'],
            ),
            _payoutManagementInfoRow(
              'Amount received',
              '\u{20B1} ${received.toStringAsFixed(2)}',
            ),
            _payoutManagementInfoRow(
              'Price',
              '\u{20B1} ${total.toStringAsFixed(2)}',
            ),
            if (isCashOnArrival && paymentStatus == 'unpaid') ...[
              _payoutManagementInfoRow(
                'Cash downpayment due at venue',
                '\u{20B1} ${downpayment.toStringAsFixed(2)}',
              ),
              _payoutManagementInfoRow(
                'Remaining cash balance after downpayment',
                '\u{20B1} ${(total - downpayment).clamp(0, total).toStringAsFixed(2)}',
              ),
            ] else
              _payoutManagementInfoRow(
                paymentStatus == 'partial'
                    ? 'Cash downpayment received'
                    : 'Balance',
                paymentStatus == 'partial'
                    ? '\u{20B1} ${received.toStringAsFixed(2)}'
                    : '\u{20B1} ${balance.toStringAsFixed(2)}',
              ),
            if (paymentStatus == 'partial')
              _payoutManagementInfoRow(
                'Cash balance due',
                '\u{20B1} ${(total - downpayment).clamp(0, total).toStringAsFixed(2)}',
              ),
            _payoutManagementInfoRow(
              'Payment status',
              paid
                  ? 'Fully paid'
                  : paymentStatus == 'partial'
                  ? 'Downpayment received · balance due'
                  : 'Unpaid',
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('merchant-payment-view-${booking['id']}'),
                  onPressed: () =>
                      _showPayoutBookingDetails(booking, paymentOnly: true),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const AppText('View payment', localize: true),
                ),
                if (isCashOnArrival &&
                    (paymentStatus == 'unpaid' || paymentStatus == 'partial') &&
                    !isCancelled)
                  OutlinedButton.icon(
                    key: ValueKey('merchant-payment-toggle-${booking['id']}'),
                    onPressed: () => _setCashOnArrivalPaymentStatus(
                      booking,
                      paymentStatus == 'unpaid' ? 'partial' : 'paid',
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: AppText(
                      paymentStatus == 'unpaid'
                          ? 'Mark cash downpayment received'
                          : 'Mark remaining balance paid',
                      localize: true,
                    ),
                  ),
                if (_isMerchantDeletableBooking(booking))
                  OutlinedButton.icon(
                    key: ValueKey('merchant-payment-delete-${booking['id']}'),
                    onPressed: () =>
                        _deleteCompletedBooking((booking['id'] as num).toInt()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const AppText('Delete', localize: true),
                  ),
              ],
            ),
            if (!(isCashOnArrival &&
                (paymentStatus == 'unpaid' || paymentStatus == 'partial') &&
                !isCancelled)) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: AppText(
                  isCancelled
                      ? 'Cancelled booking'
                      : isCashOnArrival
                      ? 'Cash payment recorded'
                      : 'Online payment status is provider-managed',
                  localize: true,
                  style: TextStyle(
                    color: _merchantMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
