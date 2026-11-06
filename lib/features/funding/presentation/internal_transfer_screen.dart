import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/symbol_settings_activity.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/internal_transfer_provider.dart';
import '../application/internal_transfer_storage_provider.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_form.dart';
import 'internal_transfer_status.dart';
import 'internal_transfer_confirmation.dart';

class InternalTransferScreen extends ConsumerWidget {
  const InternalTransferScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        auth = ref.watch(authProvider),
        controller = ref.read(internalTransferProvider.notifier);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.internalTransferTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('internal-transfer-scroll'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.internalTransferScope),
              const SizedBox(height: 12),
              Text(l10n.internalTransferRisk),
              Text(l10n.internalTransferReadHint),
              if (auth.identity?.walletAddress case final address?) SelectableText(address),
              const InternalTransferRecovery(),
              const _ReadControls(),
              const InternalTransferForm(),
              const _ReviewButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadControls extends ConsumerWidget {
  const _ReadControls();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(internalTransferProvider),
        auth = ref.watch(authProvider),
        controller = ref.read(internalTransferProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('internal-transfer-read'),
          onPressed: state.busy || auth.busy
              ? null
              : auth.identity?.signingAvailable == true
              ? controller.load
              : () => showAccountSheet(context),
          child: Text(l10n.internalTransferRead),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(switch (state.step) {
            InternalTransferStep.reading => l10n.internalTransferReading,
            InternalTransferStep.checking => l10n.internalTransferChecking,
            _ => l10n.internalTransferSending,
          }),
          TextButton(
            key: const Key('internal-transfer-stop'),
            onPressed: controller.stop,
            child: Text(l10n.subaccountStopWaiting),
          ),
        ],
        if (state.failure case final key?)
          Text(
            apiErrorText(context, key, state.errorDetails),
            style: const TextStyle(color: AppColors.warning),
          ),
      ],
    );
  }
}

class _ReviewButton extends ConsumerWidget {
  const _ReviewButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(internalTransferProvider),
        storage = ref.watch(internalTransferStorageProvider),
        activity = ref.watch(symbolSettingsActivityProvider),
        controller = ref.read(internalTransferProvider.notifier),
        l10n = AppLocalizations.of(context);
    final enabled =
        !state.busy &&
        !state.stale &&
        state.context != null &&
        state.context!.validate(state.amount) == null &&
        storage.ready &&
        !storage.failure &&
        ref.watch(pendingInternalTransfersProvider).isEmpty &&
        !activity.blocks(SymbolSetting.internalTransfer) &&
        ref.watch(authProvider).identity?.signingAvailable == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activity.blocks(SymbolSetting.internalTransfer)) Text(l10n.internalTransferBlocked),
        OutlinedButton(
          key: const Key('internal-transfer-review'),
          onPressed: enabled
              ? () async {
                  final review = controller.prepare();
                  if (review == null) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => InternalTransferConfirmation(review: review),
                  );
                  if (confirmed == true) {
                    await controller.confirm(review);
                  } else {
                    controller.cancel(review);
                  }
                }
              : null,
          child: Text(l10n.internalTransferReview),
        ),
      ],
    );
  }
}
