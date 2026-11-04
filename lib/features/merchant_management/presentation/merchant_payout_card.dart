import 'package:flutter/material.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_text.dart';

class MerchantPayoutCard extends StatelessWidget {
  const MerchantPayoutCard({
    super.key,
    required this.bookingCount,
    required this.received,
    required this.balanceDue,
  });

  final int bookingCount;
  final double received;
  final double balanceDue;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('merchant-payment-overview'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Payment overview',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
              ),
              AppText(
                '$bookingCount ${bookingCount == 1 ? 'booking' : 'bookings'}',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MerchantPayoutAmount(
                  key: const ValueKey('merchant-payment-overview-received'),
                  label: 'Received',
                  amount: received,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MerchantPayoutAmount(
                  key: const ValueKey('merchant-payment-overview-balance'),
                  label: 'Balance due',
                  amount: balanceDue,
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MerchantPayoutAmount extends StatelessWidget {
  const _MerchantPayoutAmount({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Expanded(
              child: AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        AppText(
          '\u{20B1} ${amount.toStringAsFixed(2)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
