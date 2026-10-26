import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/merchant_management/domain/merchant_profile_performance.dart';

void main() {
  final now = DateTime(2026, 10, 26, 9);

  test(
    'today excludes cancelled bookings and counts pending bookings/players',
    () {
      final result = MerchantProfilePerformance.calculate(
        now: now,
        period: 'Today',
        bookings: [
          {
            'date': '2026-10-26',
            'status': 'approved',
            'players': 4,
            'total': 100,
          },
          {
            'bookingDate': DateTime(2026, 10, 26, 16),
            'status': 'awaiting_approval',
            'players': '3',
          },
          {
            'date': '2026-10-26',
            'status': 'cancelled',
            'players': 8,
            'total': 200,
          },
          {'date': '2026-10-25', 'status': 'pending', 'players': 2},
          {'date': 'not-a-date', 'status': 'pending', 'players': 1},
        ],
      );

      expect(result.todayBookings, hasLength(2));
      expect(result.todayPendingCount, 1);
      expect(result.todayParticipantCount, 7);
      expect(result.confirmedRevenue, 100);
    },
  );

  test('selected date windows include their start and end dates', () {
    final bookings = [
      {'date': '2026-10-26', 'status': 'approved'},
      {'date': '2026-10-20', 'status': 'approved'},
      {'date': '2026-10-19', 'status': 'approved'},
      {'date': '2026-09-27', 'status': 'approved'},
      {'date': '2026-09-26', 'status': 'approved'},
      {'date': '2026-10-27', 'status': 'approved'},
      {'date': 'invalid', 'status': 'approved'},
    ];

    final sevenDays = MerchantProfilePerformance.calculate(
      bookings: bookings,
      period: '7 days',
      now: now,
    );
    final thirtyDays = MerchantProfilePerformance.calculate(
      bookings: bookings,
      period: '30 days',
      now: now,
    );
    final allTime = MerchantProfilePerformance.calculate(
      bookings: bookings,
      period: 'All time',
      now: now,
    );

    expect(sevenDays.periodBookings, hasLength(2));
    expect(thirtyDays.periodBookings, hasLength(4));
    expect(allTime.periodBookings, same(bookings));
  });

  test('revenue and paid estimates follow booking/payment statuses', () {
    final result = MerchantProfilePerformance.calculate(
      now: now,
      period: 'Today',
      bookings: [
        {
          'date': '2026-10-26',
          'status': 'approved',
          'total': 100,
          'paidAmount': '40',
          'paymentStatus': 'partial',
        },
        {
          'date': '2026-10-26',
          'status': 'confirmed',
          'total': '60',
          'paymentStatus': 'paid',
        },
        {
          'date': '2026-10-26',
          'status': 'pending',
          'total': 500,
          'paidAmount': 0,
          'paymentStatus': 'unpaid',
        },
        {
          'date': '2026-10-26',
          'status': 'cancelled',
          'total': 300,
          'paymentStatus': 'unpaid',
        },
        {
          'date': '2026-10-25',
          'status': 'approved',
          'total': 200,
          'paymentStatus': 'paid',
        },
      ],
    );

    expect(result.confirmedRevenue, 160);
    expect(result.estimatedPaidAmount, 100);
  });
}
