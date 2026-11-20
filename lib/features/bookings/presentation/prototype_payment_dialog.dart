import 'package:flutter/material.dart';

import 'package:myapp/core/app_text.dart';

class PrototypePaymentDialog extends StatefulWidget {
  const PrototypePaymentDialog({super.key, required this.amount});

  final double amount;

  @override
  State<PrototypePaymentDialog> createState() => _PrototypePaymentDialogState();
}

class _PrototypePaymentDialogState extends State<PrototypePaymentDialog> {
  String _scenario = 'success';
  String _method = 'synthetic';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Prototype demo checkout', localize: true),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            'Amount due: \u{20B1} ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Demo only. No real charge will be made. Do not enter card numbers, CVCs, wallet PINs, passwords, or verification codes.',
            localize: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('prototype-payment-scenario'),
            initialValue: _scenario,
            decoration: const InputDecoration(
              labelText: 'Choose simulated result',
            ),
            items: const [
              DropdownMenuItem(value: 'success', child: Text('Success')),
              DropdownMenuItem(value: 'decline', child: Text('Decline')),
              DropdownMenuItem(
                value: 'cancel',
                child: Text('User cancellation'),
              ),
              DropdownMenuItem(value: 'timeout', child: Text('Timeout')),
              DropdownMenuItem(
                value: 'error',
                child: Text('Recoverable error'),
              ),
            ],
            onChanged: (scenario) {
              if (scenario != null) setState(() => _scenario = scenario);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('prototype-payment-method'),
            initialValue: _method,
            decoration: const InputDecoration(
              labelText: 'Synthetic demo method',
            ),
            items: const [
              DropdownMenuItem(
                value: 'synthetic',
                child: Text('Synthetic demo wallet'),
              ),
              DropdownMenuItem(
                value: 'synthetic_card',
                child: Text('Synthetic demo card'),
              ),
            ],
            onChanged: (method) {
              if (method != null) setState(() => _method = method);
            },
          ),
          const SizedBox(height: 12),
          AppText(
            _scenario == 'success'
                ? 'Success will be verified by the server before payment status changes.'
                : 'This result stays unpaid and can be retried while the 15-minute payment window is active.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(null),
        child: const AppText('Cancel', localize: true),
      ),
      FilledButton(
        key: const ValueKey('prototype-payment-confirm'),
        onPressed: () =>
            Navigator.of(context)
                .pop({'provider': _method, 'scenario': _scenario}),
        child: const AppText('Run demo checkout', localize: true),
      ),
    ],
  );
}
