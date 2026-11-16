import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/bookings/presentation/widgets/sports_booking_price_summary.dart';

void main() {
  testWidgets('cash summary keeps the booking breakdown and amount due', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SportsBookingPriceSummary(
            slotCount: 2,
            rate: 150,
            durationHours: 2,
            playerCount: 4,
            extraPlayerCount: 2,
            additionalPlayerFee: 25,
            extraPlayerCharge: 50,
            bookingDate: DateTime(2026, 11, 12),
            bookingTime: const TimeOfDay(hour: 18, minute: 30),
            total: 650,
            amountDueAfterApproval: 325,
            cashOnArrival: true,
          ),
        ),
      ),
    );

    expect(find.text('Merchant rate (2 slots)'), findsOneWidget);
    expect(find.text('\u{20B1} 300.00/ hour'), findsOneWidget);
    expect(find.text('2 hour(s)'), findsOneWidget);
    expect(find.text('4 players'), findsOneWidget);
    expect(find.text('Extra players (2 × \u{20B1} 25.00)'), findsOneWidget);
    expect(find.text('\u{20B1} 50.00'), findsOneWidget);
    expect(find.text('Booking total'), findsOneWidget);
    expect(find.text('\u{20B1} 650.00'), findsOneWidget);
    expect(find.text('Cash downpayment after approval'), findsOneWidget);
    expect(find.text('\u{20B1} 325.00'), findsOneWidget);
    expect(
      find.text('Cash on Arrival is fixed at 50% of the booking total.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('online summary labels the full amount due after approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SportsBookingPriceSummary(
            slotCount: 1,
            rate: 500,
            durationHours: 1,
            playerCount: 1,
            extraPlayerCount: 0,
            additionalPlayerFee: 0,
            extraPlayerCharge: 0,
            bookingDate: DateTime(2026, 11, 12),
            bookingTime: const TimeOfDay(hour: 18, minute: 30),
            total: 500,
            amountDueAfterApproval: 500,
            cashOnArrival: false,
          ),
        ),
      ),
    );

    expect(find.text('Merchant rate'), findsOneWidget);
    expect(find.text('Online amount after approval'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00'), findsNWidgets(2));
    expect(find.text('Cash downpayment after approval'), findsNothing);
    expect(
      find.text('Cash on Arrival is fixed at 50% of the booking total.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
