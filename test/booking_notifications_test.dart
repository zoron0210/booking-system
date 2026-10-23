import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/booking_notifications.dart';

void main() {
  group('parseBookingReminderStart', () {
    test('parses SQL date and time values', () {
      final start = parseBookingReminderStart('2026-10-22', '09:30:15');

      expect(start, DateTime(2026, 10, 22, 9, 30, 15));
    });

    test('keeps the SQL calendar date when serialized as an ISO timestamp', () {
      final start = parseBookingReminderStart(
        '2026-10-22T00:00:00.000Z',
        '09:30:00',
      );

      expect(start, DateTime(2026, 10, 22, 9, 30));
    });

    test('rejects invalid dates and times', () {
      expect(parseBookingReminderStart('2026-02-30', '09:30:00'), isNull);
      expect(parseBookingReminderStart('2026-10-22', '25:30:00'), isNull);
      expect(parseBookingReminderStart(null, '09:30:00'), isNull);
    });
  });
}
