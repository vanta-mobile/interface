import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/presentation/account_snapshot_status.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/deposit_wallet_provider.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_messages.dart';
import 'withdraw_info_panel.dart';

class DepositWalletPanel extends ConsumerWidget {
  const DepositWalletPanel({super.key, required this.query});
  final DepositWalletQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(depositWalletProvider(query));
    final session = ref.watch(authProvider), snapshot = state.account;
    final controller = ref.read(depositWalletProvider(query).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.identity?.walletAddress case final address?)
          SelectableText(address, key: const Key('deposit-wallet-address')),
        FilledButton(
          key: const Key('deposit-wallet-read'),
          onPressed: state.busy || session.busy
              ? null
              : session.identity?.walletAddress == null
              ? () => showAccountSheet(context)
              : controller.refresh,
          child: Text(l10n.depositReadWallet),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          TextButton(
            key: const Key('deposit-wallet-stop'),
            onPressed: controller.stop,
            child: Text(l10n.subaccountStopWaiting),
          ),
        ],
        if (state.failure case final failure?)
          Text(
            depositMessage(context, failure.key),
            style: const TextStyle(color: AppColors.negative),
          ),
        AccountSnapshotStatus(state: state),
        if (snapshot != null) ...[
          ValueRow(
            l10n.depositAssetBalance,
            fundingAmount(snapshot.assetBalance, query.asset.asset),
          ),
          ValueRow(
            l10n.depositNativeBalance,
            fundingAmount(snapshot.nativeBalance, query.asset.chainId == 56 ? 'BNB' : 'ETH'),
          ),
          if (!query.asset.isNative) ...[
            ValueRow(l10n.depositAllowance, fundingAmount(snapshot.allowance, query.asset.asset)),
            Text(l10n.depositSpenderScope),
            SelectableText(depositVaults[query.asset.chainId]!),
          ],
          ValueRow(l10n.depositBlock, snapshot.blockNumber.toString()),
          SelectableText(snapshot.blockHash),
        ],
      ],
    );
  }
}
