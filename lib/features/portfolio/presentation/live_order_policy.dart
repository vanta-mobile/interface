import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order_time_in_force.dart';

String _label(AppLocalizations l10n, LiveOrderTimeInForce policy) => switch (policy) {
  LiveOrderTimeInForce.gtc => l10n.liveOrderPolicyGtc,
  LiveOrderTimeInForce.ioc => l10n.liveOrderPolicyIoc,
  LiveOrderTimeInForce.postOnly => l10n.liveOrderPolicyPostOnly,
  LiveOrderTimeInForce.hidden => l10n.liveOrderPolicyHidden,
};

String _hint(AppLocalizations l10n, LiveOrderTimeInForce policy) => switch (policy) {
  LiveOrderTimeInForce.gtc => l10n.liveOrderPolicyGtcHint,
  LiveOrderTimeInForce.ioc => l10n.liveOrderPolicyIocHint,
  LiveOrderTimeInForce.postOnly => l10n.liveOrderPolicyPostOnlyHint,
  LiveOrderTimeInForce.hidden => l10n.liveOrderPolicyHiddenHint,
};

class LiveOrderPolicyField extends StatelessWidget {
  const LiveOrderPolicyField({
    super.key,
    required this.selected,
    required this.available,
    required this.enabled,
    required this.onChanged,
  });

  final LiveOrderTimeInForce selected;
  final Set<LiveOrderTimeInForce> available;
  final bool enabled;
  final ValueChanged<LiveOrderTimeInForce> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supported = available.contains(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.liveOrderPolicy),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LiveOrderTimeInForce>(
              key: const Key('live-order-policy'),
              isExpanded: true,
              value: supported ? selected : null,
              hint: Text(l10n.liveOrderPolicyChoose, maxLines: 1, overflow: TextOverflow.ellipsis),
              items: [
                for (final policy in LiveOrderTimeInForce.values)
                  if (available.contains(policy))
                    DropdownMenuItem(
                      value: policy,
                      child: Text(
                        _label(l10n, policy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: !enabled || available.isEmpty
                  ? null
                  : (value) {
                      if (value != null) onChanged(value);
                    },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(supported ? _hint(l10n, selected) : l10n.liveOrderTimeInForceUnavailable),
      ],
    );
  }
}

class LiveOrderPolicySummary extends StatelessWidget {
  const LiveOrderPolicySummary({super.key, required this.policy});
  final LiveOrderTimeInForce policy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [ValueRow(l10n.liveOrderPolicy, _label(l10n, policy)), Text(_hint(l10n, policy))],
    );
  }
}
