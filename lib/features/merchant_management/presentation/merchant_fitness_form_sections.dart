import 'package:flutter/material.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';

class MerchantFitnessCategoryInput {
  MerchantFitnessCategoryInput({
    required String category,
    String sessionPrice = '',
    String monthlyPrice = '',
    String yearlyPrice = '',
    this.yearlyDiscountType = 'none',
    String yearlyDiscountValue = '',
  }) : category = TextEditingController(text: category),
       sessionPrice = TextEditingController(text: sessionPrice),
       monthlyPrice = TextEditingController(text: monthlyPrice),
       yearlyPrice = TextEditingController(text: yearlyPrice),
       yearlyDiscountValue = TextEditingController(text: yearlyDiscountValue);

  final TextEditingController category;
  final TextEditingController sessionPrice;
  final TextEditingController monthlyPrice;
  final TextEditingController yearlyPrice;
  final TextEditingController yearlyDiscountValue;
  String yearlyDiscountType;

  void dispose() {
    category.dispose();
    sessionPrice.dispose();
    monthlyPrice.dispose();
    yearlyPrice.dispose();
    yearlyDiscountValue.dispose();
  }
}

class MerchantFitnessCoachInput {
  MerchantFitnessCoachInput({
    String name = '',
    String monthlyPrice = '',
    this.profileImageUrl,
  }) : name = TextEditingController(text: name),
       monthlyPrice = TextEditingController(text: monthlyPrice);

  final TextEditingController name;
  final TextEditingController monthlyPrice;
  String? profileImageUrl;

  void dispose() {
    name.dispose();
    monthlyPrice.dispose();
  }
}

class MerchantFitnessCategoryCard extends StatelessWidget {
  const MerchantFitnessCategoryCard({
    super.key,
    required this.category,
    required this.onDiscountChanged,
  });

  final MerchantFitnessCategoryInput category;
  final ValueChanged<String> onDiscountChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          category.category.text,
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        for (final entry in <(String, TextEditingController)>[
          ('Session price (required)', category.sessionPrice),
          ('Monthly price (required)', category.monthlyPrice),
          ('Yearly price (required)', category.yearlyPrice),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: entry.$2,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: appLanguageText(entry.$1, entry.$1),
                prefixText: '₱ ',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        amount > 99999999.99
                    ? 'Enter a price greater than ₱0.'
                    : null;
              },
            ),
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: category.yearlyDiscountType,
          decoration: InputDecoration(
            labelText: appLanguageText(
              'Yearly offer (optional)',
              'Yearly offer (optional)',
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'none',
              child: AppText('No discount', localize: true),
            ),
            DropdownMenuItem(
              value: 'freeMonths',
              child: AppText('Free months', localize: true),
            ),
            DropdownMenuItem(
              value: 'percentage',
              child: AppText('Percentage off', localize: true),
            ),
          ],
          onChanged: (value) {
            if (value != null) onDiscountChanged(value);
          },
        ),
        if (category.yearlyDiscountType != 'none')
          TextFormField(
            controller: category.yearlyDiscountValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: category.yearlyDiscountType == 'freeMonths'
                  ? appLanguageText('Free months (1–11)', 'Free months (1–11)')
                  : appLanguageText(
                      'Discount percentage (1–100%)',
                      'Discount percentage (1–100%)',
                    ),
              suffixText: category.yearlyDiscountType == 'percentage'
                  ? '%'
                  : null,
            ),
          ),
      ],
    ),
  );
}

class MerchantFitnessCoachCard extends StatelessWidget {
  const MerchantFitnessCoachCard({
    super.key,
    required this.coach,
    required this.onPickImage,
    required this.onRemove,
    this.profileImageProvider,
  });

  final MerchantFitnessCoachInput coach;
  final VoidCallback onPickImage;
  final VoidCallback onRemove;
  final ImageProvider<Object>? profileImageProvider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.softOrange,
                backgroundImage: profileImageProvider,
                child: coach.profileImageUrl == null
                    ? Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.accent,
                        size: 19,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                'Coach profile photo (optional)',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
                localize: true,
              ),
            ),
            IconButton(
              tooltip: appLanguageText('Remove coach', 'Remove coach'),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextFormField(
          controller: coach.name,
          decoration: InputDecoration(
            labelText: appLanguageText(
              'Coach name (required)',
              'Coach name (required)',
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the coach name.'
              : null,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: coach.monthlyPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: appLanguageText(
              'Coach monthly price (required)',
              'Coach monthly price (required)',
            ),
            prefixText: '₱ ',
          ),
          validator: (value) {
            final amount = double.tryParse(value?.trim() ?? '');
            return amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    amount > 99999999.99
                ? 'Enter a monthly price greater than ₱0.'
                : null;
          },
        ),
      ],
    ),
  );
}
