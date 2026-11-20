import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../application/batch_close_provider.dart';
import '../domain/batch_close.dart';
import 'open_order_cancel_prompts.dart';

/// Design confirmation sheet; confirming closes every listed position at
/// market straight away. Positions are re-read silently when the snapshot has
/// gone stale; if they changed meanwhile, the new set is confirmed again. The
/// outcome is a toast: success once every close was placed and verified,
/// otherwise the first failure's cause.
Future<void> confirmBatchClose(BuildContext context, WidgetRef ref, {String? symbol}) async {
  final controller = ref.read(batchCloseProvider.notifier);
  var intent = await controller.prepareCurrent(symbol: symbol);
  while (intent != null) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context), count = intent.targets.length;
    final confirmed = await showWarningConfirmSheet(
      context,
      title: l10n.positionsCloseAll,
      message: intent.symbol == null
          ? l10n.positionsCloseAllQuestion(count)
          : l10n.positionsCloseSymbolQuestion(intent.symbol!, count),
      confirmKey: const Key('batch-close-confirm'),
    );
    if (!confirmed || !context.mounted) return;
    final current = await controller.renew(intent);
    if (current == null) return;
    if (_sameTargets(current, intent)) {
      await controller.submit(current);
      if (context.mounted) _showOutcome(context, ref.read(batchCloseProvider), current);
      return;
    }
    intent = current;
  }
}

void _showOutcome(BuildContext context, BatchCloseState state, BatchCloseIntent intent) {
  if (!identical(state.intent, intent) || state.busy) return;
  final items = state.items.values;
  final failure = items
      .map((item) => item.failure ?? item.result?.failure)
      .firstWhere((failure) => failure != null, orElse: () => null);
  if (failure != null) {
    AppToast.showFailure(context, accountErrorText(context, failure));
  } else if (items.isNotEmpty && items.every((item) => item.submitted)) {
    AppToast.showSuccess(context, AppLocalizations.of(context).batchCloseDone(items.length));
  }
}

bool _sameTargets(BatchCloseIntent a, BatchCloseIntent b) =>
    a.targets.map((t) => t.key).toSet().containsAll(b.targets.map((t) => t.key)) &&
    a.targets.length == b.targets.length;
