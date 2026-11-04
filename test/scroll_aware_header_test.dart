import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/scroll_aware_header.dart';

void main() {
  testWidgets('header hides on downward scroll and returns on upward scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollAwareHeader(
            header: const SizedBox(
              key: ValueKey('scroll-aware-header'),
              height: 56,
              child: Text('Search and filters'),
            ),
            body: ListView.builder(
              key: const ValueKey('scroll-aware-list'),
              itemCount: 40,
              itemBuilder: (_, index) =>
                  SizedBox(height: 80, child: Text('Venue $index')),
            ),
          ),
        ),
      ),
    );

    final list = find.byKey(const ValueKey('scroll-aware-list'));
    final header = find.byKey(const ValueKey('scroll-aware-header'));
    expect(header, findsOneWidget);

    await tester.drag(list, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(header, findsNothing);

    await tester.drag(list, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
