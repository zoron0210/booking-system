import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/merchant_management/domain/merchant_profile_performance.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_profile_performance_card.dart';

void main() {
  testWidgets('performance card renders metrics and reports user actions', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 26, 9);
    final bookings = [
      {
        'date': '2026-10-26',
        'status': 'approved',
        'total': 100,
        'paidAmount': 40,
        'paymentStatus': 'partial',
        'players': 3,
      },
    ];
    var period = 'Today';
    var selectedPeriod = '';
    var paidAmountTapped = false;
    late StateSetter updateParent;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateParent = setState;
              return MerchantProfilePerformanceCard(
                performance: MerchantProfilePerformance.calculate(
                  bookings: bookings,
                  period: period,
                  now: now,
                ),
                period: period,
                venueCount: 2,
                onPeriodChanged: (value) {
                  selectedPeriod = value;
                  updateParent(() => period = value);
                },
                onEstimatedPaidTap: () => paidAmountTapped = true,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('₱100.00'), findsOneWidget);
    expect(find.text('₱40.00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('merchant-profile-date-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days').last);
    await tester.pumpAndSettle();
    expect(selectedPeriod, '7 days');
    expect(find.text('7 days performance'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('merchant-profile-estimated-paid')),
    );
    expect(paidAmountTapped, isTrue);
  });
}
