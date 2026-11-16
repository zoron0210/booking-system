import 'package:myapp/core/api_transport.dart';
import 'package:myapp/features/bookings/domain/matchmaking_models.dart';

class MatchmakingLobbyPage {
  const MatchmakingLobbyPage({
    required this.lobbies,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<MatchmakingLobby> lobbies;
  final String? nextCursor;
  final bool hasMore;
}

class MatchmakingApi {
  const MatchmakingApi(this._api);

  final ApiTransport _api;

  Future<MatchmakingLobbyPage> getLobbiesPage({
    required String token,
    String? sport,
    String? date,
    int? venueId,
    int? lobbyId,
    int? cursor,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }
    final query = <String, String>{'limit': '$limit'};
    if (sport != null && sport.trim().isNotEmpty) {
      query['sport'] = sport.trim();
    }
    if (date != null && date.trim().isNotEmpty) query['date'] = date.trim();
    if (venueId != null) query['venueId'] = '$venueId';
    if (lobbyId != null) query['lobbyId'] = '$lobbyId';
    if (cursor != null) query['cursor'] = '$cursor';
    final response = await _api.request(
      'GET',
      Uri(path: '/api/matchmaking/lobbies', queryParameters: query).toString(),
      headers: _api.authHeadersForToken(token),
    );
    final values = response['lobbies'];
    if (values is! List) {
      throw const FormatException('The server returned invalid match lobbies.');
    }
    return MatchmakingLobbyPage(
      lobbies: values
          .map((value) {
            if (value is! Map) {
              throw const FormatException(
                'The server returned an invalid match lobby.',
              );
            }
            return MatchmakingLobby.fromJson(Map<String, dynamic>.from(value));
          })
          .toList(growable: false),
      nextCursor: response['nextCursor']?.toString(),
      hasMore: response['hasMore'] == true,
    );
  }

  Future<List<MatchmakingLobby>> getLobbies({
    required String token,
    String? sport,
    String? date,
    int? venueId,
    int? lobbyId,
    int? cursor,
    int limit = 20,
  }) async => (await getLobbiesPage(
    token: token,
    sport: sport,
    date: date,
    venueId: venueId,
    lobbyId: lobbyId,
    cursor: cursor,
    limit: limit,
  )).lobbies;

  Future<List<Map<String, dynamic>>> getBookingAvailability({
    required String token,
    required int venueId,
    required String date,
  }) async {
    final response = await _api.request(
      'GET',
      Uri(
        path: '/api/bookings/availability',
        queryParameters: {'venueId': '$venueId', 'date': date},
      ).toString(),
      headers: _api.authHeadersForToken(token),
    );
    final bookings = response['bookings'];
    if (bookings is! List) {
      throw const FormatException(
        'The server returned invalid venue availability.',
      );
    }
    return bookings
        .map((booking) {
          if (booking is! Map) {
            throw const FormatException(
              'The server returned an invalid venue booking.',
            );
          }
          return Map<String, dynamic>.from(booking);
        })
        .toList(growable: false);
  }

  Future<List<MatchmakingHostRequest>> getHostLobbies({
    required String token,
  }) async {
    final response = await _api.request(
      'GET',
      '/api/matchmaking/host/lobbies',
      headers: _api.authHeadersForToken(token),
    );
    final values = response['lobbies'];
    if (values is! List) {
      throw const FormatException('The server returned invalid host matches.');
    }
    return values
        .map((value) {
          if (value is! Map) {
            throw const FormatException(
              'The server returned an invalid host match.',
            );
          }
          return MatchmakingHostRequest.fromJson(
            Map<String, dynamic>.from(value),
          );
        })
        .toList(growable: false);
  }

  Future<int> createLobby({
    required String token,
    required int venueId,
    required int slotNumber,
    required String sportType,
    required String matchDate,
    required String startTime,
    required double durationHours,
    required String skillLevel,
    required String paymentMethod,
    required String paymentPolicy,
    String? opponentCriteria,
  }) async {
    final response = await _api.request(
      'POST',
      '/api/matchmaking/lobbies',
      body: {
        'venueId': venueId,
        'slotNumber': slotNumber,
        'sportType': sportType,
        'matchDate': matchDate,
        'startTime': startTime,
        'durationHours': durationHours,
        'skillLevel': skillLevel,
        'paymentMethod': paymentMethod,
        'paymentPolicy': paymentPolicy,
        'opponentCriteria': opponentCriteria,
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    final lobbyId = response['lobbyId'];
    if (lobbyId is! num || lobbyId <= 0) {
      throw const FormatException(
        'The server did not return the new match ID.',
      );
    }
    return lobbyId.toInt();
  }

  Future<Uri> createHostDownpaymentCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) async {
    final response = await _api.request(
      'POST',
      '/api/payments/paymongo/checkout',
      body: {
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'paymentType': 'matchmaking_downpayment',
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    return _paymongoCheckoutUri(response['checkoutUrl']);
  }

  Future<Uri> createOpponentShareCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) async {
    final response = await _api.request(
      'POST',
      '/api/payments/paymongo/checkout',
      body: {
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'paymentType': 'matchmaking_opponent_share',
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    return _paymongoCheckoutUri(response['checkoutUrl']);
  }

  Future<Uri> createHostBalanceCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) async {
    final response = await _api.request(
      'POST',
      '/api/payments/paymongo/checkout',
      body: {
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'paymentType': 'matchmaking_host_balance',
      },
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    return _paymongoCheckoutUri(response['checkoutUrl']);
  }

  Future<MatchmakingRequest> joinLobby({
    required String token,
    required int lobbyId,
    String? message,
  }) async {
    final response = await _api.request(
      'POST',
      '/api/matchmaking/lobbies/$lobbyId/join',
      body: {'message': message},
      headers: _api.authHeadersForToken(
        token,
        extra: {'Content-Type': 'application/json'},
      ),
    );
    return MatchmakingRequest.fromJson(response);
  }

  Future<void> acceptRequest({
    required String token,
    required int lobbyId,
    required int requestId,
  }) async {
    await _api.request(
      'POST',
      '/api/matchmaking/lobbies/$lobbyId/requests/$requestId/accept',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> declineRequest({
    required String token,
    required int lobbyId,
    required int requestId,
  }) async {
    await _api.request(
      'POST',
      '/api/matchmaking/lobbies/$lobbyId/requests/$requestId/decline',
      headers: _api.authHeadersForToken(token),
    );
  }

  Future<void> decideMerchantRequest({
    required String token,
    required int lobbyId,
    required bool approve,
  }) async {
    await _api.request(
      'POST',
      '/api/matchmaking/lobbies/$lobbyId/merchant-'
          '${approve ? 'approve' : 'decline'}',
      headers: _api.authHeadersForToken(token),
    );
  }
}

Uri _paymongoCheckoutUri(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'checkout.paymongo.com' ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'The server returned an invalid PayMongo checkout URL.',
    );
  }
  return uri;
}
