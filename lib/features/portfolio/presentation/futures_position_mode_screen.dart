import 'futures_position_mode_sheet.dart';
import 'mode_settings_sheet.dart';
import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/futures_position_mode_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/futures_position_mode.dart';
import 'futures_position_mode_status.dart';
import 'futures_position_mode_form.dart';
import 'symbol_settings_notice.dart';

Future<void> openPositionModeSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const FuturesPositionModeSheet());

class FuturesPositionModeScreen extends ConsumerStatefulWidget {
  const FuturesPositionModeScreen({super.key});
  @override
  ConsumerState<FuturesPositionModeScreen> createState() => _FuturesPositionModeScreenState();
}

class _FuturesPositionModeScreenState extends ConsumerState<FuturesPositionModeScreen> {
  FuturesPositionMode? target;
  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (
      before,
      after,
    ) {
      if (before != after) setState(() => target = null);
    });
    final l10n = AppLocalizations.of(context), state = ref.watch(futuresPositionModeProvider);
    final auth = ref.watch(authProvider), identity = auth.identity;
    final settings = state.context;
    final otherBlocked = ref
        .watch(symbolSettingsActivityProvider)
        .blocks(SymbolSetting.positionMode);
    final controller = ref.read(futuresPositionModeProvider.notifier);
    final intent = target == null ? null : controller.prepare(target!);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.positionModeSettings)),
      body: SafeArea(
        child: ListView(
          key: const Key('position-mode-page'),
          padding: const EdgeInsets.all(16),
          children: [
            const OrderRecoveryNotice(),
            Text(l10n.positionModeAllSymbols, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l10n.positionModeSettingsScope),
            const SizedBox(height: 8),
            Text(l10n.positionModeOneWayHint, style: Theme.of(context).textTheme.bodySmall),
            Text(l10n.positionModeHedgeHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (identity?.walletAddress case final address?) SelectableText(address),
            const SymbolSettingsNotice(setting: SymbolSetting.positionMode),
            FilledButton.icon(
              key: const Key('position-mode-read'),
              onPressed: state.busy || state.needsRecheck || otherBlocked || auth.busy
                  ? null
                  : identity?.signingAvailable == true && identity?.walletAddress != null
                  ? () => controller.load()
                  : () => showAccountSheet(context),
              icon: const Icon(Icons.refresh),
              label: Text(
                identity == null
                    ? l10n.accountSignInToRead
                    : identity.walletAddress == null
                    ? l10n.createWallet
                    : !identity.signingAvailable
                    ? l10n.reconnectExternalWallet
                    : l10n.positionModeReadSettings,
              ),
            ),
            Text(l10n.positionModeReadHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const FuturesPositionModeStatus(),
            if (settings != null)
              FuturesPositionModeForm(
                settings: settings,
                stale: state.stale,
                busy: state.busy,
                target: target,
                onChanged: (value) => setState(() => target = value),
                onReview: intent == null ? null : () => _confirm(intent),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(PositionModeIntent intent) async {
    final controller = ref.read(futuresPositionModeProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(l10n.positionModeConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.positionModeConfirmHint),
              const SizedBox(height: 12),
              SelectableText(intent.context.address),
              Text(l10n.positionModeAllSymbols),
              ValueRow(
                l10n.positionModeCurrentSetting,
                positionModeLabel(l10n, intent.context.current),
              ),
              ValueRow(l10n.positionModeTarget, positionModeLabel(l10n, intent.target)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('position-mode-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.positionModeSignChange),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) await controller.change(intent);
  }
}
