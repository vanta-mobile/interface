import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/attached_entry_peg.dart';

String attachedEntryPegLabel(AppLocalizations l10n, AttachedEntryPeg peg) => peg.counterparty
    ? l10n.attachedEntryCounterparty(peg.depth)
    : l10n.attachedEntryQueue(peg.depth);

class AttachedEntryPricing extends StatelessWidget {
  const AttachedEntryPricing({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.postOnly = false,
  });
  final bool postOnly;
  final AttachedEntryPeg? selected;
  final bool enabled;
  final ValueChanged<AttachedEntryPeg?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.attachedEntryPricing),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('attached-entry-pricing'),
              isExpanded: true,
              itemHeight: null,
              value: selected?.wire ?? 'fixed',
              items: [
                DropdownMenuItem(value: 'fixed', child: Text(l10n.attachedEntryFixed)),
                for (final peg in AttachedEntryPeg.values)
                  if (!postOnly || peg == AttachedEntryPeg.queue1)
                    DropdownMenuItem(
                      value: peg.wire,
                      child: Text(attachedEntryPegLabel(l10n, peg)),
                    ),
              ],
              onChanged: !enabled
                  ? null
                  : (wire) => onChanged(
                      AttachedEntryPeg.values.where((p) => p.wire == wire).singleOrNull,
                    ),
            ),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Text(l10n.attachedEntryPegTiming),
          Text(l10n.attachedEntryPegEstimate),
        ],
      ],
    );
  }
}

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
