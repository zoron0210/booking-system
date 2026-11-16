import 'package:flutter/material.dart';

import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_text.dart';

class SportsBookingPriceSummary extends StatelessWidget {
  const SportsBookingPriceSummary({
    super.key,
    required this.slotCount,
    required this.rate,
    required this.durationHours,
    required this.playerCount,
    required this.extraPlayerCount,
    required this.additionalPlayerFee,
    required this.extraPlayerCharge,
    required this.bookingDate,
    required this.bookingTime,
    required this.total,
    required this.amountDueAfterApproval,
    required this.cashOnArrival,
  });

  final int slotCount;
  final double rate;
  final int durationHours;
  final int playerCount;
  final int extraPlayerCount;
  final double additionalPlayerFee;
  final double extraPlayerCharge;
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final double total;
  final double amountDueAfterApproval;
  final bool cashOnArrival;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Divider(height: 20, color: AppColors.borderSubtle),
      _amountRow(
        slotCount == 1 ? 'Merchant rate' : 'Merchant rate ($slotCount slots)',
        rate * slotCount,
        '/ hour',
      ),
      _amountRow('Duration', durationHours.toDouble(), ' hour(s)'),
      _amountRow(
        'Players',
        playerCount.toDouble(),
        playerCount == 1 ? ' player' : ' players',
      ),
      if (extraPlayerCharge > 0)
        _amountRow(
          'Extra players ($extraPlayerCount × '
              '\u{20B1} ${additionalPlayerFee.toStringAsFixed(2)})',
          extraPlayerCharge,
          '',
        ),
      _scheduleRow(context),
      _amountRow('Booking total', total, ''),
      _amountRow(
        cashOnArrival
            ? 'Cash downpayment after approval'
            : 'Online amount after approval',
        amountDueAfterApproval,
        '',
        strong: true,
      ),
      if (cashOnArrival)
        AppText(
          'Cash on Arrival is fixed at 50% of the booking total.',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          localize: true,
        ),
    ],
  );

  Widget _amountRow(
    String label,
    double amount,
    String suffix, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        AppText(
          label == 'Duration' || label == 'Players'
              ? '${amount.toStringAsFixed(0)}$suffix'
              : '\u{20B1} ${amount.toStringAsFixed(2)}$suffix',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _scheduleRow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        AppText(
          'Schedule',
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
          localize: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppText(
            '${MaterialLocalizations.of(context).formatShortDate(bookingDate)} · '
            '${bookingTime.format(context)} · $durationHours hr',
            textAlign: TextAlign.end,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
            localize: true,
          ),
        ),
      ],
    ),
  );
}
