import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/bookings/domain/matchmaking_availability.dart';

void main() {
  test('availability respects four independent sport slots and overlaps', () {
    final available = availableMatchmakingSlots(
      bookings: [
        {
          'startTime': '18:00:00',
          'durationHours': 1,
          'slotNumber': 2,
          'status': 'approved',
        },
        {
          'startTime': '19:00:00',
          'durationHours': 1,
          'slotNumber': 3,
          'status': 'pending',
        },
        {
          'startTime': '18:00:00',
          'durationHours': 1,
          'slotNumber': 4,
          'status': 'cancelled',
        },
      ],
      startTime: '18:30',
      durationHours: 1,
      slotCount: 4,
      fullCourt: false,
    );

    expect(available, [1, 4]);
  });

  test('full court selection is unavailable if any court is occupied', () {
    final available = availableMatchmakingSlots(
      bookings: [
        {
          'startTime': '18:00:00',
          'durationHours': 1,
          'slotNumber': 3,
          'status': 'matchmaking_pending_merchant',
        },
      ],
      startTime: '18:30',
      durationHours: 1,
      slotCount: 4,
      fullCourt: true,
    );

    expect(available, isEmpty);
  });

  test('an existing whole-court booking blocks each independent slot', () {
    final available = availableMatchmakingSlots(
      bookings: [
        {
          'startTime': '18:00:00',
          'durationHours': 1,
          'occupiesFullStudio': 1,
          'slotNumber': 1,
          'status': 'approved',
        },
      ],
      startTime: '18:30',
      durationHours: 1,
      slotCount: 4,
      fullCourt: false,
    );

    expect(available, isEmpty);
  });

  test(
    'touching bookings do not overlap and malformed active rows fail closed',
    () {
      final available = availableMatchmakingSlots(
        bookings: [
          {
            'startTime': '17:00:00',
            'durationHours': 1,
            'slotNumber': 1,
            'status': 'approved',
          },
        ],
        startTime: '18:00',
        durationHours: 1,
        slotCount: 2,
        fullCourt: false,
      );
      expect(available, [1, 2]);

      expect(
        availableMatchmakingSlots(
          bookings: [
            {'status': 'approved', 'slotNumber': 1},
          ],
          startTime: '18:00',
          durationHours: 1,
          slotCount: 2,
          fullCourt: false,
        ),
        isEmpty,
      );
    },
  );
}
