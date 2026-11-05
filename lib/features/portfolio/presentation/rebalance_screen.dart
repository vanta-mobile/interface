import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../../auth/application/auth_provider.dart';
import '../application/rebalance_provider.dart';
import '../application/rebalance_storage_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/asset_rebalance.dart';
import 'futures_asset_mode_status.dart';

class RebalanceScreen extends ConsumerWidget {
  const RebalanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(rebalanceProvider),
        auth = ref.watch(authProvider);
    final controller = ref.read(rebalanceProvider.notifier),
        pending = ref.watch(pendingRebalancesProvider),
        storage = ref.watch(rebalanceStorageProvider);
    final c = state.context;
    final canReview =
        !state.busy &&
        !state.stale &&
        c?.needed == true &&
        pending.isEmpty &&
        storage.ready &&
        !storage.failure &&
        !ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.rebalance);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.rebalanceTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('rebalance-scroll'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.rebalanceScope),
              Text(l10n.rebalanceRisk),
              Text(l10n.rebalanceReadHint),
              if (auth.identity?.walletAddress case final address?) SelectableText(address),
              const _RebalanceRecoveryTerms(),
              const _RebalanceReadControls(),
              if (c != null) _RebalanceSnapshot(contextData: c, stale: state.stale),
              if (state.reply case final reply?) RebalanceReplyPanel(reply: reply),
              _RebalanceReviewButton(enabled: canReview),
              Text(l10n.rebalancePermission),
            ],
          ),
        ),
      ),
    );
  }
}

class RebalanceConfirmation extends ConsumerWidget {
  const RebalanceConfirmation({super.key, required this.review});
  final RebalanceReview review;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        valid = identical(ref.watch(rebalanceProvider).review, review);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.rebalanceReview),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rebalanceRisk),
          SelectableText(review.context.address),
          ValueRow(l10n.rebalanceCurrentMode, assetModeLabel(l10n, review.context.mode)),
          ValueRow(l10n.rebalanceUsdt, '${review.context.usdt} USDT'),
          for (final asset in review.context.account.assets)
            ValueRow(asset.asset, '${asset.walletBalance} ${asset.asset}'),
          if (!valid) Text(l10n.rebalanceChanged),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rebalance-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.rebalanceCancel),
        ),
        FilledButton(
          key: const Key('rebalance-confirm'),
          onPressed: valid ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.rebalanceConfirm),
        ),
      ],
    );
  }
}

class RebalanceReplyPanel extends StatelessWidget {
  const RebalanceReplyPanel({super.key, required this.reply});
  final RebalanceReply reply;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(reply.noExchange ? l10n.rebalanceNoExchange : l10n.rebalanceReported),
        if (!reply.noExchange) ...[
          Text(l10n.rebalanceAccountId),
          SelectableText(reply.accountId!),
          ValueRow(l10n.rebalanceReportedBalance, '${reply.balance} ${reply.asset}'),
          Text(l10n.rebalanceReportedTime),
          Text(reply.updateTime!.toUtc().toIso8601String()),
        ],
      ],
    );
  }
}

class _RebalanceRecoveryTerms extends ConsumerWidget {
  const _RebalanceRecoveryTerms();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        storage = ref.watch(rebalanceStorageProvider),
        pending = ref.watch(pendingRebalancesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!storage.ready || storage.failure) ...[
          Text(l10n.rebalanceStorage, style: const TextStyle(color: AppColors.warning)),
          TextButton(
            key: const Key('rebalance-storage-retry'),
            onPressed: ref.read(rebalanceStorageProvider.notifier).reload,
            child: Text(l10n.notificationRetry),
          ),
        ],
        for (final record in pending) ...[
          Text(record.reply == null ? l10n.rebalanceUnknown : l10n.rebalanceReplyPending),
          Text(l10n.rebalanceNonce),
          SelectableText('${record.nonce}'),
          Text(record.preparedAt.toUtc().toIso8601String()),
        ],
      ],
    );
  }
}

class _RebalanceReadControls extends ConsumerWidget {
  const _RebalanceReadControls();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(rebalanceProvider),
        auth = ref.watch(authProvider);
    final controller = ref.read(rebalanceProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('rebalance-read'),
          onPressed: state.busy || auth.busy
              ? null
              : auth.identity?.signingAvailable == true
              ? controller.load
              : () => showAccountSheet(context),
          child: Text(l10n.rebalanceRead),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(state.step == RebalanceStep.reading ? l10n.rebalanceReading : l10n.rebalanceSending),
          TextButton(
            key: const Key('rebalance-stop'),
            onPressed: controller.stop,
            child: Text(l10n.subaccountStopWaiting),
          ),
        ],
        if (state.failure case final key?)
          Text(switch (key) {
            'rebalanceStorage' => l10n.rebalanceStorage,
            'rebalancePending' => l10n.rebalancePending,
            'rebalanceChanged' => l10n.rebalanceChanged,
            _ => tr(context, key),
          }, style: const TextStyle(color: AppColors.warning)),
      ],
    );
  }
}

class _RebalanceSnapshot extends StatelessWidget {
  const _RebalanceSnapshot({required this.contextData, required this.stale});
  final RebalanceContext contextData;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final c = contextData, l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale) Text(l10n.rebalanceStale, style: const TextStyle(color: AppColors.warning)),
        ValueRow(l10n.rebalanceCurrentMode, assetModeLabel(l10n, c.mode)),
        ValueRow(l10n.rebalanceUsdt, c.usdt == null ? '—' : '${c.usdt} USDT'),
        Text(
          c.usdt == null
              ? l10n.rebalanceUnknownUsdt
              : c.needed
              ? l10n.rebalanceRequired
              : l10n.rebalanceNotNeeded,
        ),
        Text(l10n.accountSnapshotTime(c.receivedAt.toUtc().toIso8601String())),
        for (final asset in c.account.assets)
          ValueRow(asset.asset, '${asset.walletBalance} ${asset.asset}'),
      ],
    );
  }
}

class _RebalanceReviewButton extends ConsumerWidget {
  const _RebalanceReviewButton({required this.enabled});
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), controller = ref.read(rebalanceProvider.notifier);
    return OutlinedButton(
      key: const Key('rebalance-review'),
      onPressed: enabled
          ? () async {
              final review = controller.prepare();
              if (review == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => RebalanceConfirmation(review: review),
              );
              if (confirmed == true) {
                await controller.confirm(review);
              } else {
                controller.cancel(review);
              }
            }
          : null,
      child: Text(l10n.rebalanceReview),
    );
  }
}
