import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/order_cancellation.dart';

class OrderCancelProgress extends StatelessWidget {
  const OrderCancelProgress({super.key, required this.step});
  final OrderCancelStep step;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(switch (step) {
          OrderCancelStep.signing => l10n.orderCancelSigning,
          OrderCancelStep.submitting => l10n.orderCancelSubmitting,
          OrderCancelStep.checkSigning => l10n.orderCancelCheckSigning,
          OrderCancelStep.checking => l10n.orderCancelChecking,
          _ => l10n.accountReadPreparing,
        }),
      ],
    );
  }
}
