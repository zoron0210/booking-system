import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/notifications/domain/booking_notification_destination.dart';

void main() {
  test('booking notification opens its booking reference', () {
    final destination = BookingNotificationDestination.fromData({
      'type': 'booking',
      'bookingId': '54',
    });

    expect(destination?.bookingId, 54);
    expect(destination?.matchmakingLobbyId, isNull);
  });

  test(
    'match notification opens its lobby rather than the related booking',
    () {
      final destination = BookingNotificationDestination.fromPayload(
        '{"type":"matchmaking","bookingId":"54","matchmakingLobbyId":"91"}',
      );

      expect(destination?.bookingId, isNull);
      expect(destination?.matchmakingLobbyId, 91);
    },
  );

  test('invalid notification payloads have no destination', () {
    expect(BookingNotificationDestination.fromPayload('not-json'), isNull);
    expect(BookingNotificationDestination.fromData({'bookingId': -1}), isNull);
  });
}
