import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/attached_entry_peg.dart';

String attachedEntryPegLabel(AppLocalizations l10n, AttachedEntryPeg peg) => peg.counterparty
    ? l10n.attachedEntryCounterparty(peg.depth)
    : l10n.attachedEntryQueue(peg.depth);

class AttachedEntryPegSummary extends StatelessWidget {
  const AttachedEntryPegSummary({super.key, required this.peg, this.showEstimate = true});
  final AttachedEntryPeg peg;
  final bool showEstimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.attachedEntryPricing, attachedEntryPegLabel(l10n, peg)),
        Text(l10n.attachedEntryPegTiming),
        if (showEstimate) Text(l10n.attachedEntryPegEstimate),
      ],
    );
  }
}
