import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/transfer_history.dart';
import 'transfer_history_components.dart';

class TransferRecordProgress extends StatelessWidget {
  const TransferRecordProgress(this.record, {super.key});
  final TransferRecord record;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final success = record.status == TransferStatus.success;
    final failed = record.status == TransferStatus.failed;
    return PortfolioCard(
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.assetHistoryProgress, style: AccountTypography.body),
          const SizedBox(height: 12),
          // History reports only the overall exchange status. A hash or a
          // PROCESSING state cannot prove that a transaction was mined.
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
