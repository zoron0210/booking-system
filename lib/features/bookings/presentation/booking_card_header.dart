import 'package:flutter/material.dart';

import '../../../app_design_system.dart';
import '../../../app_text.dart';
import '../../../features/bookings/domain/booking.dart';

class BookingCardHeader extends StatelessWidget {
  const BookingCardHeader({
    super.key,
    required this.booking,
    required this.status,
    required this.canPayBookingPrototype,
    required this.statusColor,
    required this.statusGuidance,
    required this.statusLabel,
    required this.onCancel,
    required this.onDetails,
    required this.approvalDeadline,
    required this.paymentDeadline,
    required this.paymentRefundGuidance,
    required this.prototypePayableAmount,
    required this.formatBookingApprovalDeadline,
  });

  final Booking booking;
  final String status;
  final bool canPayBookingPrototype;
  final Color Function(String status, {bool awaitingPayment}) statusColor;
  final String Function(String status, {bool awaitingPayment}) statusGuidance;
  final String Function(String status, {bool awaitingPayment}) statusLabel;
  final VoidCallback? onCancel;
  final VoidCallback onDetails;
  final DateTime? approvalDeadline;
  final DateTime? paymentDeadline;
  final String Function(String status) paymentRefundGuidance;
  final double Function(Booking booking) prototypePayableAmount;
  final String Function(DateTime?) formatBookingApprovalDeadline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppText(
                '${booking['venueName'] ?? 'Venue'}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                localize: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor(status, awaitingPayment: canPayBookingPrototype)
                    .withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppText(
                statusLabel(status, awaitingPayment: canPayBookingPrototype),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: statusColor(
                    status,
                    awaitingPayment: canPayBookingPrototype,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          statusGuidance(status, awaitingPayment: canPayBookingPrototype),
          localize: true,
          key: ValueKey('booking-status-guidance-$status'),
          style: TextStyle(
            color: statusColor(
              status,
              awaitingPayment: canPayBookingPrototype,
            ),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (status.toLowerCase() == 'pending' && approvalDeadline != null) ...[
          const SizedBox(height: 4),
          AppText(
            'Request deadline: ${formatBookingApprovalDeadline(approvalDeadline)}',
            key: ValueKey('customer-booking-approval-deadline-${booking.id}'),
            style: TextStyle(
              color: AppColors.errorText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (status.toLowerCase() == 'cancelled' &&
            booking.paymentRefundStatus != 'not_requested') ...[
          const SizedBox(height: 6),
          AppText(
            paymentRefundGuidance(booking.paymentRefundStatus),
            localize: true,
            style: TextStyle(
              color: booking.paymentRefundStatus == 'failed'
                  ? AppColors.errorText
                  : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
        if (canPayBookingPrototype) ...[
          const SizedBox(height: 6),
          AppText(
            'Payment due: \u{20B1} ${prototypePayableAmount(booking).toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (paymentDeadline != null)
            AppText(
              'Pay by ${formatBookingApprovalDeadline(paymentDeadline)}',
              key: ValueKey('customer-booking-payment-deadline-${booking.id}'),
              style: TextStyle(
                color: AppColors.errorText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            if (status.toLowerCase() == 'pending' ||
                status.toLowerCase() == 'approved') ...[
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('customer-booking-cancel-${booking.id}'),
                  onPressed: onCancel,
                  icon: const Icon(Icons.event_busy_outlined, size: 16),
                  label: const AppText('Cancel', localize: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorText,
                    side: BorderSide(color: AppColors.errorText),
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
                key: ValueKey('customer-booking-details-${booking.id}'),
                onPressed: onDetails,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const AppText('Details', localize: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: BorderSide(color: AppColors.border),
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
          ],
        ),
      ],
    );
  }
}
