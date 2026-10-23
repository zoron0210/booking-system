import 'package:flutter/material.dart';

import '../../../app_design_system.dart';
import '../../../app_text.dart';
import '../../../features/bookings/domain/booking.dart';

class BookingStatusBanner extends StatelessWidget {
  const BookingStatusBanner({
    super.key,
    required this.booking,
    required this.status,
    required this.isCompleted,
    required this.isInactive,
    required this.isExpired,
    required this.isAwaitingPayment,
    required this.onRefresh,
    required this.onDismiss,
    required this.prototypePayableAmount,
    required this.formatTime,
  });

  final Booking booking;
  final String status;
  final bool isCompleted;
  final bool isInactive;
  final bool isExpired;
  final bool isAwaitingPayment;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDismiss;
  final double Function(Booking booking) prototypePayableAmount;
  final String Function(dynamic value) formatTime;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isCompleted
        ? const Color(0xFFE7F6EC)
        : isInactive
        ? const Color(0xFFFEE4E2)
        : isAwaitingPayment
        ? const Color(0xFFFFF4E5)
        : AppColors.softStatus;

    final leadingIcon = isCompleted
        ? Icons.check_circle_rounded
        : isInactive
        ? Icons.event_busy_rounded
        : Icons.event_available_rounded;

    final contentColor = isCompleted
        ? AppColors.success
        : isInactive
        ? AppColors.errorText
        : isAwaitingPayment
        ? const Color(0xFFB85C00)
        : AppColors.accentForeground;

    return MaterialBanner(
      backgroundColor: backgroundColor,
      leading: Icon(leadingIcon, color: contentColor),
      content: InkWell(
        key: const ValueKey('booking-status-banner-content'),
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                isExpired
                    ? booking.paymentExpiredAt.isNotEmpty
                          ? 'Your reservation at ${booking['venueName'] ?? 'your venue'} expired because payment was not received before the payment deadline.'
                          : 'Your booking request at ${booking['venueName'] ?? 'your venue'} has expired.'
                    : isCompleted || isInactive
                    ? 'Booking at ${booking['venueName'] ?? 'your venue'} is ${status.toUpperCase() == 'APPROVED' ? 'Approved' : status}.'
                    : isAwaitingPayment
                    ? 'The venue approved your booking. Pay the required amount of \u{20B1} ${prototypePayableAmount(booking).toStringAsFixed(2)} before the payment deadline using the test payment form, or the reservation will expire.'
                    : 'Booking at ${booking['venueName'] ?? 'your venue'} was approved for ${booking['date']} at ${formatTime(booking['startTime'])}.',
                localize: true,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Column(
                key: const ValueKey('booking-status-banner-references'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppText(
                        'TRANSACTION ID',
                        localize: true,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: AppText(
                          booking.transactionId,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const AppText(
                        'BOOKING REFERENCE',
                        localize: true,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AppText(
                        'BK-${booking.id ?? '—'}',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onRefresh,
          child: const AppText('Refresh', localize: true),
        ),
        TextButton(
          key: const ValueKey('booking-status-banner-dismiss'),
          onPressed: onDismiss,
          child: const AppText('Dismiss', localize: true),
        ),
      ],
    );
  }
}
