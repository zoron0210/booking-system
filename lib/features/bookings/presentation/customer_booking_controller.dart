import 'package:myapp/core/booking_status.dart';
import 'package:myapp/features/bookings/domain/booking.dart';

class CustomerBookingController {
  const CustomerBookingController();

  static String bookingStatus(Booking booking) {
    final status = BookingStatusAnalyzer.effectiveStatus(booking);
    if (booking.bookingType != 'matchmaking') return status;
    return switch (status) {
      'matchmaking_pending_merchant' => 'pending',
      'matchmaking_open' => 'approved',
      _ => status,
    };
  }

  static bool awaitingApprovalPayment(Booking booking) =>
      booking.bookingType == 'matchmaking'
      ? bookingStatus(booking) == 'approved' &&
            booking.paymentStatus.trim().toLowerCase() == 'unpaid' &&
            booking.paymentDueAt.trim().isNotEmpty
      : BookingStatusAnalyzer.isAwaitingApprovalPayment(booking);

  static bool isNotificationRelevant(Booking booking) => const {
    'approved',
    'finished',
    'done',
    'completed',
    'expired',
    'cancelled',
  }.contains(bookingStatus(booking));

  static int compareBookingStatusNotifications(Booking first, Booking second) {
    final firstPriority = awaitingApprovalPayment(first) ? 0 : 1;
    final secondPriority = awaitingApprovalPayment(second) ? 0 : 1;
    final priorityComparison = firstPriority.compareTo(secondPriority);
    if (priorityComparison != 0) return priorityComparison;
    return BookingStatusAnalyzer.compareNotifications(first, second);
  }

  static String bookingStatusKey(Booking booking) =>
      BookingStatusAnalyzer.bannerKey(booking);

  static bool matchesBookingSearch(Booking booking, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final searchableValues = [
      '${booking['venueName'] ?? ''}',
      booking.transactionId,
      'BK-${booking.id ?? ''}',
    ];
    return searchableValues.any(
      (value) => value.toLowerCase().contains(normalized),
    );
  }

  static Booking? selectStatusBannerBooking(List<Booking> bookings) {
    final notifications = bookings.where(isNotificationRelevant).toList()
      ..sort((first, second) {
        final firstStatus = bookingStatus(first);
        final secondStatus = bookingStatus(second);
        if (firstStatus == 'expired' && secondStatus != 'expired') return -1;
        if (secondStatus == 'expired' && firstStatus != 'expired') return 1;

        final firstIsInactive = {
          'finished',
          'done',
          'completed',
          'cancelled',
        }.contains(firstStatus);
        final secondIsInactive = {
          'finished',
          'done',
          'completed',
          'cancelled',
        }.contains(secondStatus);
        if (firstIsInactive != secondIsInactive) {
          return firstIsInactive ? -1 : 1;
        }
        return compareBookingStatusNotifications(first, second);
      });

    return notifications.isEmpty ? null : notifications.first;
  }

  static double prototypePayableAmount(Booking booking) {
    final paidAmount = booking.paidAmount;
    final totalAmount = amount(booking['total']);
    final requiredAmount =
        booking.bookingType == 'matchmaking' ||
            booking.paymentMethod == 'cash_on_arrival'
        ? amount(booking['downpayment'])
        : totalAmount;
    return (requiredAmount - paidAmount).clamp(0, requiredAmount).toDouble();
  }

  static double amount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.replaceAll(',', '').trim();
      return double.tryParse(trimmed) ?? 0;
    }
    return 0;
  }
}
