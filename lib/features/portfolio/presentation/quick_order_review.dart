import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/order_confirmation_provider.dart';
import '../application/quick_order_provider.dart';
import '../domain/live_order.dart';
import '../../auth/application/auth_provider.dart';

Future<void> reviewQuickOrder(BuildContext context, WidgetRef ref, LiveOrderIntent intent) async {
  final preference = ref.read(marketOrderConfirmationProvider);
  final identity = ref.read(authProvider).identity;
  var skipNext = false;
  var confirmed = preference.canSkip;
  if (!confirmed) {
    confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final l10n = AppLocalizations.of(context);
              return AlertDialog(
                scrollable: true,
                title: Text(l10n.quickOrderConfirmation),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(intent.context.address),
                    SelectableText(intent.context.symbol),
                    ValueRow(l10n.liveOrderSide, intent.draft.buy ? l10n.long : l10n.short),
                    ValueRow(
                      l10n.liveOrderQuantity(intent.context.rules.baseAsset),
                      intent.draft.quantity,
                    ),
                    Text(l10n.quickOrderHint),
                    CheckboxListTile(
                      key: const Key('quick-order-skip-confirmation'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.quickOrderDoNotShow),
                      value: skipNext,
                      onChanged: (value) => setState(() => skipNext = value ?? false),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    key: const Key('quick-order-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(intent.draft.buy ? l10n.quickOrderBuy : l10n.quickOrderSell),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  }
  if (!confirmed || !context.mounted || !identical(identity, ref.read(authProvider).identity)) {
    return;
  }
  if (skipNext) await ref.read(marketOrderConfirmationProvider.notifier).select(false);
  if (context.mounted) await ref.read(quickOrderProvider.notifier).submit(intent);
}
