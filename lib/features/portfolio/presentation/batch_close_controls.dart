import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/batch_close_provider.dart';
import '../domain/batch_close.dart';
import 'open_order_cancel_prompts.dart';

/// Design confirmation sheet; confirming closes every listed position at
/// market straight away.
Future<void> confirmBatchClose(BuildContext context, WidgetRef ref, {String? symbol}) async {
  final controller = ref.read(batchCloseProvider.notifier),
      intent = controller.prepare(symbol: symbol);
  if (intent == null) return;
  final l10n = AppLocalizations.of(context), count = intent.targets.length;
  final confirmed = await showWarningConfirmSheet(
    context,
    title: l10n.positionsCloseAll,
    message: intent.symbol == null
        ? l10n.positionsCloseAllQuestion(count)
        : l10n.positionsCloseSymbolQuestion(intent.symbol!, count),
    confirmKey: const Key('batch-close-confirm'),
  );
  if (confirmed && context.mounted) await controller.submit(intent);
}

class BatchCloseTargetDetails extends StatelessWidget {
  const BatchCloseTargetDetails({super.key, required this.target});
  final BatchCloseTarget target;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), p = target.position;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(p.symbol, style: Theme.of(context).textTheme.titleSmall),
          SelectableText(p.side),
          Text(p.long ? l10n.liveCloseLong : l10n.liveCloseShort),
          ValueRow(
            l10n.quantity,
            '${p.quantity.abs()} ${p.units?.base ?? l10n.accountUnitUnavailable}',
          ),
          Text(l10n.liveOrderClientId),
          SelectableText(target.clientOrderId),
        ],
      ),
    );
  }
}
