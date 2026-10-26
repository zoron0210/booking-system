import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_bottom_navigation.dart';

void main() {
  testWidgets(
    'quickly reselecting a customer tab invokes its refresh callback',
    (tester) async {
      var destinationSelections = 0;
      var reselections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) => destinationSelections++,
              onDestinationReselected: () => reselections++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Venue'));
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Venue'));

      expect(destinationSelections, 1);
      expect(reselections, 1);
      expect(find.text('Explore'), findsNothing);
    },
  );

  testWidgets('selecting a different customer tab remains normal navigation', (
    tester,
  ) async {
    int? selectedDestination;
    var reselections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedDestination = index,
            onDestinationReselected: () => reselections++,
          ),
        ),
      ),
    );

    expect(find.text('Venue'), findsOneWidget);
    await tester.tap(find.text('Saved'));

    expect(selectedDestination, 1);
    expect(reselections, 0);
  });

  testWidgets('customer navigation can omit Saved while retaining routes', (
    tester,
  ) async {
    int? selectedDestination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            hideSavedDestination: true,
            onDestinationSelected: (index) => selectedDestination = index,
          ),
        ),
      ),
    );

    expect(find.text('Saved'), findsNothing);
    await tester.tap(find.text('Messages'));
    expect(selectedDestination, 2);
    await tester.tap(find.text('Profile'));
    expect(selectedDestination, 4);
  });

  testWidgets('customer navigation exposes Home as its own destination', (
    tester,
  ) async {
    int? selectedDestination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 5,
            hideSavedDestination: true,
            showHomeDestination: true,
            onDestinationSelected: (index) => selectedDestination = index,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('customer-nav-home')), findsOneWidget);
    expect(find.text('Home').first, findsOneWidget);
    await tester.tap(find.text('Venue'));
    expect(selectedDestination, 0);
    await tester.tap(find.text('Home'));
    expect(selectedDestination, 5);
  });
}
