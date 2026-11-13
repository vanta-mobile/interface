import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order_peg.dart';

String liveOrderPegLabel(AppLocalizations l10n, LiveOrderPeg peg) =>
    peg == LiveOrderPeg.counterparty
    ? l10n.attachedEntryCounterparty(1)
    : l10n.attachedEntryQueue(1);

class LiveOrderPegSummary extends StatelessWidget {
  const LiveOrderPegSummary({super.key, required this.peg});
  final LiveOrderPeg peg;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderPricing, liveOrderPegLabel(l10n, peg)),
        Text(l10n.liveOrderPegHint),
      ],
    );
  }
}
