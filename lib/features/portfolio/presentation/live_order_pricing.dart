import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order_peg.dart';

String liveOrderPegLabel(AppLocalizations l10n, LiveOrderPeg peg) =>
    peg == LiveOrderPeg.counterparty
    ? l10n.attachedEntryCounterparty(1)
    : l10n.attachedEntryQueue(1);

class LiveOrderPricing extends StatelessWidget {
  const LiveOrderPricing({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.postOnly = false,
  });
  final bool postOnly;
  final LiveOrderPeg? selected;
  final bool enabled;
  final ValueChanged<LiveOrderPeg?> onChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          key: const Key('live-order-bbo'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.liveOrderBbo),
          value: selected != null,
          onChanged: !enabled
              ? null
              : (value) => onChanged(
                  value ? (postOnly ? LiveOrderPeg.queue : LiveOrderPeg.counterparty) : null,
                ),
        ),
        if (selected != null)
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.liveOrderPricing),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('live-order-pricing'),
                isExpanded: true,
                itemHeight: null,
                value: selected?.wire,
                items: [
                  for (final peg in LiveOrderPeg.values)
                    if (!postOnly || peg == LiveOrderPeg.queue)
                      DropdownMenuItem(value: peg.wire, child: Text(liveOrderPegLabel(l10n, peg))),
                ],
                onChanged: !enabled
                    ? null
                    : (wire) =>
                          onChanged(LiveOrderPeg.values.where((p) => p.wire == wire).singleOrNull),
              ),
            ),
          ),
        if (selected != null) Text(l10n.liveOrderPegHint),
      ],
    );
  }
}

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
