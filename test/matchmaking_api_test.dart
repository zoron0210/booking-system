import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/bookings/data/matchmaking_api.dart';

void main() {
  test('loads typed lobbies with the requested filters', () async {
    http.Request? captured;
    final api = AuthApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'lobbies': [
              {
                'id': 12,
                'hostUserId': 4,
                'venueId': 8,
                'venueName': 'North Court',
                'venueAddress': 'Main Street',
                'venueImageUrls': ['https://example.test/court.jpg'],
                'venueRating': '4.8',
                'venueReviewCount': 12,
                'sportType': 'Badminton',
                'slotNumber': 2,
                'matchDate': '2030-04-12',
                'startTime': '18:30',
                'durationHours': 1.5,
                'totalPrice': '240.00',
                'hostShareAmount': '120.00',
                'opponentShareAmount': '120.00',
                'skillLevel': 'intermediate',
                'opponentCriteria': 'Bring rackets',
                'status': 'open',
                'hostFirstName': 'Host',
                'hostAvatarUrl': 'https://example.test/host.jpg',
                'requestStatus': null,
                'venueLatitude': '14.5',
                'venueLongitude': '121.0',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final lobbies = await MatchmakingApi(api).getLobbies(
      token: 'test-token',
      sport: 'Badminton',
      date: '2030-04-12',
      venueId: 8,
    );

    expect(captured?.url.path, '/api/matchmaking/lobbies');
    expect(captured?.url.queryParameters['sport'], 'Badminton');
    expect(captured?.url.queryParameters['date'], '2030-04-12');
    expect(captured?.url.queryParameters['venueId'], '8');
    expect(lobbies, hasLength(1));
    expect(lobbies.single.venueName, 'North Court');
    expect(lobbies.single.slotNumber, 2);
    expect(lobbies.single.opponentShareAmount, 120);
    expect(lobbies.single.venueReviewCount, 12);
    expect(lobbies.single.latitude, 14.5);
  });

  test('loads paginated lobby pages with cursor metadata', () async {
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/matchmaking/lobbies');
        expect(request.url.queryParameters['limit'], '20');
        return http.Response(
          jsonEncode({
            'lobbies': [
              {
                'id': 12,
                'hostUserId': 4,
                'venueId': 8,
                'venueName': 'North Court',
                'venueAddress': 'Main Street',
                'venueImageUrls': ['https://example.test/court.jpg'],
                'venueRating': '4.8',
                'venueReviewCount': 12,
                'sportType': 'Badminton',
                'slotNumber': 2,
                'matchDate': '2030-04-12',
                'startTime': '18:30',
                'durationHours': 1.5,
                'totalPrice': '240.00',
                'hostShareAmount': '120.00',
                'opponentShareAmount': '120.00',
                'skillLevel': 'intermediate',
                'status': 'open',
                'hostFirstName': 'Host',
                'hostAvatarUrl': 'https://example.test/host.jpg',
                'requestStatus': null,
              },
            ],
            'nextCursor': '12',
            'hasMore': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final page = await MatchmakingApi(api)
        .getLobbiesPage(token: 'test-token', sport: 'Badminton', limit: 20);

    expect(page.lobbies.single.id, 12);
    expect(page.nextCursor, '12');
    expect(page.hasMore, isTrue);
  });

  test('loads a notification-linked public lobby by ID', () async {
    http.Request? captured;
    final api = AuthApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'lobbies': [], 'nextCursor': null, 'hasMore': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await MatchmakingApi(api)
        .getLobbiesPage(token: 'test-token', lobbyId: 91, limit: 1);

    expect(captured?.url.queryParameters['lobbyId'], '91');
    expect(captured?.url.queryParameters['limit'], '1');
  });

  test('creates a lobby and returns its ID', () async {
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/matchmaking/lobbies');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['venueId'], 8);
        expect(body['slotNumber'], 2);
        expect(body['durationHours'], 1.5);
        expect(body['paymentMethod'], 'online');
        expect(body['paymentPolicy'], 'split_remaining');
        return http.Response(
          jsonEncode({'lobbyId': 31}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final lobbyId = await MatchmakingApi(api).createLobby(
      token: 'test-token',
      venueId: 8,
      slotNumber: 2,
      sportType: 'Badminton',
      matchDate: '2030-04-12',
      startTime: '18:30',
      durationHours: 1.5,
      skillLevel: 'open',
      paymentMethod: 'online',
      paymentPolicy: 'split_remaining',
    );

    expect(lobbyId, 31);
  });

  test('loads booked venue slots for the requested date', () async {
    http.Request? captured;
    final api = AuthApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'bookings': [
              {
                'startTime': '18:00:00',
                'durationHours': 1,
                'slotNumber': 2,
                'status': 'matchmaking_open',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final bookings = await MatchmakingApi(api).getBookingAvailability(
      token: 'test-token',
      venueId: 8,
      date: '2030-04-12',
    );

    expect(captured?.url.path, '/api/bookings/availability');
    expect(captured?.url.queryParameters, {
      'venueId': '8',
      'date': '2030-04-12',
    });
    expect(bookings.single['slotNumber'], 2);
    expect(bookings.single['status'], 'matchmaking_open');
  });

  test(
    'starts opponent-share checkout with the matchmaking payment type',
    () async {
      final api = AuthApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/payments/paymongo/checkout');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['bookingId'], 52);
          expect(body['paymentMethod'], 'gcash');
          expect(body['paymentType'], 'matchmaking_opponent_share');
          return http.Response(
            jsonEncode({
              'checkoutUrl': 'https://checkout.paymongo.com/checkout',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final checkout = await MatchmakingApi(api).createOpponentShareCheckout(
        token: 'test-token',
        bookingId: 52,
        paymentMethod: 'gcash',
      );

      expect(checkout.host, 'checkout.paymongo.com');
    },
  );

  test(
    'starts host-balance checkout with the matchmaking payment type',
    () async {
      final api = AuthApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/payments/paymongo/checkout');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['bookingId'], 52);
          expect(body['paymentMethod'], 'paymaya');
          expect(body['paymentType'], 'matchmaking_host_balance');
          return http.Response(
            jsonEncode({
              'checkoutUrl': 'https://checkout.paymongo.com/checkout',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final checkout = await MatchmakingApi(api).createHostBalanceCheckout(
        token: 'test-token',
        bookingId: 52,
        paymentMethod: 'paymaya',
      );

      expect(checkout.host, 'checkout.paymongo.com');
    },
  );

  test('rejects non-PayMongo matchmaking checkout URLs', () async {
    final api = AuthApi(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({'checkoutUrl': 'http://checkout.paymongo.com/checkout'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      MatchmakingApi(api).createHostDownpaymentCheckout(
        token: 'test-token',
        bookingId: 52,
        paymentMethod: 'gcash',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'sends merchant matchmaking decisions to the approval endpoint',
    () async {
      final api = AuthApi(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/matchmaking/lobbies/31/merchant-approve',
          );
          expect(request.headers['authorization'], 'Bearer test-token');
          return http.Response('{}', 200);
        }),
      );

      await MatchmakingApi(
        api,
      ).decideMerchantRequest(token: 'test-token', lobbyId: 31, approve: true);
    },
  );
}
