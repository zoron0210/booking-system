import '../features/bookings/domain/booking.dart';

enum BookingStatus {
  pending,
  approved,
  confirmed,
  finished,
  completed,
  done,
  cancelled,
  rejected,
  expired,
  unknown,
}

extension BookingStatusX on BookingStatus {
  String get value => switch (this) {
    BookingStatus.pending => 'pending',
    BookingStatus.approved => 'approved',
    BookingStatus.confirmed => 'confirmed',
    BookingStatus.finished => 'finished',
    BookingStatus.completed => 'completed',
    BookingStatus.done => 'done',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.rejected => 'rejected',
    BookingStatus.expired => 'expired',
    BookingStatus.unknown => 'unknown',
  };

  bool get isPending => this == BookingStatus.pending;
  bool get isApproved =>
      this == BookingStatus.approved || this == BookingStatus.confirmed;
  bool get isConfirmed =>
      this == BookingStatus.approved ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.finished ||
      this == BookingStatus.completed ||
      this == BookingStatus.done;
  bool get isCancelled =>
      this == BookingStatus.cancelled ||
      this == BookingStatus.rejected ||
      this == BookingStatus.expired;

  String get displayLabel => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.approved => 'Approved',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.finished => 'Finished',
    BookingStatus.completed => 'Completed',
    BookingStatus.done => 'Done',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.expired => 'Expired',
    BookingStatus.unknown => 'Unknown',
  };
}

class BookingStatusParser {
  const BookingStatusParser();

  static BookingStatus parse(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return switch (normalized) {
      'pending' || 'awaiting_approval' => BookingStatus.pending,
      'approved' => BookingStatus.approved,
      'confirmed' => BookingStatus.confirmed,
      'finished' => BookingStatus.finished,
      'completed' => BookingStatus.completed,
      'done' => BookingStatus.done,
      'cancelled' || 'canceled' => BookingStatus.cancelled,
      'rejected' => BookingStatus.rejected,
      'expired' => BookingStatus.expired,
      _ => BookingStatus.unknown,
    };
  }

  static bool isPending(Object? value) => parse(value).isPending;
  static bool isApproved(Object? value) => parse(value).isApproved;
  static bool isConfirmed(Object? value) => parse(value).isConfirmed;
  static bool isCancelled(Object? value) => parse(value).isCancelled;
  static String label(Object? value) => parse(value).displayLabel;
}

class BookingStatusAnalyzer {
  const BookingStatusAnalyzer();

  static String effectiveStatus(Booking booking) =>
      booking.paymentExpiredAt.isNotEmpty ? 'expired' : booking.status;

  static bool isAwaitingApprovalPayment(Booking booking) =>
      effectiveStatus(booking) == 'approved' &&
      booking.paymentStatus.trim().toLowerCase() == 'unpaid' &&
      booking.paymentDueAt.trim().isNotEmpty;

  static bool isNotificationRelevant(Booking booking) => const {
    'approved',
    'finished',
    'done',
    'completed',
    'expired',
    'cancelled',
  }.contains(effectiveStatus(booking));

  static int notificationPriority(Booking booking) {
    if (isAwaitingApprovalPayment(booking)) return 0;
    return switch (effectiveStatus(booking)) {
      'expired' => 1,
      'cancelled' => 2,
      'approved' => 3,
      _ => 4,
    };
  }

  static int compareNotifications(Booking first, Booking second) {
    final priorityComparison = notificationPriority(first)
        .compareTo(notificationPriority(second));
    if (priorityComparison != 0) return priorityComparison;

    final firstCreated = DateTime.tryParse(first.createdAt);
    final secondCreated = DateTime.tryParse(second.createdAt);
    if (firstCreated == null || secondCreated == null) return 0;
    return secondCreated.compareTo(firstCreated);
  }

  static String bannerKey(Booking booking) {
    final identity =
        booking.id?.toString() ??
        '${booking.venue.id ?? booking.venue.name}_${booking.date}_${booking.startTime}';
    return '${identity}_${effectiveStatus(booking)}_${booking.paymentDueAt}';
  }
}
