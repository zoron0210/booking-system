import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/app_theme.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/bookings/domain/matchmaking_models.dart';
import 'package:myapp/features/bookings/presentation/matchmaking_lobby_list_page.dart';
import 'package:myapp/features/bookings/presentation/widgets/matchmaking_ticket_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lobby model parses server response values', () {
    final lobby = MatchmakingLobby.fromJson({
      'id': 12,
      'hostUserId': 4,
      'venueId': 8,
      'venueName': 'North Court',
      'venueLogoUrl': 'https://example.test/brand.png',
      'venueImageUrls': ['https://example.test/court.jpg'],
      'venueRating': 4.8,
      'venueReviewCount': 12,
      'sportType': 'Badminton',
      'slotNumber': 2,
      'matchDate': '2030-04-12',
      'startTime': '18:30',
      'durationHours': '1.5',
      'totalPrice': '240.00',
      'hostShareAmount': '120.00',
      'opponentShareAmount': '120.00',
      'skillLevel': 'intermediate',
      'hostFirstName': 'Jordan',
      'status': 'open',
    });

    expect(lobby.id, 12);
    expect(lobby.slotNumber, 2);
    expect(lobby.durationHours, 1.5);
    expect(lobby.venueLogoUrl, 'https://example.test/brand.png');
    expect(lobby.requestStatus, isNull);
  });

  test('match search checks venue, sport, host, date, and court details', () {
    final lobby = MatchmakingLobby.fromJson({
      'id': 12,
      'hostUserId': 4,
      'venueId': 8,
      'venueName': 'North Court',
      'venueAddress': 'Main Street',
      'venueReviewCount': 12,
      'sportType': 'Badminton',
      'slotNumber': 2,
      'matchDate': '2030-04-12',
      'startTime': '18:30',
      'durationHours': 1.5,
      'totalPrice': 240,
      'hostShareAmount': 120,
      'opponentShareAmount': 120,
      'skillLevel': 'intermediate',
      'opponentCriteria': 'Bring rackets',
      'status': 'open',
      'hostFirstName': 'Jordan',
    });

    expect(matchmakingLobbyMatchesSearch(lobby, '  north COURT '), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, 'badminton'), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, 'jordan'), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, 'court 2'), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, '2030-04-12'), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, 'match 12'), isTrue);
    expect(matchmakingLobbyMatchesSearch(lobby, 'tennis'), isFalse);
    expect(matchmakingLobbyMatchesSearch(lobby, '  '), isTrue);
  });

  testWidgets(
    'Find Match refreshes on revisit and prioritizes nearby matches',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      FlutterSecureStorage.setMockInitialValues({
        'session_api_token': 'test-token',
      });

      var lobbyRequests = 0;
      final api = AuthApi(
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/api/auth/me':
              return http.Response(
                '{"user":{"id":99}}',
                200,
                headers: {'content-type': 'application/json'},
              );
            case '/api/matchmaking/lobbies':
              lobbyRequests++;
              return http.Response(
                '{"lobbies":['
                '${_lobbyJson(20, latitude: 14.6, longitude: 121.1)},'
                '${_lobbyJson(19, latitude: 14.501, longitude: 121.001)},'
                '${_lobbyJson(21, latitude: null, longitude: null)}'
                ']}',
                200,
                headers: {'content-type': 'application/json'},
              );
            case '/api/matchmaking/host/lobbies':
              return http.Response(
                '{"lobbies":[]}',
                200,
                headers: {'content-type': 'application/json'},
              );
            default:
              return http.Response('{}', 404);
          }
        }),
      );
      final userPosition = Position(
        latitude: 14.5,
        longitude: 121,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );
      var isActive = true;
      late StateSetter updateActive;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateActive = setState;
              return Scaffold(
                body: MatchmakingLobbyListPage(
                  api: api,
                  initialUserPosition: userPosition,
                  isActive: isActive,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lobbyRequests, 1);
      final nearbyTop = tester.getTopLeft(
        find.byKey(const ValueKey('matchmaking-lobby-19')),
      );
      final fartherTop = tester.getTopLeft(
        find.byKey(const ValueKey('matchmaking-lobby-20')),
      );
      final unknownDistanceTop = tester.getTopLeft(
        find.byKey(const ValueKey('matchmaking-lobby-21')),
      );
      expect(nearbyTop.dy, lessThan(fartherTop.dy));
      expect(fartherTop.dy, lessThan(unknownDistanceTop.dy));
      expect(find.text('Distance unavailable'), findsOneWidget);

      updateActive(() => isActive = false);
      await tester.pumpAndSettle();
      updateActive(() => isActive = true);
      await tester.pumpAndSettle();
      expect(lobbyRequests, 2);
    },
  );

  testWidgets('host can accept a pending matchmaking ticket', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: false,
      palette: AppPalette.orange,
    );
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: false,
          accentColor: AppPalette.orange.color,
        ),
        home: Scaffold(
          body: MatchmakingTicketCard(
            ticket: const {
              'requestId': 34,
              'lobbyId': 12,
              'applicantName': 'Jordan Player',
              'sportType': 'Badminton',
              'matchDate': '2030-04-12',
              'startTime': '18:30',
              'skillLevel': 'intermediate',
              'status': 'pending',
            },
            isHost: true,
            onAction: (_, accept) async {
              accepted = accept;
            },
          ),
        ),
      ),
    );

    expect(find.text('Jordan Player'), findsOneWidget);
    expect(find.text('MATCH REQUEST'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
  });

  testWidgets('matched opponent must pay online', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: false,
      palette: AppPalette.orange,
    );
    final methods = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: false,
          accentColor: AppPalette.orange.color,
        ),
        home: Scaffold(
          body: MatchmakingTicketCard(
            ticket: const {
              'requestId': 34,
              'lobbyId': 12,
              'applicantName': 'Jordan Player',
              'sportType': 'Badminton',
              'matchDate': '2030-04-12',
              'startTime': '18:30',
              'skillLevel': 'intermediate',
              'opponentShareAmount': 125,
              'status': 'matched',
              'opponentPaymentStatus': 'unpaid',
            },
            isHost: false,
            onAction: (_, _) async {},
            onOpponentPayment: (_, method) async {
              methods.add(method);
            },
          ),
        ),
      ),
    );

    expect(find.text('Pay Online'), findsOneWidget);
    expect(find.text('Cash on Arrival'), findsNothing);
    await tester.tap(find.text('Pay Online'));
    await tester.pumpAndSettle();
    expect(methods, ['online']);
  });
}

String _lobbyJson(
  int id, {
  required double? latitude,
  required double? longitude,
}) =>
    '{"id":$id,"hostUserId":4,"venueId":8,"venueName":"Court $id",'
    '"venueAddress":"Main Street","venueReviewCount":0,'
    '"sportType":"Badminton","slotNumber":2,"matchDate":"2030-04-12",'
    '"startTime":"18:30","durationHours":1,"totalPrice":240,'
    '"hostShareAmount":120,"opponentShareAmount":120,'
    '"skillLevel":"open","status":"open","hostFirstName":"Jordan",'
    '"venueLatitude":${latitude ?? 'null'},'
    '"venueLongitude":${longitude ?? 'null'}}';
