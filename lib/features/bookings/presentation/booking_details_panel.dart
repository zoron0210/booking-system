import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app_design_system.dart';
import '../../../app_text.dart';
import '../../../features/bookings/domain/booking.dart';
import 'customer_booking_controller.dart';

class BookingDetailsPanel extends StatelessWidget {
  const BookingDetailsPanel({
    super.key,
    required this.booking,
    required this.onDeleteBooking,
    required this.onPayBookingPrototype,
    required this.onReviewBooking,
    required this.formatBookingApprovalDeadline,
  });

  final Booking booking;
  final Future<void> Function(Booking booking) onDeleteBooking;
  final Future<void> Function(Booking booking) onPayBookingPrototype;
  final Future<void> Function(Booking booking, {bool closeDetailsOnSubmit})
  onReviewBooking;
  final String Function(DateTime) formatBookingApprovalDeadline;

  @override
  Widget build(BuildContext context) {
    final status = CustomerBookingController.bookingStatus(booking);
    final normalizedStatus = status.toLowerCase();
    final canDeleteCancelledBooking =
        normalizedStatus == 'cancelled' &&
        booking.paidAmount <= 0 &&
        booking.paymentRefundStatus.toLowerCase() != 'pending';
    final isFinishedBooking = const {
      'finished',
      'done',
      'completed',
    }.contains(normalizedStatus);
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);
    final paidAmount = booking.paidAmount;
    final paymentStatus = booking.paymentStatus.toLowerCase();
    final isCashOnArrival = booking.paymentMethod == 'cash_on_arrival';
    final awaitingApprovalPayment =
        CustomerBookingController.awaitingApprovalPayment(booking);
    final paymentDeadline = DateTime.tryParse(booking.paymentDueAt);
    final remainingBalance = (total - paidAmount).clamp(0, total).toDouble();
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final coachName = '${booking['fitnessCoachName'] ?? ''}';
    final coachDurationMonths = int.tryParse(
      '${booking['fitnessCoachDurationMonths'] ?? ''}',
    );
    final isEvent = '${booking['businessType']}'.toLowerCase() == 'event';
    final eventType = '${booking['eventType'] ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BookingGallery(images: _imageUrls(booking)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${booking['venueName'] ?? 'Venue'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  localize: true,
                ),
              ),
              const SizedBox(width: 6),
              _statusPill(status, awaitingPayment: awaitingApprovalPayment),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            _statusGuidance(status, awaitingPayment: awaitingApprovalPayment),
            localize: true,
            style: TextStyle(
              color: _statusColor(
                status,
                awaitingPayment: awaitingApprovalPayment,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            _scheduleLabel(booking),
            localize: true,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            '${fitnessPlanType.isNotEmpty
                ? 'First visit'
                : isEvent
                ? '${booking['players']} guests'
                : '${booking['players']} players'} · '
            '${booking['paymentMethod']}',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
            localize: true,
          ),
          if (isEvent && eventType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              'Event: $eventType',
              localize: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
          if (fitnessPlanType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              '${booking['fitnessCategory']} · ${booking['fitnessPlanType']}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
              localize: true,
            ),
            AppText(
              'Plan duration: ${_fitnessPlanDuration(fitnessPlanType)}',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
              localize: true,
            ),
            AppText(
              coachName.isEmpty
                  ? 'Plan: \u{20B1} ${_amount(booking['fitnessPlanPrice']).toStringAsFixed(2)}'
                  : 'Plan: \u{20B1} ${_amount(booking['fitnessPlanPrice']).toStringAsFixed(2)}\n'
                        'Coach: $coachName'
                        '${coachDurationMonths == null ? '' : ' · ${coachDurationMonths == 1 ? '1 month' : '$coachDurationMonths months'}'}'
                        ' · \u{20B1} ${_amount(booking['fitnessCoachPrice']).toStringAsFixed(2)}',
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 6),
          AppText(
            'Total: \u{20B1} ${total.toStringAsFixed(2)}',
            localize: true,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (_amount(booking['extraPlayerCharge']) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppText(
                'Includes extra-player fee: ? '
                '${_amount(booking['extraPlayerCharge']).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
                localize: true,
              ),
            ),
          const SizedBox(height: 6),
          AppText(
            isCashOnArrival && paymentStatus == 'partial'
                ? 'Cash downpayment received: \u{20B1} ${paidAmount.toStringAsFixed(2)}'
                : isCashOnArrival && paymentStatus != 'paid'
                ? awaitingApprovalPayment
                      ? 'Cash downpayment due before the payment deadline: \u{20B1} ${downpayment.toStringAsFixed(2)}'
                      : 'Cash downpayment due at venue: \u{20B1} ${downpayment.toStringAsFixed(2)}'
                : paymentStatus == 'paid'
                ? 'Amount paid: \u{20B1} ${paidAmount.toStringAsFixed(2)}'
                : '${fitnessPlanType.isNotEmpty ? 'One-time plan total' : 'Amount due'}: ? '
                      '${total.toStringAsFixed(2)}',
            localize: true,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (isCashOnArrival && paymentStatus != 'paid')
            AppText(
              paymentStatus == 'partial'
                  ? 'Remaining cash balance due on arrival: \u{20B1} ${remainingBalance.toStringAsFixed(2)}'
                  : 'Remaining cash balance after downpayment: ? '
                        '${(total - downpayment).clamp(0, total).toStringAsFixed(2)}',
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          if (awaitingApprovalPayment && paymentDeadline != null) ...[
            const SizedBox(height: 10),
            AppText(
              'Payment deadline: ${formatBookingApprovalDeadline(paymentDeadline)}',
              style: TextStyle(
                color: AppColors.errorText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('customer-booking-pay-${booking.id}'),
                onPressed: booking.id == null
                    ? null
                    : () => onPayBookingPrototype(booking),
                icon: const Icon(Icons.credit_card_rounded, size: 18),
                label: const AppText('Pay now (test payment)', localize: true),
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              'Prototype only — no real payment is processed.',
              localize: true,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          AppText(
            'Venue information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
          _venueDetail(
            Icons.person_outline_rounded,
            _labelValue('Venue owner', booking['ownerName']),
          ),
          _venueDetail(Icons.location_on_outlined, booking['address']),
          _venueDetail(
            Icons.sports_rounded,
            _labelValue(
              fitnessPlanType.isNotEmpty ? 'Fitness category' : 'Sport',
              booking['sportType'] ?? booking['category'],
            ),
          ),
          if (fitnessPlanType.isEmpty)
            _venueDetail(
              Icons.grid_view_rounded,
              _labelValue(
                'Booked area',
                booking['occupiesFullStudio'] == true
                    ? 'Whole studio'
                    : booking.slotNumbers.length > 1
                    ? 'Slots ${booking.slotNumbers.join(', ')}'
                    : 'Slot ${booking.slotNumbers.isNotEmpty ? booking.slotNumbers.first : booking['slotNumber'] ?? '—'}',
              ),
            ),
          _venueDetail(
            Icons.business_center_outlined,
            _labelValue('Type', booking['facilityType']),
          ),
          _venueDetail(
            Icons.grid_3x3,
            _labelValue('Details', booking['details']),
          ),
          _venueDetail(
            Icons.access_time,
            _labelValue('Hours', booking['hours']),
          ),
          _venueDetail(
            Icons.check_circle_outline,
            _labelValue('Availability', booking['availability']),
          ),
          const SizedBox(height: 6),
          _bookingField(
            'Rate',
            '\u{20B1} ${_amount(booking['pricePerHour'] ?? booking['venuePricePerHour']).toStringAsFixed(2)} / hr',
          ),
          const SizedBox(height: 6),
          AppText(
            'Booking information you entered',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
          _bookingField('Date', booking['date']),
          if (isEvent)
            _bookingField(
              'Venue hours',
              '${_formatTime(booking['startTime'])} - '
                  '${_endTime(booking['startTime'], _amount(booking['durationHours'])) ?? '—'}',
            )
          else ...[
            _bookingField('Start time', _formatTime(booking['startTime'])),
            _bookingField(
              fitnessPlanType.isNotEmpty ? 'First visit session' : 'Duration',
              '${_amount(booking['durationHours']).toStringAsFixed(0)} hour(s)',
            ),
          ],
          if (fitnessPlanType.isNotEmpty)
            _bookingField(
              'Plan duration',
              _fitnessPlanDuration(fitnessPlanType),
            ),
          _bookingField('Players', booking['players']),
          _bookingField('Payment method', booking['paymentMethod']),
          if (booking.checkedInAt case final checkedInAt?)
            _bookingField('Venue arrival', 'Checked in · $checkedInAt')
          else if (status.toLowerCase() == 'approved')
            _bookingField('Venue arrival', 'Not checked in yet'),
          if (isFinishedBooking || canDeleteCancelledBooking) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isFinishedBooking && booking.id != null) ...[
                  Expanded(
                    child: booking.reviewId == null
                        ? OutlinedButton.icon(
                            onPressed: () => onReviewBooking(
                              booking,
                              closeDetailsOnSubmit: true,
                            ),
                            icon: const Icon(
                              Icons.star_outline_rounded,
                              size: 16,
                            ),
                            label: const AppText('Review', localize: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentForeground,
                              side: BorderSide(
                                color: AppColors.accentForeground.withValues(
                                  alpha: .55,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.star_rounded, size: 16),
                            label: const AppText('Reviewed', localize: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentForeground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('customer-booking-delete-${booking.id}'),
                    onPressed: () => onDeleteBooking(booking),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const AppText('Delete', localize: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorText,
                      side: BorderSide(color: AppColors.errorText),
                      padding: AppSpacing.buttonPadding,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _statusPill(String status, {bool awaitingPayment = false}) {
    final color = _statusColor(status, awaitingPayment: awaitingPayment);
    return Container(
      key: ValueKey('booking-status-pill-${status.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        _statusLabel(status, awaitingPayment: awaitingPayment),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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

  String _labelValue(String label, dynamic value) {
    final text = '$value'.trim();
    return value == null || text.isEmpty || text == 'null'
        ? ''
        : '$label: $text';
  }

  Widget _bookingField(String label, dynamic value) {
    final text = '$value'.trim();
    if (value == null || text.isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: AppText(
              label,
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: AppText(
              text,
              localize: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scheduleLabel(Booking booking) {
    final date = '${booking['date'] ?? ''}';
    final start = _formatTime(booking['startTime']);
    final duration = _amount(booking['durationHours']);
    final end = _endTime(booking['startTime'], duration);
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    if (isEvent) {
      return end == null ? '$date · $start' : '$date · $start - $end';
    }
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final sessionLabel = fitnessPlanType.isNotEmpty
        ? 'First visit session'
        : 'Duration';
    if (end == null) {
      return '$date · $start · $sessionLabel: '
          '${duration.toStringAsFixed(0)} hour(s)';
    }
    return '$date · $start - $end · $sessionLabel: '
        '${duration.toStringAsFixed(0)} hour(s)';
  }

  String _fitnessPlanDuration(String planType) => switch (planType) {
    'monthly' => '1 month',
    'yearly' => '1 year',
    'session' => '1 session',
    _ => planType,
  };

  String _formatTime(dynamic value) {
    final raw = '$value'.trim();
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    return _clockLabel(hour, minute);
  }

  String? _endTime(dynamic value, double duration) {
    final parts = '$value'.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || duration <= 0) return null;
    final end = DateTime(
      2024,
      1,
      1,
      hour,
      minute,
    ).add(Duration(minutes: (duration * 60).round()));
    return _clockLabel(end.hour % 24, end.minute);
  }

  String _clockLabel(int hour, int minute) {
    final normalizedHour = hour % 24;
    final period = normalizedHour >= 12 ? 'PM' : 'AM';
    final displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  double _amount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
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
