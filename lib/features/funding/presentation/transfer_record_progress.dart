import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/transfer_confirmation_provider.dart';
import '../domain/transfer_history.dart';
import 'transfer_history_components.dart';

class TransferRecordProgress extends ConsumerWidget {
  const TransferRecordProgress(this.record, {super.key});
  final TransferRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final key = transferConfirmationKey(record);
    final confirmation = key == null ? null : ref.watch(transferConfirmationProvider(key));
    final success = record.status == TransferStatus.success;
    final failed = record.status == TransferStatus.failed;
    return PortfolioCard(
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.assetHistoryProgress, style: AccountTypography.body),
          const SizedBox(height: 12),
          // A completed record implies the chain step. While the exchange is
          // still processing, only a successful canonical receipt confirms it.
          if (success || confirmation?.value == true)
            _Stage(l.assetHistoryConfirmed, 'history-check-circle.svg', size: 16)
          else if (confirmation != null && confirmation.isLoading && !confirmation.hasValue)
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: SkeletonBox(
                key: Key('transfer-confirmation-loading'),
                width: 180,
                height: 22,
                color: StatusColors.skeletonOnCard,
              ),
            )
          else
            _Stage(l.assetHistoryConfirmationUnavailable, 'history-clock.svg', size: 20),
          const SizedBox(height: 12),
          _Stage(
            failed
                ? l.transferStatus('failed')
                : success
                ? record.type == TransferType.deposit
                      ? l.assetHistoryDepositCompleted
                      : l.assetHistoryWithdrawCompleted
                : record.type == TransferType.deposit
                ? l.assetHistoryCrediting
                : l.assetHistoryWithdrawPending,
            success ? 'history-check-circle.svg' : 'history-pending.svg',
            size: success ? 16 : 20,
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage(this.label, this.asset, {required this.size});
  final String label, asset;
  final double size;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 22),
    child: Row(
      children: [
        HistoryGlyph(asset, size: size),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: PortfolioTypography.caption)),
      ],
    ),
  );
}
