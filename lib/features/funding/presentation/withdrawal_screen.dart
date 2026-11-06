import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../../core/presentation/wallet_operation_history.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/transfer_history_provider.dart';
import '../application/withdrawal_provider.dart';
import '../domain/deposit_wallet.dart';
import '../domain/transfer_history.dart';
import '../domain/withdrawal_recovery.dart';
import 'transfer_history_screen.dart';

void openWithdrawal(BuildContext context, DepositWalletQuery query) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => WithdrawalScreen(query: query)));

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key, required this.query});
  final DepositWalletQuery query;
  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final amount = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(withdrawalProvider.notifier).cancel();
    });
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        s = ref.watch(withdrawalProvider),
        auth = ref.watch(authProvider),
        q = widget.query;
    final controller = ref.read(withdrawalProvider.notifier);
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (a, b) {
        if (a != b) {
          amount.clear();
        }
      },
    );
    final relevant = s.review?.query == q ? s.review : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.withdrawalSubmit)),
      body: SafeArea(
        child: ListView(
          key: const Key('withdrawal-page'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.withdrawalScope),
            SelectableText(
              '${q.asset.asset} · ${q.market == TransferMarket.spot ? l.transferSpotMarket : l.transferPerpMarket} · ${q.asset.chainId}',
            ),
            Text(l.withdrawalReceiver),
            if (auth.identity?.walletAddress case final address?) SelectableText(address),
            TextField(
              key: const Key('withdrawal-amount'),
              controller: amount,
              enabled: !s.busy && s.review == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.internalTransferAmount),
            ),
            FilledButton(
              key: const Key('withdrawal-prepare'),
              onPressed:
                  s.busy || s.review != null || auth.busy || auth.identity?.walletAddress == null
                  ? null
                  : () => controller.prepare(q, amount.text.trim()),
              child: Text(l.withdrawalPrepare),
            ),
            if (relevant case final review?) ...[
              const Divider(),
              Text(l.withdrawalReview),
              SelectableText('${review.amount} ${q.asset.asset}'),
              Text(l.withdrawalFee),
              SelectableText('${review.fee.assetFee} ${q.asset.asset}'),
              Text(l.withdrawalMarket),
              Text(q.market == TransferMarket.spot ? l.transferSpotMarket : l.transferPerpMarket),
              Text(l.withdrawalChain),
              Text('${q.asset.chainId}'),
              Text(l.withdrawalReceiver),
              SelectableText(review.identity.walletAddress!),
              Text(l.withdrawalConfirmScope),
              FilledButton(
                key: const Key('withdrawal-confirm'),
                onPressed: s.busy ? null : () => controller.confirm(review),
                child: Text(l.withdrawalConfirm),
              ),
              TextButton(
                onPressed: s.busy ? null : controller.cancel,
                child: Text(tr(context, 'cancel')),
              ),
            ],
            if (s.busy) ...[
              const LinearProgressIndicator(),
              TextButton(onPressed: controller.stop, child: Text(l.subaccountStopWaiting)),
            ],
            if (s.failure case final key?)
              Text(
                apiErrorText(context, key, s.errorDetails),
                style: const TextStyle(color: AppColors.negative),
              ),
            if (s.result case final result?
                when result.terms['asset'] == q.asset.asset &&
                    result.terms['market'] == q.market.name &&
                    result.terms['chain'] == '${q.asset.chainId}')
              Text(l.withdrawalAcknowledged),
            const Divider(),
            const _WithdrawalRecovery(),
            const Divider(),
            const WalletOperationHistory(withdrawals: true),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalRecovery extends ConsumerWidget {
  const _WithdrawalRecovery();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), history = ref.watch(transferHistoryProvider);
    final operations = ref
        .watch(currentWalletOperationsProvider)
        .where((r) => r.kind == WalletOperationKind.withdrawal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.withdrawalRecovery),
        Text(l.withdrawalRecoveryScope),
        OutlinedButton(
          key: const Key('withdrawal-history-open'),
          onPressed: () => openTransferHistory(context),
          child: Text(l.withdrawalOpenHistory),
        ),
        for (final op in operations) ...[
          SelectableText(op.reference ?? '${l.walletOperationReference}: ${op.nonce}'),
          Builder(
            builder: (context) {
              final match = history.account == null
                  ? null
                  : reconcileWithdrawal(op, history.account!);
              return Text(
                match == null
                    ? l.withdrawalNotReconciled
                    : history.stale
                    ? l.withdrawalHistoryStale
                    : switch (match.status) {
                        TransferStatus.processing => l.withdrawalProcessing,
                        TransferStatus.success => l.withdrawalCompleted,
                        TransferStatus.failed => l.withdrawalFailed,
                      },
              );
            },
          ),
        ],
      ],
    );
  }
}
