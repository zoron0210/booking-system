import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings page falls back to shared preferences', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: AppSettingsPage()));

    expect(find.byType(AppSettingsPage), findsOneWidget);
    expect(find.text('Make the app feel like yours.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-settings-dark-mode')));
    await tester.pumpAndSettle();
    expect(AppPreferences.instance.darkMode, isTrue);
    await AppPreferences.instance.update(darkMode: false);
  });

  testWidgets('settings page accepts explicit preference dependency', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences.empty();
    await tester.pumpWidget(
      MaterialApp(home: AppSettingsPage(preferences: preferences)),
    );

    expect(find.byType(AppSettingsPage), findsOneWidget);
    expect(find.text('Make the app feel like yours.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-settings-dark-mode')));
    await tester.pumpAndSettle();
    expect(preferences.darkMode, isTrue);
    expect(AppPreferences.instance.darkMode, isFalse);
  });
}
