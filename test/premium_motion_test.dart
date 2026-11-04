import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/premium_motion.dart';

void main() {
  test(
    'refresh gate coalesces overlapping pulls and suppresses rapid repeats',
    () async {
      final gate = PremiumRefreshGate(
        cooldown: const Duration(milliseconds: 30),
      );
      final refreshCompletion = Completer<void>();
      var refreshCount = 0;
      Future<void> refresh() {
        refreshCount++;
        return refreshCompletion.future;
      }

      final firstRefresh = gate.run(refresh);
      final overlappingRefresh = gate.run(refresh);
      expect(identical(firstRefresh, overlappingRefresh), isTrue);
      expect(refreshCount, 1);

      refreshCompletion.complete();
      await firstRefresh;
      await gate.run(refresh);
      expect(refreshCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      await gate.run(() async {
        refreshCount++;
      });
      expect(refreshCount, 2);
    },
  );

  testWidgets('press scales to 90 percent and springs back', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PremiumPressScale(child: Text('Press'))),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Press')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .9);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 470));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  test('refresh physics allows 35 percent of a downward top pull', () {
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 500,
      pixels: 0,
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    expect(
      const RefreshResistantScrollPhysics().applyBoundaryConditions(
        metrics,
        -100,
      ),
      -65,
    );
  });

  testWidgets('expandable content eases to its full height in 350 ms', (
    tester,
  ) async {
    var expanded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => expanded = !expanded),
                  child: const Text('Toggle'),
                ),
                PremiumExpandable(
                  expanded: expanded,
                  child: const SizedBox(
                    key: ValueKey('expand-content'),
                    height: 40,
                    child: Text('Details'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AnimatedSize)).height, 0);
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    final halfwayHeight = tester.getSize(find.byType(AnimatedSize)).height;
    expect(halfwayHeight, greaterThan(0));
    expect(halfwayHeight, lessThan(40));

    await tester.pump(const Duration(milliseconds: 175));
    expect(tester.getSize(find.byType(AnimatedSize)).height, 40);
  });

  testWidgets('rolling digits settle on the updated number', (tester) async {
    var value = '18';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => value = '42'),
                  child: const Text('Update'),
                ),
                RollingDigits(
                  value: value,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('42'), findsOneWidget);
  });

  testWidgets('rolling digit columns begin 100 ms apart', (tester) async {
    var value = '11';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => value = '22'),
                  child: const Text('Update'),
                ),
                RollingDigits(
                  value: value,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 99));
    expect(find.text('2'), findsNWidgets(2));
  });

  testWidgets('success check draws and exposes an accessible label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SuccessCheckmark())),
    );

    await tester.pump(const Duration(milliseconds: 470));
    expect(find.bySemanticsLabel('Success'), findsOneWidget);
  });
}
