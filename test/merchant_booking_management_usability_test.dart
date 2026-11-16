import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_dashboard.dart';

import 'merchant_dashboard_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'booking status counts follow the active type and search filters',
    (tester) async {
      final bookings = _statusFixtures();
      final api = _apiFor(bookings);
      await _mountDashboard(tester, api);
      await tapMerchantDestination(tester, 'bookings');

      expect(
        _statusCountLabel(tester, 'requests'),
        contains('Requests, 2 bookings'),
      );
      expect(
        _statusCountLabel(tester, 'active'),
        contains('Active, 2 bookings'),
      );
      expect(
        _statusCountLabel(tester, 'completed'),
        contains('Completed, 2 bookings'),
      );
      expect(
        _statusCountLabel(tester, 'requests'),
        contains('pending or awaiting merchant approval'),
      );
      expect(
        _statusCountLabel(tester, 'active'),
        contains('approved or matchmaking-open'),
      );
      expect(
        _statusCountLabel(tester, 'completed'),
        contains('finished, completed, or done'),
      );

      await tester.tap(
        find.byKey(const ValueKey('merchant-payout-type-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event').last);
      await tester.pumpAndSettle();
      expect(
        _statusCountLabel(tester, 'requests'),
        contains('Requests, 1 booking'),
      );
      expect(
        _statusCountLabel(tester, 'active'),
        contains('Active, 1 booking'),
      );
      expect(
        _statusCountLabel(tester, 'completed'),
        contains('Completed, 1 booking'),
      );

      await tester.enterText(
        find.byKey(const ValueKey('merchant-payout-search')),
        'no such customer',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(
        find.text('No completed bookings match your filters'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('merchant-management-empty-clear-filters')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('merchant-management-empty-clear-filters')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<int>>(
              find.byKey(
                const ValueKey('merchant-booking-management-status-tabs'),
              ),
            )
            .selected,
        {2},
      );
      expect(
        _statusCountLabel(tester, 'completed'),
        contains('Completed, 2 bookings'),
      );
      expect(
        find.byKey(const ValueKey('merchant-management-result-count')),
        findsNothing,
      );
    },
  );

  testWidgets('request cards expose confirmed approve and reasoned decline', (
    tester,
  ) async {
    final bookings = [
      _booking(id: 1, customer: 'Approval Customer', status: 'pending'),
      _booking(id: 2, customer: 'Decline Customer', status: 'pending'),
    ];
    final requests = <String>[];
    final api = _apiFor(
      bookings,
      onMutation: (request) {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/approve')) {
          bookings.singleWhere((booking) => booking['id'] == 1)['status'] =
              'approved';
        } else if (request.url.path.endsWith('/decline')) {
          bookings.singleWhere((booking) => booking['id'] == 2)['status'] =
              'cancelled';
        }
      },
    );
    await _mountDashboard(tester, api);
    await tapMerchantDestination(tester, 'bookings');

    final approveButton = find.byKey(
      const ValueKey('merchant-booking-card-approve-1'),
    );
    await tester.ensureVisible(approveButton);
    await tester.tap(approveButton);
    await tester.pumpAndSettle();
    expect(find.text('Approve booking request?'), findsOneWidget);
    expect(find.text('Approval Customer'), findsWidgets);
    expect(requests, isEmpty);

    await tester.tap(find.text('Keep request'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.tap(approveButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('merchant-booking-card-approve-confirm')),
    );
    await tester.pumpAndSettle();
    expect(requests, ['PATCH /api/merchant/bookings/1/approve']);

    final declineButton = find.byKey(
      const ValueKey('merchant-booking-card-decline-2'),
    );
    await tester.ensureVisible(declineButton);
    await tester.tap(declineButton);
    await tester.pumpAndSettle();
    expect(find.text('Decline booking?'), findsOneWidget);
    expect(requests, hasLength(1));
    await tester.enterText(
      find.byKey(const ValueKey('merchant-booking-decline-reason')),
      'The venue is unavailable.',
    );
    await tester.tap(find.text('Decline booking'));
    await tester.pumpAndSettle();
    expect(requests, [
      'PATCH /api/merchant/bookings/1/approve',
      'PATCH /api/merchant/bookings/2/decline',
    ]);
    expect(
      find.byKey(const ValueKey('merchant-booking-count-requests')),
      findsOneWidget,
    );
  });

  testWidgets('Fitness customer navigation names the membership workflow', (
    tester,
  ) async {
    final bookings = [
      _booking(
        id: 8,
        customer: 'Fitness Member',
        status: 'approved',
        businessType: 'Fitness & Wellness',
        fitnessPlanType: 'monthly',
        date: DateTime.now().toIso8601String().substring(0, 10),
      ),
    ];
    await _mountDashboard(tester, _apiFor(bookings));
    await tapMerchantDestination(tester, 'bookings');
    await tester.tap(find.byKey(const ValueKey('merchant-payout-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fitness').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    expect(find.text('Fitness memberships'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-fitness-membership-plan-filter')),
      findsOneWidget,
    );
    expect(find.text('Active fitness memberships'), findsOneWidget);
    expect(find.text('Fitness Member'), findsOneWidget);
  });

  testWidgets('booking and payment controls remain readable on a phone', (
    tester,
  ) async {
    final bookings = [
      _booking(id: 1, customer: 'Pending Customer', status: 'pending'),
      _booking(
        id: 2,
        customer: 'Payment Customer',
        status: 'approved',
        paymentStatus: 'unpaid',
      ),
    ];
    final api = _apiFor(bookings);
    await _mountDashboard(
      tester,
      api,
      textScaler: const TextScaler.linear(1.25),
    );
    await tapMerchantDestination(tester, 'bookings');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-booking-management-status-tabs')),
      findsOneWidget,
    );
    expect(find.text('Pending Customer'), findsOneWidget);
    expect(find.text('Booking date and time'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-booking-card-approve-1')),
      findsOneWidget,
    );
    final bookingLayoutException = tester.takeException();
    final bookingLayoutFailure = bookingLayoutException is FlutterError
        ? bookingLayoutException.diagnostics
              .map((diagnostic) => diagnostic.toStringDeep())
              .join('\n')
        : '$bookingLayoutException';
    expect(bookingLayoutException, isNull, reason: bookingLayoutFailure);

    tester
        .widget<SegmentedButton<int>>(
          find.byKey(const ValueKey('merchant-management-tabs')),
        )
        .onSelectionChanged!({2});
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-payment-management-tabs')),
      findsOneWidget,
    );
    expect(find.text('Payment Customer'), findsOneWidget);
    expect(find.text('₱ 1000.00'), findsWidgets);
    expect(
      find.byKey(const ValueKey('merchant-payment-toggle-2')),
      findsOneWidget,
    );
    final paymentLayoutException = tester.takeException();
    expect(paymentLayoutException, isNull);
  });
}

String _statusCountLabel(WidgetTester tester, String category) =>
    tester
        .widget<Semantics>(
          find.byKey(ValueKey('merchant-booking-count-$category')),
        )
        .properties
        .label ??
    '';

Future<void> _mountDashboard(
  WidgetTester tester,
  AuthApi api, {
  TextScaler? textScaler,
}) async {
  setMerchantDashboardSession();
  await tester.pumpWidget(
    MaterialApp(
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: MerchantDashboardPage(
        api: api,
        liveUpdatesClientFactory: OfflineLiveUpdatesClient.new,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Map<String, dynamic>> _statusFixtures() => [
  _booking(id: 1, customer: 'Pending Sports', status: 'pending'),
  _booking(
    id: 2,
    customer: 'Pending Event',
    status: 'matchmaking_pending_merchant',
    businessType: 'Event',
    bookingType: 'matchmaking',
  ),
  _booking(id: 3, customer: 'Active Sports', status: 'approved'),
  _booking(
    id: 4,
    customer: 'Active Event',
    status: 'matchmaking_open',
    businessType: 'Event',
    bookingType: 'matchmaking',
  ),
  _booking(
    id: 5,
    customer: 'Finished Event',
    status: 'finished',
    businessType: 'Event',
  ),
  _booking(id: 6, customer: 'Done Sports', status: 'done'),
  _booking(id: 7, customer: 'Cancelled Sports', status: 'cancelled'),
];

Map<String, dynamic> _booking({
  required int id,
  required String customer,
  required String status,
  String businessType = 'Sports',
  String bookingType = 'regular',
  String paymentStatus = 'unpaid',
  String paymentMethod = 'cash_on_arrival',
  String? fitnessPlanType,
  String? date,
}) => {
  'id': id,
  'customerId': id + 100,
  'customerName': customer,
  'customerEmail': '${customer.toLowerCase().replaceAll(' ', '.')}@example.com',
  'venueName': 'Sample venue',
  'businessType': businessType,
  'bookingType': bookingType,
  'date': date ?? DateTime.now().toIso8601String().substring(0, 10),
  'startTime': '09:00:00',
  'durationHours': 2,
  'players': 2,
  'fitnessPlanType': fitnessPlanType,
  'pricePerHour': 500,
  'total': 1000,
  'downpayment': 500,
  'paidAmount': paymentStatus == 'paid' ? 1000 : 0,
  'paymentMethod': paymentMethod,
  'paymentStatus': paymentStatus,
  'status': status,
};

AuthApi _apiFor(
  List<Map<String, dynamic>> bookings, {
  void Function(http.Request request)? onMutation,
}) => AuthApi(
  client: MockClient((request) async {
    if (request.method == 'PATCH' &&
        (request.url.path.endsWith('/approve') ||
            request.url.path.endsWith('/decline'))) {
      onMutation?.call(request);
      return http.Response(jsonEncode({'message': 'Booking updated.'}), 200);
    }
    switch (request.url.path) {
      case '/api/merchant/profile':
        return http.Response(
          jsonEncode({
            'profile': {
              'firstName': 'Merchant',
              'lastName': 'Owner',
              'email': 'merchant@example.com',
              'businessType': 'Sports',
            },
          }),
          200,
        );
      case '/api/merchant/businesses':
        return http.Response(jsonEncode({'businesses': []}), 200);
      case '/api/merchant/bookings':
        return http.Response(jsonEncode({'bookings': bookings}), 200);
      case '/api/activity-logs':
        return http.Response(jsonEncode({'activities': []}), 200);
      default:
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
    }
  }),
);
