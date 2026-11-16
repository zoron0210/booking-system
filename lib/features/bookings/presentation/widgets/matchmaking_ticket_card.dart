import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';

class MatchmakingTicketCard extends StatefulWidget {
  const MatchmakingTicketCard({
    super.key,
    required this.ticket,
    required this.isHost,
    required this.onAction,
    this.onOpponentPayment,
  });

  final Map<String, dynamic> ticket;
  final bool isHost;
  final Future<void> Function(Map<String, dynamic> ticket, bool accept)
  onAction;
  final Future<void> Function(Map<String, dynamic> ticket, String method)?
  onOpponentPayment;

  @override
  State<MatchmakingTicketCard> createState() => _MatchmakingTicketCardState();
}

class MatchmakingBookingRequestTicketCard extends StatefulWidget {
  const MatchmakingBookingRequestTicketCard({
    super.key,
    required this.ticket,
    required this.isMerchant,
    required this.onDecision,
  });

  final Map<String, dynamic> ticket;
  final bool isMerchant;
  final Future<void> Function(Map<String, dynamic> ticket, bool approve)
  onDecision;

  @override
  State<MatchmakingBookingRequestTicketCard> createState() =>
      _MatchmakingBookingRequestTicketCardState();
}

class _MatchmakingBookingRequestTicketCardState
    extends State<MatchmakingBookingRequestTicketCard> {
  var _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      await widget.onDecision(widget.ticket, approve);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.ticket['status'] == 'pending_merchant_approval';
    final approved = widget.ticket['status'] == 'approved';
    final statusColor = approved
        ? const Color(0xFF237A43)
        : const {
            'declined',
            'cancelled',
            'expired',
          }.contains(widget.ticket['status'])
        ? AppColors.errorText
        : AppColors.accent;
    final statusLabel = switch (widget.ticket['status']) {
      'approved' => 'APPROVED',
      'declined' => 'DECLINED',
      'cancelled' => 'CANCELLED',
      'expired' => 'EXPIRED',
      _ => 'PENDING',
    };
    final venueName = _stringValue(widget.ticket['venueName'], 'Venue');
    final date = [
      _stringValue(widget.ticket['matchDate'], ''),
      _stringValue(widget.ticket['startTime'], ''),
    ].where((part) => part.isNotEmpty).join(' · ');
    final totalPrice = _amount(widget.ticket['totalPrice']);
    final hostShare = _amount(widget.ticket['hostShareAmount']);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 370),
      child: Container(
        key: ValueKey(
          'matchmaking-booking-ticket-${widget.ticket['bookingId']}',
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: .5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: statusColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: AppText(
                      'MATCH BOOKING REQUEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                      localize: true,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    venueName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_stringValue(widget.ticket['hostName'], '').isNotEmpty)
                    _bookingDetail(
                      Icons.person_outline_rounded,
                      'Host: ${_stringValue(widget.ticket['hostName'], '')}',
                    ),
                  const SizedBox(height: 8),
                  _bookingDetail(
                    Icons.sports_outlined,
                    '${_stringValue(widget.ticket['sportType'], 'Match')} · '
                    'Court ${widget.ticket['slotNumber'] ?? '1'}',
                  ),
                  _bookingDetail(Icons.calendar_month_outlined, date),
                  _bookingDetail(
                    Icons.payments_outlined,
                    'Total ₱$totalPrice · Host downpayment ₱$hostShare',
                  ),
                  if (approved)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: AppText(
                        'The venue approved this request. The host can pay from Matchmaking.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        localize: true,
                      ),
                    ),
                  if (widget.isMerchant && pending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _decide(false),
                            child: const AppText('Decline', localize: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _decide(true),
                            child: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const AppText('Approve', localize: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _bookingDetail(IconData icon, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 5),
  child: Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: AppText(value, style: TextStyle(color: AppColors.muted)),
      ),
    ],
  ),
);

String _amount(dynamic value) {
  final amount = double.tryParse('$value');
  return amount == null ? '0.00' : amount.toStringAsFixed(2);
}

class _MatchmakingTicketCardState extends State<MatchmakingTicketCard> {
  var _busy = false;

  Future<void> _act(bool accept) async {
    setState(() => _busy = true);
    try {
      await widget.onAction(widget.ticket, accept);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(String method) async {
    final onOpponentPayment = widget.onOpponentPayment;
    if (onOpponentPayment == null) return;
    setState(() => _busy = true);
    try {
      await onOpponentPayment(widget.ticket, method);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicantName = _stringValue(
      widget.ticket['applicantName'],
      'Player',
    );
    final sportType = _stringValue(widget.ticket['sportType'], 'Match');
    final matchDate = _stringValue(widget.ticket['matchDate'], '');
    final startTime = _stringValue(widget.ticket['startTime'], '');
    final skillLevel = _skillLabel(
      _stringValue(widget.ticket['skillLevel'], 'open'),
    );
    final status = _stringValue(widget.ticket['status'], 'pending');
    final isPending = status == 'pending';
    final paymentStatus = _stringValue(
      widget.ticket['opponentPaymentStatus'],
      'unpaid',
    );
    final applicantAvatar = _imageProvider(widget.ticket['applicantAvatarUrl']);
    final statusColor = switch (status) {
      'accepted' || 'matched' => const Color(0xFF237A43),
      'declined' => AppColors.errorText,
      _ => AppColors.accent,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 370),
      child: Container(
        key: ValueKey('matchmaking-ticket-${widget.ticket['requestId']}'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: .5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: statusColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.sports_handball_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'MATCH REQUEST',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                      localize: true,
                    ),
                  ),
                  Text(
                    status == 'matched' ? 'MATCHED!' : status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: applicantAvatar,
                        child: applicantAvatar == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          applicantName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _detail(Icons.sports_outlined, sportType),
                  if (_stringValue(widget.ticket['venueName'], '').isNotEmpty)
                    _detail(
                      Icons.stadium_outlined,
                      _stringValue(widget.ticket['venueName'], ''),
                    ),
                  const SizedBox(height: 5),
                  _detail(
                    Icons.calendar_month_outlined,
                    [
                      matchDate,
                      startTime,
                    ].where((part) => part.isNotEmpty).join(' · '),
                  ),
                  const SizedBox(height: 5),
                  _detail(Icons.stars_outlined, skillLevel),
                  if (status == 'matched' && !widget.isHost) ...[
                    const SizedBox(height: 10),
                    if (paymentStatus == 'unpaid' &&
                        widget.onOpponentPayment != null) ...[
                      AppText(
                        'Matched! Pay your share of '
                        '₱${_amount(widget.ticket['opponentShareAmount'])}.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _pay('online'),
                          child: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const AppText('Pay Online'),
                        ),
                      ),
                    ] else
                      AppText(
                        paymentStatus == 'paid'
                            ? 'Your share is paid.'
                            : paymentStatus == 'cash_on_arrival'
                            ? 'Your share is due in cash at the venue.'
                            : paymentStatus == 'not_required'
                            ? 'Free to join. The host covers the remaining balance.'
                            : 'Online payment is required for your 50% share.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                  if (widget.isHost && isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _act(false),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('❌'),
                                SizedBox(width: 4),
                                AppText('Decline', localize: true),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _act(true),
                            child: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('✅'),
                                      SizedBox(width: 4),
                                      AppText('Accept', localize: true),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: AppText(value, style: TextStyle(color: AppColors.muted)),
      ),
    ],
  );

  String _skillLabel(String value) => switch (value) {
    'beginner' => 'Beginner',
    'intermediate' => 'Intermediate',
    'advanced' => 'Advanced',
    _ => 'Open to All',
  };

  String _amount(dynamic value) {
    final amount = double.tryParse('$value');
    return amount == null ? '0.00' : amount.toStringAsFixed(2);
  }
}

String _stringValue(dynamic value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

ImageProvider<Object>? _imageProvider(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && {'http', 'https'}.contains(uri.scheme)) {
    return NetworkImage(value);
  }
  try {
    final base64Value = value.contains(',')
        ? value.substring(value.indexOf(',') + 1)
        : value;
    return MemoryImage(base64Decode(base64Value));
  } on FormatException {
    return null;
  }
}
