import 'dart:convert';

class BookingNotificationDestination {
  const BookingNotificationDestination.booking(this.bookingId)
    : matchmakingLobbyId = null;

  const BookingNotificationDestination.match(this.matchmakingLobbyId)
    : bookingId = null;

  final int? bookingId;
  final int? matchmakingLobbyId;

  static BookingNotificationDestination? fromData(Map<String, dynamic> data) {
    final bookingId = _positiveInt(data['bookingId']);
    final lobbyId = _positiveInt(data['matchmakingLobbyId']);
    if (lobbyId != null) {
      return BookingNotificationDestination.match(lobbyId);
    }
    if (bookingId != null) {
      return BookingNotificationDestination.booking(bookingId);
    }
    return null;
  }

  static BookingNotificationDestination? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return fromData({
        for (final entry in decoded.entries)
          if (entry.key is String) entry.key as String: entry.value,
      });
    } on FormatException {
      return null;
    }
  }

  static int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
