import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/order_confirmation_provider.dart';
import '../domain/order_confirmation.dart';
import '../domain/live_order.dart';

String orderConfirmationLabel(AppLocalizations l10n, OrderConfirmationKind kind) => switch (kind) {
  OrderConfirmationKind.limit => l10n.orderConfirmLimit,
  OrderConfirmationKind.market => l10n.quickOrderConfirmPreference,
  OrderConfirmationKind.stopLimit => l10n.orderConfirmStopLimit,
  OrderConfirmationKind.stopMarket => l10n.orderConfirmStopMarket,
  OrderConfirmationKind.trailing => l10n.orderConfirmTrailing,
};

class OrderConfirmationControl extends ConsumerWidget {
  const OrderConfirmationControl({super.key, required this.kind, required this.enabled});
  final OrderConfirmationKind kind;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderConfirmationProvider(kind));
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: ValueKey('order-confirmation-${kind.name}'),
          contentPadding: EdgeInsets.zero,
          title: Text(orderConfirmationLabel(l10n, kind)),
          subtitle: kind == OrderConfirmationKind.limit ? Text(l10n.orderConfirmLimitShared) : null,
          value: state.required,
          onChanged: !enabled || state.loading
              ? null
              : ref.read(orderConfirmationProvider(kind).notifier).select,
        ),
        if (state.failure) Text(l10n.quickOrderPreferenceFailure),
        Text(l10n.orderConfirmWalletHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class LiveOrderSubmitControls extends ConsumerWidget {
  const LiveOrderSubmitControls({
    super.key,
    required this.draft,
    required this.enabled,
    required this.onSubmit,
    this.pending = false,
  });
  final LiveOrderDraft draft;
  final bool enabled;
  final VoidCallback? onSubmit;
  final bool pending;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = orderConfirmationKind(draft), l10n = AppLocalizations.of(context);
    final canSkip = !draft.reducing && ref.watch(orderConfirmationProvider(kind)).canSkip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!draft.reducing) OrderConfirmationControl(kind: kind, enabled: enabled),
        FilledButton(
          key: const Key('live-order-review'),
          onPressed: enabled && !pending ? onSubmit : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              Text(canSkip ? l10n.liveOrderSignSubmit : l10n.liveOrderReview),
            ],
          ),
        ),
      ],
    );
  }
}
