import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/data/merchant_add_session.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_add_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('News Card session failure has an inline retry', (tester) async {
    final tokens = <String?>[null, 'test-token', 'test-token'];
    var requests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(jsonEncode({'error': 'Unavailable'}), 503);
        }
        return http.Response(jsonEncode({'posts': []}), 200);
      }),
    );

    await tester.pumpWidget(
      _page(
        api: api,
        session: _TestMerchantAddSession(() async => tokens.removeAt(0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load News Cards.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-news-cards-retry')),
      findsOneWidget,
    );
    expect(requests, 0);

    await tester.tap(find.byKey(const ValueKey('merchant-news-cards-retry')));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.textContaining('Could not load News Cards.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('merchant-news-cards-retry')));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(
      find.byKey(const ValueKey('merchant-booking-cards-no-businesses')),
      findsOneWidget,
    );
  });

  testWidgets('failed News Card refresh retains the last loaded card', (
    tester,
  ) async {
    var requests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/merchant/news-posts') {
          requests++;
          if (requests == 1) {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'id': 100,
                    'businessId': 10,
                    'title': 'Saved draft',
                    'body': 'Venue update',
                    'imageUrl': 'venue-image',
                    'status': 'draft',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'error': 'Unavailable'}), 503);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      _page(
        api: api,
        session: _TestMerchantAddSession(() async => 'test-token'),
        businesses: [_business()],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('News cards'));
    await tester.pumpAndSettle();

    expect(find.text('Saved draft'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 480));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(
      find.textContaining('Showing the last successfully loaded cards'),
      findsOneWidget,
    );
    expect(find.text('Saved draft'), findsOneWidget);
    expect(
      find.textContaining('DRAFT · Publish to show this Booking Card'),
      findsOneWidget,
    );
  });

  testWidgets('business updates do not duplicate an active News Card load', (
    tester,
  ) async {
    final initialResponse = Completer<http.Response>();
    var requests = 0;
    final api = AuthApi(
      client: MockClient((request) {
        requests++;
        return requests == 1
            ? initialResponse.future
            : Future.value(_newsResponse('Refreshed result'));
      }),
    );
    final pageKey = GlobalKey<MerchantAddPageState>();
    Widget buildPage(List<Map<String, dynamic>> businesses) => MaterialApp(
      home: Scaffold(
        body: MerchantAddPage(
          key: pageKey,
          initialBusinessType: null,
          api: api,
          session: _TestMerchantAddSession(() async => 'test-token'),
          businesses: businesses,
          onBusinessesChanged: () async {},
        ),
      ),
    );
    await tester.pumpWidget(buildPage([_business()]));
    await tester.pump();
    expect(requests, 1);

    await tester.pumpWidget(
      buildPage([
        _business(),
        {..._business(), 'id': 11, 'name': 'Second court'},
      ]),
    );
    await tester.pump();
    expect(requests, 1);

    initialResponse.complete(_newsResponse('Initial result'));
    await tester.pumpAndSettle();
    expect(requests, 1);

    await tester.tap(find.text('News cards'));
    await tester.pumpAndSettle();
    expect(find.text('Initial result'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 480));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('Refreshed result'), findsOneWidget);
    expect(find.text('Initial result'), findsNothing);
  });

  testWidgets('business filters distinguish no matches from no businesses', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );
    await tester.pumpWidget(
      _page(
        api: api,
        session: _TestMerchantAddSession(() async => 'test-token'),
        businesses: [_business()],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('merchant-booking-cards-not-ready')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-publishing-lifecycle')),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Event').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('merchant-booking-cards-filter-no-results')),
      findsOneWidget,
    );
    expect(find.text('No businesses match these filters'), findsOneWidget);
  });

  testWidgets('publishing points to the first missing required field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            key: pageKey,
            initialBusinessType: 'Sports',
            api: api,
            session: _TestMerchantAddSession(() async => 'test-token'),
            businesses: const [],
            onBusinessesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pageKey.currentState!.openAddBusinessForm();
    await tester.pumpAndSettle();

    final publishButton = find.ancestor(
      of: find.text('Publish booking card'),
      matching: find.byType(FilledButton),
    );
    tester.widget<FilledButton>(publishButton.first).onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter a venue name before publishing.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sports, Event, and Fitness setup sections fit at phone width and larger text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sections = {
        'Sports': 'SPORTS, SLOTS & RATES',
        'Event': 'EVENT BOOKING DETAILS',
        'Fitness & Wellness': 'FITNESS CATEGORIES & PRICES',
      };
      for (final entry in sections.entries) {
        final pageKey = GlobalKey<MerchantAddPageState>();
        final api = AuthApi(
          client: MockClient(
            (request) async => http.Response(jsonEncode({'posts': []}), 200),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: MerchantAddPage(
                key: pageKey,
                initialBusinessType: entry.key,
                api: api,
                session: _TestMerchantAddSession(() async => 'test-token'),
                businesses: const [],
                onBusinessesChanged: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        pageKey.currentState!.openAddBusinessForm();
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.byKey(const ValueKey('business-setup-section-guide')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('business-setup-step-booking-details')),
          findsOneWidget,
        );
        tester
            .widget<ActionChip>(
              find.byKey(const ValueKey('business-setup-step-booking-details')),
            )
            .onPressed!
            .call();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final closeButton = find.ancestor(
          of: find.byIcon(Icons.close_rounded),
          matching: find.byType(IconButton),
        );
        tester.widget<IconButton>(closeButton.first).onPressed!.call();
        await tester.pumpAndSettle();
      }
    },
  );
}

Widget _page({
  required AuthApi api,
  required MerchantAddSession session,
  List<Map<String, dynamic>> businesses = const [],
}) => MaterialApp(
  home: Scaffold(
    body: MerchantAddPage(
      initialBusinessType: null,
      api: api,
      session: session,
      businesses: businesses,
      onBusinessesChanged: () async {},
    ),
  ),
);

Map<String, dynamic> _business() => {
  'id': 10,
  'businessType': 'Sports',
  'name': 'Example court',
  'category': 'Basketball',
  'address': 'Cebu City',
  'imageUrl': 'venue-image',
  'pricePerHour': 200,
  'hours': '8:00 AM - 5:00 PM',
};

http.Response _newsResponse(String title) => http.Response(
  jsonEncode({
    'posts': [
      {
        'id': 100,
        'businessId': 10,
        'title': title,
        'body': 'Venue update',
        'imageUrl': 'venue-image',
        'status': 'draft',
      },
    ],
  }),
  200,
);

class _TestMerchantAddSession implements MerchantAddSession {
  const _TestMerchantAddSession(this.loadToken);

  final Future<String?> Function() loadToken;

  @override
  Future<String?> loadApiToken() => loadToken();

  @override
  Future<bool> bookingDeadlineReminderDismissed() async => true;

  @override
  Future<void> dismissBookingDeadlineReminder() async {}
}
