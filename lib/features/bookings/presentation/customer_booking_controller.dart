import 'package:myapp/core/booking_status.dart';
import 'package:myapp/features/bookings/domain/booking.dart';

class CustomerBookingController {
  const CustomerBookingController();

  static String bookingStatus(Booking booking) =>
      BookingStatusAnalyzer.effectiveStatus(booking);

  static bool awaitingApprovalPayment(Booking booking) =>
      BookingStatusAnalyzer.isAwaitingApprovalPayment(booking);

  static bool isNotificationRelevant(Booking booking) =>
      BookingStatusAnalyzer.isNotificationRelevant(booking);

  static int compareBookingStatusNotifications(Booking first, Booking second) =>
      BookingStatusAnalyzer.compareNotifications(first, second);

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
    final notifications = bookings
        .where(isNotificationRelevant)
        .toList()
      ..sort((first, second) {
        final firstStatus = bookingStatus(first);
        final secondStatus = bookingStatus(second);
        if (firstStatus == 'expired' && secondStatus != 'expired') return -1;
        if (secondStatus == 'expired' && firstStatus != 'expired') return 1;

        final firstIsInactive = {'finished', 'done', 'completed', 'cancelled'}
            .contains(firstStatus);
        final secondIsInactive = {'finished', 'done', 'completed', 'cancelled'}
            .contains(secondStatus);
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
    final requiredAmount = booking.paymentMethod == 'cash_on_arrival'
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
