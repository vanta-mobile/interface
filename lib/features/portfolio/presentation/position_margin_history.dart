import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_margin_provider.dart';
import '../application/position_margin_storage_provider.dart';
import 'position_margin_screen.dart';
import '../../../core/presentation/status_view.dart';

class PositionMarginHistoryEntry extends ConsumerWidget {
  const PositionMarginHistoryEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(positionMarginStorageProvider);
    if (!storage.failed && storage.ready && ref.watch(currentPositionMarginsProvider).isEmpty) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      key: const Key('margin-adjust-history-entry'),
      onPressed: () => openPositionMargin(context),
      child: Text(AppLocalizations.of(context).marginAdjustHistory),
    );
  }
}

class PositionMarginHistory extends ConsumerWidget {
  const PositionMarginHistory({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), storage = ref.watch(positionMarginStorageProvider);
    final records = ref.watch(currentPositionMarginsProvider);
    final state = ref.watch(positionMarginProvider);
    final controller = ref.read(positionMarginProvider.notifier);
    final auth = ref.watch(authProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(l.marginAdjustHistory, style: Theme.of(context).textTheme.titleMedium),
        if (!storage.ready || storage.failed)
          StatusFailureView(
            message: l.marginAdjustStorage,
            retrying: state.busy,
            onRetry: () => ref.read(positionMarginStorageProvider.notifier).reload(),
          ),
        if (records.isEmpty && storage.ready && !storage.failed)
          StatusEmptyView(message: l.marginAdjustHistoryEmpty),
        for (final record in records.reversed)
          _Record(
            record: record,
            onCheck:
                state.busy ||
                    auth.busy ||
                    auth.identity?.signingAvailable != true ||
                    storage.failed ||
                    !storage.ready
                ? null
                : () => controller.check(record),
          ),
        Text(l.marginAdjustStopHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.record, required this.onCheck});
  final WalletOperationRecord record;
  final VoidCallback? onCheck;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), t = record.terms;
    final rejected = record.reference?.startsWith('rejected:') == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText('${t['symbol']} · ${t['side']}'),
          SelectableText(record.address),
          ValueRow(
            t['type'] == '1' ? l.marginAdjustAdd : l.marginAdjustRemove,
            '${t['amount']} ${t['asset']}',
          ),
          Text(l.marginAdjustReference),
          SelectableText(t['clientTranId']!),
          Text('${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.preparedAt.toUtc())} UTC'),
          Text(
            rejected
                ? l.marginAdjustRejected
                : record.acknowledged
                ? l.marginAdjustVerified
                : l.marginAdjustUnknown,
          ),
          if (!record.acknowledged)
            OutlinedButton(
              key: ValueKey('margin-adjust-check-${record.key}'),
              onPressed: onCheck,
              child: Text(l.marginAdjustCheck),
            ),
        ],
      ),
    );
  }
}
