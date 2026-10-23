import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_fitness_form_sections.dart';

void main() {
  testWidgets('fitness category card validates prices and reports offers', (
    tester,
  ) async {
    final category = MerchantFitnessCategoryInput(category: 'Pilates');
    addTearDown(category.dispose);
    final formKey = GlobalKey<FormState>();
    String? selectedOffer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: MerchantFitnessCategoryCard(
                category: category,
                onDiscountChanged: (value) => selectedOffer = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    category.sessionPrice.text = '100';
    category.monthlyPrice.text = '800';
    category.yearlyPrice.text = '8000';
    expect(formKey.currentState!.validate(), isTrue);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free months').last);
    await tester.pumpAndSettle();

    expect(selectedOffer, 'freeMonths');
  });

  testWidgets('fitness coach card validates details and exposes callbacks', (
    tester,
  ) async {
    final coach = MerchantFitnessCoachInput();
    addTearDown(coach.dispose);
    final formKey = GlobalKey<FormState>();
    var pickedImage = false;
    var removed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: MerchantFitnessCoachCard(
              coach: coach,
              onPickImage: () => pickedImage = true,
              onRemove: () => removed = true,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    coach.name.text = 'Coach Alex';
    coach.monthlyPrice.text = '1200';
    expect(formKey.currentState!.validate(), isTrue);

    await tester.tap(find.byType(CircleAvatar));
    await tester.tap(find.byIcon(Icons.delete_outline));

    expect(pickedImage, isTrue);
    expect(removed, isTrue);
  });
}
