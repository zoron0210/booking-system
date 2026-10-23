import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/booking_status.dart';
import 'package:myapp/features/bookings/domain/booking.dart';
import 'package:myapp/features/bookings/presentation/customer_booking_controller.dart';

void main() {
  group('BookingStatusAnalyzer', () {
    test('treats expired payment as expired status', () {
      final booking = Booking(
        id: 12,
        venue: const Venue(name: 'Court A'),
        status: 'approved',
        paymentStatus: 'unpaid',
        paymentDueAt: '2024-06-01T10:00:00Z',
        paymentExpiredAt: '2024-06-01T10:15:00Z',
      );

      expect(BookingStatusAnalyzer.effectiveStatus(booking), 'expired');
      expect(BookingStatusAnalyzer.isNotificationRelevant(booking), isTrue);
    });

    test('detects approved bookings that still need payment', () {
      final booking = Booking(
        id: 13,
        venue: const Venue(name: 'Court B'),
        status: 'approved',
        paymentStatus: 'unpaid',
        paymentDueAt: '2024-06-02T10:00:00Z',
      );

      expect(BookingStatusAnalyzer.isAwaitingApprovalPayment(booking), isTrue);
      expect(BookingStatusAnalyzer.notificationPriority(booking), 0);
    });

    test('sorts urgent notifications before lower priority bookings', () {
      final first = Booking(
        id: 14,
        venue: const Venue(name: 'Court C'),
        status: 'approved',
        paymentStatus: 'unpaid',
        paymentDueAt: '2024-06-03T10:00:00Z',
        createdAt: '2024-06-03T09:00:00Z',
      );
      final second = Booking(
        id: 15,
        venue: const Venue(name: 'Court D'),
        status: 'finished',
        paymentStatus: 'paid',
        createdAt: '2024-06-03T09:30:00Z',
      );

      expect(
        BookingStatusAnalyzer.compareNotifications(first, second),
        lessThan(0),
      );
      expect(
        BookingStatusAnalyzer.bannerKey(first),
        contains('approved'),
      );
    });

    test('customer booking controller matches venue and booking ids', () {
      final booking = Booking(
        id: 42,
        venue: const Venue(name: 'Riverstone Courts'),
        status: 'approved',
        paymentStatus: 'paid',
        transactionId: 'TX-8675309',
      );

      expect(
        CustomerBookingController.matchesBookingSearch(booking, 'riverstone'),
        isTrue,
      );
      expect(
        CustomerBookingController.matchesBookingSearch(booking, '8675309'),
        isTrue,
      );
      expect(
        CustomerBookingController.matchesBookingSearch(booking, 'BK-42'),
        isTrue,
      );
      expect(
        CustomerBookingController.matchesBookingSearch(booking, 'missing'),
        isFalse,
      );
    });
  });
}
