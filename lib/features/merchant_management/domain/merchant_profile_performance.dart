import '../../../core/booking_status.dart';

class MerchantProfilePerformance {
  factory MerchantProfilePerformance.calculate({
    required List<Map<String, dynamic>> bookings,
    required String period,
    required DateTime now,
  }) {
    final todayBookings = bookings.where((booking) {
      if (BookingStatusParser.isCancelled(booking['status'])) return false;
      final date = _bookingDate(booking);
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    final periodBookings = _periodBookings(bookings, period, now);
    final confirmedRevenue = periodBookings
        .where((booking) => BookingStatusParser.isConfirmed(booking['status']))
        .fold<double>(0, (total, booking) => total + _number(booking['total']));
    final estimatedPaidAmount = periodBookings.fold<double>(
      0,
      (total, booking) => total + _bookingAmountReceived(booking),
    );

    return MerchantProfilePerformance._(
      todayBookings: todayBookings,
      periodBookings: periodBookings,
      confirmedRevenue: confirmedRevenue,
      estimatedPaidAmount: estimatedPaidAmount,
      todayPendingCount: todayBookings
          .where((booking) => BookingStatusParser.isPending(booking['status']))
          .length,
      todayParticipantCount: todayBookings.fold<int>(
        0,
        (total, booking) => total + _count(booking['players']),
      ),
    );
  }

  const MerchantProfilePerformance._({
    required this.todayBookings,
    required this.periodBookings,
    required this.confirmedRevenue,
    required this.estimatedPaidAmount,
    required this.todayPendingCount,
    required this.todayParticipantCount,
  });

  final List<Map<String, dynamic>> todayBookings;
  final List<Map<String, dynamic>> periodBookings;
  final double confirmedRevenue;
  final double estimatedPaidAmount;
  final int todayPendingCount;
  final int todayParticipantCount;

  static List<Map<String, dynamic>> _periodBookings(
    List<Map<String, dynamic>> bookings,
    String period,
    DateTime now,
  ) {
    if (period == 'All time') return bookings;

    final days = switch (period) {
      '7 days' => 7,
      '30 days' => 30,
      _ => 1,
    };
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day);
    return bookings.where((booking) {
      final date = _bookingDate(booking);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  static DateTime? _bookingDate(Map<String, dynamic> booking) {
    final value = booking['date'] ?? booking['bookingDate'];
    return value is DateTime ? value : DateTime.tryParse('$value');
  }

  static double _bookingAmountReceived(Map<String, dynamic> booking) {
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    final paidAmount = booking['paidAmount'];
    if (paidAmount != null) {
      final amount = _number(paidAmount);
      if (amount > 0 || paymentStatus != 'paid') return amount;
    }
    if (paymentStatus == 'paid') return _number(booking['total']);
    return 0;
  }

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _count(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
