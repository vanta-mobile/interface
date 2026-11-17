import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order_time_in_force.dart';

String liveOrderPolicyLabel(AppLocalizations l10n, LiveOrderTimeInForce policy) => switch (policy) {
  LiveOrderTimeInForce.gtc => l10n.liveOrderPolicyGtc,
  LiveOrderTimeInForce.ioc => l10n.liveOrderPolicyIoc,
  LiveOrderTimeInForce.postOnly => l10n.liveOrderPolicyPostOnly,
  LiveOrderTimeInForce.hidden => l10n.liveOrderPolicyHidden,
};
