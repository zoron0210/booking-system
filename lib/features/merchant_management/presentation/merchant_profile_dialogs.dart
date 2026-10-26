import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app_design_system.dart';
import '../../../app_preferences.dart';
import '../../../auth_api.dart';

Color get _profileInk => AppColors.ink;
Color get _profileMuted => AppColors.muted;
Color get _profileAccent => AppColors.accentForeground;

class MerchantSupportDetailPage extends StatelessWidget {
  const MerchantSupportDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      backgroundColor: AppColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      title: AppText(title, localize: true),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentForeground, size: 36),
            const SizedBox(height: 16),
            AppText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
              localize: true,
            ),
          ],
        ),
      ),
    ),
  );
}

class MerchantSupportSettingTile extends StatelessWidget {
  const MerchantSupportSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          key: key,
          children: [
            Icon(icon, color: _profileAccent, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BookingDeadlineDialog extends StatefulWidget {
  const BookingDeadlineDialog({
    super.key,
    required this.approvalValue,
    required this.approvalUnit,
    required this.paymentValue,
    required this.paymentUnit,
  });

  final String approvalValue;
  final String approvalUnit;
  final String paymentValue;
  final String paymentUnit;

  @override
  State<BookingDeadlineDialog> createState() => _BookingDeadlineDialogState();
}

class _BookingDeadlineDialogState extends State<BookingDeadlineDialog> {
  late final TextEditingController _approvalController;
  late final TextEditingController _paymentController;
  final _formKey = GlobalKey<FormState>();
  late String _approvalUnit;
  late String _paymentUnit;

  @override
  void initState() {
    super.initState();
    _approvalController = TextEditingController(text: widget.approvalValue);
    _paymentController = TextEditingController(text: widget.paymentValue);
    _approvalUnit = widget.approvalUnit;
    _paymentUnit = widget.paymentUnit;
  }

  @override
  void dispose() {
    _approvalController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  int _minutes(String raw, String unit) =>
      int.parse(raw.trim()) * (unit == 'hours' ? 60 : 1);

  Widget _deadlineField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required ValueChanged<String> onUnitChanged,
  }) => Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final amount = int.tryParse(value?.trim() ?? '');
            final multiplier = unit == 'hours' ? 60 : 1;
            if (amount == null || amount < 1 || amount * multiplier > 10080) {
              return 'Enter a whole number up to ${unit == 'hours' ? 168 : 10080}.';
            }
            return null;
          },
        ),
      ),
      const SizedBox(width: 10),
      DropdownButton<String>(
        value: unit,
        items: const [
          DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
          DropdownMenuItem(value: 'hours', child: Text('Hours')),
        ],
        onChanged: (value) {
          if (value != null) onUnitChanged(value);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: AppText(
      appLanguageText('Booking deadlines', 'Mga deadline ng booking'),
    ),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            appLanguageText(
              'Requests expire if they are not approved before this limit. Approved bookings must be paid before the payment limit.',
              'Mag-e-expire ang mga request kung hindi maaaprubahan sa itinakdang oras. Dapat mabayaran ang naaprubahang booking bago matapos ang limitasyon.',
            ),
          ),
          const SizedBox(height: 16),
          _deadlineField(
            label: 'Approval time limit',
            controller: _approvalController,
            unit: _approvalUnit,
            onUnitChanged: (value) => setState(() => _approvalUnit = value),
          ),
          const SizedBox(height: 12),
          _deadlineField(
            label: 'Payment time limit',
            controller: _paymentController,
            unit: _paymentUnit,
            onUnitChanged: (value) => setState(() => _paymentUnit = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: AppText(appLanguageText('Cancel', 'Kanselahin')),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          Navigator.pop(context, (
            approvalTimeoutMinutes: _minutes(
              _approvalController.text,
              _approvalUnit,
            ),
            paymentTimeoutMinutes: _minutes(
              _paymentController.text,
              _paymentUnit,
            ),
          ));
        },
        child: AppText(appLanguageText('Save', 'I-save')),
      ),
    ],
  );
}

class MerchantCheckInQrDialog extends StatefulWidget {
  const MerchantCheckInQrDialog({
    super.key,
    required this.api,
    required this.token,
    required this.venueId,
    required this.venueName,
  });

  final AuthApi api;
  final String token;
  final int venueId;
  final String venueName;

  @override
  State<MerchantCheckInQrDialog> createState() =>
      _MerchantCheckInQrDialogState();
}

class _MerchantCheckInQrDialogState extends State<MerchantCheckInQrDialog> {
  String? _qrCode;
  String? _error;
  int? _expiresAt;
  bool _loading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadCode(),
    );
    _loadCode();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCode() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.merchantVenueCheckInCode(
        token: widget.token,
        venueId: widget.venueId,
      );
      final qrCode = result['qrCode'];
      final expiresAt = result['expiresAt'];
      if (qrCode is! String || qrCode.isEmpty || expiresAt is! num) {
        throw const AuthApiException(
          'The server returned an invalid check-in QR code.',
          200,
        );
      }
      if (!mounted) return;
      setState(() {
        _qrCode = qrCode;
        _expiresAt = expiresAt.toInt();
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AuthApiException
            ? error.userMessage
            : 'Could not refresh the venue QR code: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText(widget.venueName, localize: true),
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppText(
            'Customers scan this code at arrival. It refreshes automatically.',
            textAlign: TextAlign.center,
            localize: true,
          ),
          const SizedBox(height: 12),
          if (_qrCode != null && _error == null)
            Container(
              key: const ValueKey('merchant-check-in-qr-code'),
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(
                data: _qrCode!,
                version: QrVersions.auto,
                size: 220,
              ),
            )
          else if (_loading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 220,
              child: Center(
                child: AppText(
                  _error ?? 'Check-in QR unavailable.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_expiresAt != null && _qrCode != null && _error == null) ...[
            const SizedBox(height: 8),
            AppText(
              'Code refreshes every minute · '
              'expires ${DateTime.fromMillisecondsSinceEpoch(_expiresAt!).toLocal().toString().substring(11, 16)}',
              style: TextStyle(color: _profileMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (_loading && _qrCode != null) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    ),
    actions: [
      if (_error != null)
        TextButton(
          onPressed: _loading ? null : _loadCode,
          child: const AppText('Retry', localize: true),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const AppText('Close', localize: true),
      ),
    ],
  );
}
