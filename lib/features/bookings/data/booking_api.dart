import 'dart:math';

import 'package:myapp/core/api_response.dart';
import 'package:myapp/core/api_transport.dart';
import 'package:myapp/features/bookings/domain/booking.dart';

final Random _idempotencyRandom = Random.secure();

String newBookingIdempotencyKey() => List.generate(
  32,
  (_) => _idempotencyRandom.nextInt(16).toRadixString(16),
).join();

class BookingApi {
  const BookingApi(this._api);

  final ApiTransport _api;

  Future<Map<String, dynamic>> createBooking({
    required String token,
    required String idempotencyKey,
    required int venueId,
    required String date,
    required String startTime,
    required double durationHours,
    required int players,
    required String paymentMethod,
    String sportType = '',
    int slotNumber = 1,
    List<int>? slotNumbers,
    String fitnessPlanType = '',
    String fitnessCoachName = '',
    int fitnessCoachDurationMonths = 0,
    String eventType = '',
  }) => _api.request(
    'POST',
    '/api/bookings',
    body: {
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      'durationHours': durationHours,
      'players': players,
      'paymentMethod': paymentMethod,
      'sportType': sportType,
      'slotNumber': slotNumbers != null && slotNumbers.isNotEmpty
          ? slotNumbers.first
          : slotNumber,
      ...?slotNumbers == null ? null : {'slotNumbers': slotNumbers},
      'fitnessPlanType': fitnessPlanType,
      'fitnessCoachName': fitnessCoachName,
      'fitnessCoachDurationMonths': fitnessCoachDurationMonths,
      'eventType': eventType,
    },
    headers: _api.authHeadersForToken(
      token,
      extra: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> customerBookings(
    String token, {
    String? businessType,
  }) async {
    final path = businessType == null || businessType.trim().isEmpty
        ? '/api/bookings'
        : '/api/bookings?businessType=${Uri.encodeQueryComponent(businessType.trim())}';
    final response = await _api.request(
      'GET',
      path,
      headers: _api.authHeadersForToken(token),
    );
    return asMapList(response['bookings'] ?? response['data']);
  }

  Future<Map<String, dynamic>> merchantVenueCheckInCode({
    required String token,
    required int venueId,
  }) => _api.request(
    'GET',
    '/api/merchant/businesses/$venueId/check-in-code',
    headers: _api.authHeadersForToken(token),
  );

  Future<Map<String, dynamic>> recordBookingCheckIn({
    required String token,
    required String qrCode,
  }) => _api.request(
    'POST',
    '/api/bookings/check-in',
    body: {'qrCode': qrCode},
    headers: _api.authHeadersForToken(
      token,
      extra: {'Content-Type': 'application/json'},
    ),
  );

  Future<void> deleteCustomerBooking({
    required String token,
    required int bookingId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/bookings/$bookingId',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<Map<String, dynamic>> cancelCustomerBooking({
    required String token,
    required int bookingId,
  }) => _api.request(
    'PATCH',
    '/api/bookings/$bookingId/cancel',
    headers: _api.authHeadersForToken(token),
  );

  Future<List<Map<String, dynamic>>> fitnessBookingAttendance(
    String token,
    int bookingId,
  ) async {
    final response = await _api.request(
      'GET',
      '/api/bookings/$bookingId/attendance',
      headers: _api.authHeadersForToken(token),
    );
    return asMapList(response['attendance'] ?? response['data']);
  }

  Future<void> setFitnessBookingAttendance({
    required String token,
    required int bookingId,
    required String date,
    required String status,
  }) async {
    await _api.request(
      'PUT',
      '/api/bookings/$bookingId/attendance/${Uri.encodeComponent(date)}',
      body: {'status': status},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> clearFitnessBookingAttendance({
    required String token,
    required int bookingId,
    required String date,
  }) async {
    await _api.request(
      'DELETE',
      '/api/bookings/$bookingId/attendance/${Uri.encodeComponent(date)}',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<List<Booking>> customerBookingModels(
    String token, {
    String? businessType,
  }) async {
    final response = await customerBookings(token, businessType: businessType);
    return response.map(Booking.fromJson).toList();
  }

  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) => _api.request(
    'POST',
    '/api/payments/paymongo/checkout',
    body: {'bookingId': bookingId, 'paymentMethod': paymentMethod},
    headers: _api.authHeadersForToken(
      token,
      extra: {'Content-Type': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> recordPrototypeBookingPayment({
    required String token,
    required int bookingId,
    required String provider,
  }) => _api.request(
    'POST',
    '/api/bookings/$bookingId/prototype-payment',
    body: {'paymentMethod': 'prototype_card', 'provider': provider},
    headers: _api.authHeadersForToken(
      token,
      extra: {'Content-Type': 'application/json'},
    ),
  );

  Future<bool> payMongoPaymentsEnabled(String token) async {
    final response = await _api.request(
      'GET',
      '/api/payments/paymongo/config',
      headers: _api.authHeadersForToken(token),
    );
    return response['onlinePaymentsEnabled'] == true;
  }

  Future<List<Map<String, dynamic>>> bookingAvailability({
    required String token,
    required int venueId,
    required String date,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/bookings/availability?venueId=$venueId&date=${Uri.encodeQueryComponent(date)}',
      headers: _api.authHeadersForToken(token),
    );
    return asMapList(response['bookings'] ?? response['data']);
  }

  Future<List<Map<String, dynamic>>> merchantBookings(String token) async {
    final response = await _api.request(
      'GET',
      '/api/merchant/bookings',
      headers: _api.authHeadersForToken(token),
    );
    return asMapList(response['bookings'] ?? response['data']);
  }

  Future<void> approveBooking({
    required String token,
    required int bookingId,
  }) async {
    await _api.request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/approve',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> declineBooking({
    required String token,
    required int bookingId,
    required String reason,
  }) async {
    await _api.request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/decline',
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
      body: {'reason': reason},
    );
  }

  Future<void> setCashOnArrivalPaymentStatus({
    required String token,
    required int bookingId,
    required String paymentStatus,
  }) async {
    await _api.request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/payment',
      body: {'paymentStatus': paymentStatus},
      headers: _api.authHeadersForToken(
        token,
        extra: const {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> finishBooking({
    required String token,
    required int bookingId,
  }) async {
    await _api.request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/finish',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> deleteCompletedBooking({
    required String token,
    required int bookingId,
  }) async {
    await _api.request(
      'DELETE',
      '/api/merchant/bookings/$bookingId',
      headers: _api.authHeadersForToken(token),
    );
  }
}
