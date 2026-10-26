import 'package:flutter/material.dart';

import '../../../app_design_system.dart';
import '../../../app_preferences.dart';
import '../domain/merchant_profile_performance.dart';

Color get _profileInk => AppColors.ink;
Color get _profileMuted => AppColors.muted;
Color get _profileLine => AppColors.border;
Color get _profileAccent => AppColors.accentForeground;

class MerchantProfilePerformanceCard extends StatelessWidget {
  const MerchantProfilePerformanceCard({
    super.key,
    required this.performance,
    required this.period,
    required this.venueCount,
    required this.onPeriodChanged,
    required this.onEstimatedPaidTap,
  });

  final MerchantProfilePerformance performance;
  final String period;
  final int venueCount;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onEstimatedPaidTap;

  @override
  Widget build(BuildContext context) {
    final bookings = performance.todayBookings;
    final filteredBookings = performance.periodBookings;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _profileLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: _profileLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        period == 'Today'
                            ? "Today's performance"
                            : '$period performance',
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('merchant-profile-date-filter'),
                        value: period,
                        dropdownColor: AppColors.surface,
                        iconEnabledColor: _profileMuted,
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: '7 days',
                            child: Text('7 days'),
                          ),
                          DropdownMenuItem(
                            value: '30 days',
                            child: Text('30 days'),
                          ),
                          DropdownMenuItem(
                            value: 'All time',
                            child: Text('All time'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) onPeriodChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  'CONFIRMED REVENUE',
                  style: TextStyle(
                    color: _profileMuted,
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                AppText(
                  '₱${performance.confirmedRevenue.toStringAsFixed(2)}',
                  key: const ValueKey('merchant-profile-performance-revenue'),
                  style: TextStyle(
                    color: _profileAccent,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                AppText(
                  period == 'Today'
                      ? bookings.isEmpty
                            ? 'No bookings scheduled today'
                            : '${bookings.length} booking${bookings.length == 1 ? '' : 's'} scheduled today'
                      : '${filteredBookings.length} booking${filteredBookings.length == 1 ? '' : 's'} in selected period',
                  style: TextStyle(color: _profileMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.event_available_rounded,
                        "Today's bookings",
                        '${bookings.length}',
                        const Color(0xFF1C69C9),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.pending_actions_rounded,
                        'Awaiting approval',
                        '${performance.todayPendingCount}',
                        const Color(0xFFE28A16),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.groups_rounded,
                        'Players today',
                        '${performance.todayParticipantCount}',
                        const Color(0xFF168B69),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.location_city_rounded,
                        'Active venues',
                        '$venueCount',
                        const Color(0xFF7655C5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InkWell(
              key: const ValueKey('merchant-profile-estimated-paid'),
              onTap: onEstimatedPaidTap,
              borderRadius: BorderRadius.circular(14),
              child: _metric(
                Icons.account_balance_wallet_outlined,
                'Estimated paid amount',
                '₱${performance.estimatedPaidAmount.toStringAsFixed(2)}',
                const Color(0xFF237A43),
                description: 'From booking payment records; not a withdrawable balance. Tap for payment details.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    IconData icon,
    String label,
    String value,
    Color color, {
    String? description,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _profileLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _profileMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          value,
          key: ValueKey('merchant-profile-metric-$label'),
          style: TextStyle(
            color: _profileInk,
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          AppText(
            description,
            style: TextStyle(color: _profileMuted, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ),
  );
}
