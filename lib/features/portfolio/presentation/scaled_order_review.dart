import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/scaled_order_provider.dart';
import '../domain/futures_position_mode.dart';
import '../domain/position_margin_mode.dart';
import '../domain/scaled_order.dart';
import 'live_order_funds_panel.dart';
import 'scaled_order_details.dart';

Future<void> reviewScaledOrder(
  BuildContext context,
  WidgetRef ref,
  ScaledOrderIntent intent,
) async {
  final controller = ref.read(scaledOrderProvider.notifier);
  final data = intent.context;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        scrollable: true,
        title: Text(l10n.scaledReview),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.liveOrderConfirmHint),
            SelectableText(intent.address),
            SelectableText('${data.symbol} · ${l10n.perps}'),
            ValueRow(
              l10n.positionModeSettings,
              data.mode == FuturesPositionMode.oneWay
                  ? l10n.positionModeOneWay
                  : l10n.positionModeHedge,
            ),
            ValueRow(
              l10n.accountMarginMode,
              data.marginMode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode,
            ),
            ValueRow(l10n.leverageCurrentSetting, '${data.leverage}×'),
            Text('${l10n.limit} · ${l10n.liveOrderPolicyGtc}'),
            LiveOrderFundsPanel(data: data),
            Text(l10n.scaledRule),
            Text(l10n.scaledRisk),
            ScaledPlanDetails(plan: intent.plan, data: data, clientIds: intent.clientIds),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('scaled-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.scaledConfirm),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) await controller.submit(intent);
}
