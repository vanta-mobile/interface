import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order_time_in_force.dart';

String liveOrderPolicyLabel(AppLocalizations l10n, LiveOrderTimeInForce policy) => switch (policy) {
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

class LiveOrderPolicySummary extends StatelessWidget {
  const LiveOrderPolicySummary({super.key, required this.policy});
  final LiveOrderTimeInForce policy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderPolicy, liveOrderPolicyLabel(l10n, policy)),
        Text(_hint(l10n, policy)),
      ],
    );
  }
}
