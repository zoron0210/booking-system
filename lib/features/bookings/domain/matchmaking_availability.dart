import 'dart:convert';

const _inactiveBookingStatuses = {
  'cancelled',
  'expired',
  'finished',
  'completed',
  'done',
};

List<int> availableMatchmakingSlots({
  required List<Map<String, dynamic>> bookings,
  required String startTime,
  required double durationHours,
  required int slotCount,
  required bool fullCourt,
}) {
  final startMinutes = _minutes(startTime);
  if (startMinutes == null ||
      !durationHours.isFinite ||
      durationHours <= 0 ||
      slotCount < 1) {
    return const [];
  }
  final endMinutes = startMinutes + (durationHours * 60).round();
  final count = fullCourt ? 1 : slotCount;

  return [
    for (var slot = 1; slot <= count; slot++)
      if (!bookings.any(
        (booking) => _bookingConflicts(
          booking,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          slotNumber: slot,
          fullCourt: fullCourt,
        ),
      ))
        slot,
  ];
}

bool _bookingConflicts(
  Map<String, dynamic> booking, {
  required int startMinutes,
  required int endMinutes,
  required int slotNumber,
  required bool fullCourt,
}) {
  final status = '${booking['status'] ?? ''}'.trim().toLowerCase();
  if (_inactiveBookingStatuses.contains(status)) return false;

  final bookedStart = _minutes(
    '${booking['startTime'] ?? booking['start_time'] ?? ''}',
  );
  final duration = double.tryParse(
    '${booking['durationHours'] ?? booking['duration_hours'] ?? ''}',
  );
  if (bookedStart == null ||
      duration == null ||
      !duration.isFinite ||
      duration <= 0) {
    return true;
  }
  final bookedEnd = bookedStart + (duration * 60).round();
  if (startMinutes >= bookedEnd || endMinutes <= bookedStart) return false;

  final bookingIsFullCourt =
      _isTrue(booking['occupiesFullStudio']) ||
      _isTrue(booking['occupies_full_studio']);
  if (fullCourt || bookingIsFullCourt) return true;

  final rawSlots = booking['slotNumbers'] ?? booking['slot_numbers_json'];
  dynamic slots = rawSlots;
  if (slots is String && slots.trim().isNotEmpty) {
    try {
      slots = jsonDecode(slots);
    } on FormatException {
      return true;
    }
  }
  if (slots is List) {
    final bookingSlots = slots
        .map((value) => int.tryParse('$value'))
        .whereType<int>()
        .toSet();
    return bookingSlots.isEmpty || bookingSlots.contains(slotNumber);
  }

  final bookedSlot = int.tryParse(
    '${booking['slotNumber'] ?? booking['slot_number'] ?? ''}',
  );
  return bookedSlot == null || bookedSlot == slotNumber;
}

int? _minutes(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      hour < 0 ||
      hour > 23 ||
      minute == null ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

bool _isTrue(dynamic value) =>
    value == true || value == 1 || value == '1' || value == 'true';
