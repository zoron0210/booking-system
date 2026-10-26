import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/event_dashboard.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reference booking cards use equal image-led layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    final verticalScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(verticalScrollable).position;
    expect(position.maxScrollExtent, lessThanOrEqualTo(160));
    final cardSizes = <Size>[];
    for (final option in ['sports', 'event', 'fitness']) {
      final card = find.byKey(ValueKey('reserve-option-$option'));
      final image = tester.widget<Image>(
        find.descendant(of: card, matching: find.byType(Image)),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/overview/${option == 'event' ? 'events' : option}.png',
      );
      cardSizes.add(
        tester.getSize(
          find.byKey(
            ValueKey(
              'reserve-option-surface-${switch (option) {
                'sports' => 'Sports & Courts',
                'event' => 'Events & Experiences',
                _ => 'Studios & Fitness',
              }}',
            ),
          ),
        ),
      );
    }
    expect(cardSizes[0].height, cardSizes[1].height);
    expect(cardSizes[1].height, cardSizes[2].height);
    expect(cardSizes[0].width, cardSizes[1].width);
    expect(cardSizes[1].width, cardSizes[2].width);
    await tester.ensureVisible(
      find.byKey(const ValueKey('reserve-option-fitness')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('reserve-option-fitness')))
          .dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.text('Continue to Fitness & Wellness')).dy,
      ),
    );
  });

  testWidgets('brand header and continue footer stay visible while scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('SpotGO'), findsOneWidget);
    expect(find.text('INSTANTLY BOOKABLE'), findsOneWidget);
    expect(find.text('Choose Booking Type'), findsOneWidget);
    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);
    expect(find.text('SpotGO'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Choose Booking Type')).dy,
      greaterThan(0),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Choose Booking Type'), findsOneWidget);
  });

  testWidgets('selecting an experience updates the fixed continue action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reserve-option-sports')));
    await tester.pumpAndSettle();

    expect(find.text('Continue to Sports'), findsOneWidget);
  });

  testWidgets('continue saves the selected type and opens its feed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reserve-option-event')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Event'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDashboardPage), findsOneWidget);
    expect((await AppSession.load()).lastBookingType, 'Event');
  });

  testWidgets('booking types and fixed footer adapt to dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.violet,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const ReserveDashboardPage(initialSelection: 'Event'),
      ),
    );
    await tester.pumpAndSettle();

    for (final type in ['Sports', 'Event', 'Fitness & Wellness']) {
      final bookingType = find.byKey(
        ValueKey(
          'reserve-option-${type == 'Fitness & Wellness' ? 'fitness' : type.toLowerCase()}',
        ),
      );
      await tester.ensureVisible(bookingType);
      await tester.pumpAndSettle();
      final option = tester.widget<AnimatedContainer>(
        find.byKey(
          ValueKey(
            'reserve-option-surface-${switch (type) {
              'Sports' => 'Sports & Courts',
              'Event' => 'Events & Experiences',
              _ => 'Studios & Fitness',
            }}',
          ),
        ),
      );
      expect(
        (option.decoration! as BoxDecoration).color,
        AppColors.darkSurface,
      );
    }
    final selectedEvent = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('reserve-option-surface-Events & Experiences')),
    );
    expect(
      ((selectedEvent.decoration! as BoxDecoration).border! as Border)
          .top
          .color,
      AppColors.accentForeground,
    );
    expect(
      tester.widget<Text>(find.text('EVENTS & EXPERIENCES')).style!.color,
      AppColors.onAccent,
    );
    final continueButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue to Event'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      continueButton.style!.backgroundColor!.resolve({}),
      AppPalette.violet.color,
    );

    final footer = tester.widget<Container>(
      find.byKey(const ValueKey('reserve-footer')),
    );
    expect((footer.decoration! as BoxDecoration).color, AppColors.darkSurface);

    expect(find.text('Browsing is open to everyone'), findsOneWidget);
  });
}
