import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/batch_close_provider.dart';
import '../application/position_risk_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/batch_close.dart';

class BatchCloseControls extends ConsumerWidget {
  const BatchCloseControls({super.key, this.symbol});
  final String? symbol;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(authProvider);
    ref.watch(batchCloseProvider);
    ref.watch(positionRiskProvider);
    ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(batchCloseProvider.notifier);
    final enabled = controller.prepare(symbol: symbol) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OrderRecoveryNotice(),
        OutlinedButton.icon(
          key: const Key('batch-close-open'),
          onPressed: enabled ? () => confirmBatchClose(context, ref, symbol: symbol) : null,
          icon: const Icon(Icons.close_fullscreen),
          label: Text(symbol == null ? l10n.batchCloseAll : l10n.batchCloseCurrent),
        ),
        if (!enabled) Text(l10n.batchCloseReadFirst, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Future<void> confirmBatchClose(BuildContext context, WidgetRef ref, {String? symbol}) async {
  final controller = ref.read(batchCloseProvider.notifier),
      intent = controller.prepare(symbol: symbol);
  if (intent == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        scrollable: true,
        title: Text(l10n.batchCloseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.batchCloseHint),
            SelectableText(intent.address),
            Text(intent.symbol == null ? l10n.batchCloseAll : l10n.batchCloseCurrent),
            if (intent.symbol != null) SelectableText(intent.symbol!),
            Text(l10n.batchCloseCount(intent.targets.length)),
            for (final target in intent.targets) BatchCloseTargetDetails(target: target),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('batch-close-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.batchCloseConfirm),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) await controller.submit(intent);
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
