part of 'merchant_dashboard.dart';

extension _MerchantDashboardPayoutDetails on _MerchantDashboardPageState {
  Future<void> showPayoutBookingDetails(
    Map<String, dynamic> booking, {
    bool paymentOnly = false,
  }) async {
    final total = _bookingAmount(booking['total']);
    final received = _bookingAmountReceived(booking);
    final downpayment = _bookingAmount(booking['downpayment']);
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    final isCashOnArrival = booking['paymentMethod'] == 'cash_on_arrival';
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    final balance = (total - received).clamp(0, total).toDouble();
    final playersLabel = isEvent ? 'Guests' : 'Players';
    final status = '${booking['status'] ?? 'pending'}';
    final isPendingApproval = _isPendingBooking(booking);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .88,
          child: ListView(
            key: const ValueKey('merchant-payout-booking-details-list'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              AppText(
                paymentOnly ? 'Payment details' : 'Booking details',
                style: TextStyle(
                  color: _merchantInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              const SizedBox(height: 4),
              AppText(
                'Booking #${booking['id']} · $status',
                style: TextStyle(color: _merchantMuted),
                localize: true,
              ),
              if (!paymentOnly)
                _payoutDetailsSection('Customer information', [
                  _payoutDetailRow('Customer', booking['customerName']),
                  _payoutDetailRow('Email', booking['customerEmail']),
                  _payoutDetailRow('Customer ID', booking['customerId']),
                ]),
              if (!paymentOnly)
                _payoutDetailsSection('Venue information', [
                  _payoutDetailRow('Venue', booking['venueName']),
                  _payoutDetailRow('Business type', booking['businessType']),
                  _payoutDetailRow('Address', booking['address']),
                  _payoutDetailRow('Facility', booking['facilityType']),
                  _payoutDetailRow('Venue details', booking['details']),
                ]),
              if (!paymentOnly)
                _payoutDetailsSection('Booking information', [
                  _payoutDetailRow('Reference', 'BK-${booking['id']}'),
                  _payoutDetailRow(
                    'Booking identity',
                    booking['bookingType'] == 'matchmaking'
                        ? 'Matchmaking · lobby ${booking['matchmakingLobbyId'] ?? '—'}'
                        : 'Regular booking',
                  ),
                  if (isEvent)
                    _payoutDetailRow(
                      'Event schedule',
                      _bookingTimeRangeLabel(booking),
                    )
                  else ...[
                    _payoutDetailRow('Date', booking['date']),
                    _payoutDetailRow(
                      'Start time',
                      _formatPayoutTime(booking['startTime']),
                    ),
                    _payoutDetailRow(
                      fitnessPlanType.isNotEmpty
                          ? 'First visit session'
                          : 'Duration',
                      '${booking['durationHours'] ?? '—'} hour(s)',
                    ),
                  ],
                  _payoutDetailRow(playersLabel, booking['players']),
                  _payoutDetailRow(
                    'Booking type',
                    _bookingServiceLabel(booking),
                  ),
                  if (fitnessPlanType.isEmpty && !isEvent)
                    _payoutDetailRow(
                      'Booked area',
                      booking['occupiesFullStudio'] == true ||
                              booking['occupiesFullStudio'] == 1
                          ? 'Whole studio'
                          : _bookingSlotLabel(booking),
                    ),
                  if (booking['eventType'] != null)
                    _payoutDetailRow('Event type', booking['eventType']),
                  if (fitnessPlanType.isNotEmpty) ...[
                    _payoutDetailRow('Fitness plan', fitnessPlanType),
                    _payoutDetailRow(
                      'Plan duration',
                      _fitnessPlanDuration(fitnessPlanType),
                    ),
                  ],
                  if (booking['fitnessCategory'] != null)
                    _payoutDetailRow(
                      'Fitness category',
                      booking['fitnessCategory'],
                    ),
                  if (booking['fitnessCoachName'] != null)
                    _payoutDetailRow(
                      'Coach',
                      '${booking['fitnessCoachName']}'
                          '${booking['fitnessCoachDurationMonths'] == null ? '' : ' · ${booking['fitnessCoachDurationMonths']} month(s)'}',
                    ),
                ]),
              if (!paymentOnly)
                _payoutDetailsSection('Arrival history', [
                  _payoutDetailRow(
                    'Arrival outcome',
                    _hasCheckedIn(booking)
                        ? 'Arrived · customer scanned venue QR'
                        : _isNoShowBooking(booking)
                        ? 'No-show · scheduled booking time ended without check-in'
                        : 'Awaiting arrival',
                  ),
                  if (_hasCheckedIn(booking))
                    _payoutDetailRow('Check-in time', booking['checkedInAt']),
                ]),
              _payoutDetailsSection('Payment details', [
                _payoutDetailRow(
                  'Payment method',
                  _payoutPaymentLabel(booking['paymentMethod']),
                ),
                _payoutDetailRow(
                  'Payment status',
                  booking['paymentMethod'] == 'online' &&
                          paymentStatus != 'paid' &&
                          booking['status'] == 'approved'
                      ? 'Awaiting customer payment'
                      : paymentStatus,
                ),
                _payoutDetailRow(
                  'Payment reference',
                  booking['paymentReference'],
                ),
                _payoutDetailRow(
                  'Refund status',
                  _paymentRefundLabel(
                    '${booking['paymentRefundStatus'] ?? 'not_requested'}',
                  ),
                ),
                _payoutDetailRow(
                  'Refund reference',
                  booking['paymentRefundId'],
                ),
                _payoutDetailRow(
                  'Rate',
                  '\u{20B1} ${_bookingAmount(booking['pricePerHour']).toStringAsFixed(2)}',
                ),
                _payoutDetailRow(
                  'Extra-player fee',
                  '\u{20B1} ${_bookingAmount(booking['extraPlayerCharge']).toStringAsFixed(2)}',
                ),
                _payoutDetailRow(
                  'Plan price',
                  '\u{20B1} ${_bookingAmount(booking['fitnessPlanPrice']).toStringAsFixed(2)}',
                ),
                _payoutDetailRow(
                  'Coach price',
                  '\u{20B1} ${_bookingAmount(booking['fitnessCoachPrice']).toStringAsFixed(2)}',
                ),
                _payoutDetailRow(
                  'Total',
                  '\u{20B1} ${total.toStringAsFixed(2)}',
                ),
                if (isCashOnArrival &&
                    paymentStatus == 'unpaid' &&
                    isPendingApproval)
                  _payoutDetailRow(
                    'Cash downpayment after approval',
                    '\u{20B1} ${downpayment.toStringAsFixed(2)}',
                  )
                else if (isCashOnArrival && paymentStatus == 'unpaid')
                  _payoutDetailRow(
                    'Cash downpayment due at venue',
                    '\u{20B1} ${downpayment.toStringAsFixed(2)}',
                  )
                else if (!isCashOnArrival &&
                    paymentStatus != 'paid' &&
                    isPendingApproval)
                  _payoutDetailRow(
                    'Online payment due after approval',
                    '\u{20B1} ${balance.toStringAsFixed(2)}',
                  )
                else
                  _payoutDetailRow(
                    paymentStatus == 'partial'
                        ? 'Cash downpayment received'
                        : 'Amount received',
                    '\u{20B1} ${received.toStringAsFixed(2)}',
                  ),
                _payoutDetailRow(
                  isCashOnArrival && paymentStatus == 'unpaid'
                      ? 'Remaining cash balance after downpayment'
                      : 'Remaining balance',
                  '\u{20B1} ${(isCashOnArrival && paymentStatus == 'unpaid' ? (total - downpayment).clamp(0, total).toDouble() : balance).toStringAsFixed(2)}',
                ),
              ]),
              if (!paymentOnly && _isPendingBooking(booking))
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_bookingAmountReceived(booking) > 0)
                        const AppText(
                          'Return the received payment before declining.',
                          localize: true,
                          style: TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: ValueKey(
                                'merchant-booking-decline-${booking['id']}',
                              ),
                              onPressed: _bookingAmountReceived(booking) > 0
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _declineMerchantBooking(
                                        (booking['id'] as num).toInt(),
                                        matchmakingLobbyId:
                                            booking['matchmakingLobbyId'] is num
                                            ? (booking['matchmakingLobbyId']
                                                      as num)
                                                  .toInt()
                                            : null,
                                      );
                                    },
                              child: const AppText('Decline', localize: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: ValueKey(
                                'merchant-booking-approve-${booking['id']}',
                              ),
                              onPressed:
                                  booking['bookingType'] != 'matchmaking' &&
                                      booking['paymentMethod'] == 'online' &&
                                      booking['paymentStatus'] != 'paid'
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _approveMerchantBooking(
                                        (booking['id'] as num).toInt(),
                                        matchmakingLobbyId:
                                            booking['matchmakingLobbyId'] is num
                                            ? (booking['matchmakingLobbyId']
                                                      as num)
                                                  .toInt()
                                            : null,
                                      );
                                    },
                              child: const AppText('Approve', localize: true),
                            ),
                          ),
                        ],
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

  Widget _payoutDetailsSection(String title, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: TextStyle(
            color: _merchantInk,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          localize: true,
        ),
        const Divider(height: 14),
        ...rows,
      ],
    ),
  );

  Widget _payoutDetailRow(String label, dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: AppText(
              label,
              style: TextStyle(color: _merchantMuted, fontSize: 13),
              localize: true,
            ),
          ),
          Expanded(
            child: AppText(
              text,
              style: TextStyle(
                color: _merchantInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              localize: true,
            ),
          ),
        ],
      ),
    );
  }
}
