import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order.dart';
import '../domain/live_order_peg.dart';
import '../domain/live_order_time_in_force.dart';
import 'attached_entry_pricing.dart';
import 'live_order_policy.dart';
import 'live_order_pricing.dart';

class LiveOrderPriceInputs extends StatelessWidget {
  const LiveOrderPriceInputs({
    super.key,
    required this.data,
    required this.draft,
    required this.price,
    required this.policy,
    required this.peg,
    required this.entryPeg,
    required this.enabled,
    required this.onPolicy,
    required this.onPeg,
    required this.onEntryPeg,
    required this.onPrice,
    this.fixedPolicy = false,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final TextEditingController price;
  final LiveOrderTimeInForce policy;
  final LiveOrderPeg? peg;
  final AttachedEntryPeg? entryPeg;
  final bool enabled;
  final bool fixedPolicy;
  final ValueChanged<LiveOrderTimeInForce> onPolicy;
  final ValueChanged<LiveOrderPeg?> onPeg;
  final ValueChanged<AttachedEntryPeg?> onEntryPeg;
  final VoidCallback onPrice;
  @override
  Widget build(BuildContext context) {
    if (draft.market) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiveOrderPolicyField(
          selected: policy,
          available: fixedPolicy
              ? data.rules.timeInForce.intersection({LiveOrderTimeInForce.postOnly})
              : data.rules.timeInForce,
          enabled: enabled && !fixedPolicy,
          onChanged: onPolicy,
        ),
        if (draft.attachment != null)
          AttachedEntryPricing(selected: entryPeg, enabled: enabled, onChanged: onEntryPeg)
        else
          LiveOrderPricing(selected: peg, enabled: enabled, onChanged: onPeg),
        const SizedBox(height: 12),
        if (!draft.pegged)
          TextField(
            key: const Key('live-order-price'),
            controller: price,
            readOnly: !enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.liveOrderPrice(data.rules.quoteAsset),
              helperText: l10n.liveOrderPriceTick('${data.rules.priceTick}'),
            ),
            onChanged: (_) => onPrice(),
          ),
      ],
    );
  }
}
