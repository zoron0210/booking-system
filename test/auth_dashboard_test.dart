import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/features/auth/presentation/auth_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('language selector refreshes after changing language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(languageCode: 'en');

    await tester.pumpWidget(const MaterialApp(home: AuthDashboardPage()));
    await tester.pumpAndSettle();
    final languageSelector = find.byKey(
      const ValueKey('auth-language-selector'),
    );
    expect(
      find.descendant(of: languageSelector, matching: find.text('English')),
      findsOneWidget,
    );

    await tester.tap(languageSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語 (Japanese)'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: languageSelector, matching: find.text('日本語')),
      findsOneWidget,
    );
  });

  testWidgets('customer and merchant registration choices have equal weight', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(languageCode: 'en');

    await tester.pumpWidget(const MaterialApp(home: AuthDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    final customerCard = find.byKey(const ValueKey('auth-role-customer'));
    final merchantCard = find.byKey(const ValueKey('auth-role-merchant'));
    expect(
      tester.getSize(customerCard).height,
      tester.getSize(merchantCard).height,
    );

    final customerTitle = tester.widget<Text>(
      find.descendant(of: customerCard, matching: find.text('Customer')),
    );
    final merchantTitle = tester.widget<Text>(
      find.descendant(of: merchantCard, matching: find.text('Merchant')),
    );
    expect(customerTitle.style?.fontSize, merchantTitle.style?.fontSize);
    expect(customerTitle.style?.fontWeight, merchantTitle.style?.fontWeight);
  });
}
