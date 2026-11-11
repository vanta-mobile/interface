import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_margin_mode_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/position_margin_mode.dart';
import 'position_margin_mode_status.dart';
import 'position_margin_mode_form.dart';
import 'symbol_settings_notice.dart';

void openMarginModeSettings(BuildContext context, String symbol) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => PositionMarginModeScreen(symbol: symbol)));

class PositionMarginModeScreen extends ConsumerStatefulWidget {
  const PositionMarginModeScreen({
    super.key,
    required this.symbol,
    this.initialTarget,
    this.readOnOpen = false,
  });
  final String symbol;
  final PositionMarginMode? initialTarget;
  final bool readOnOpen;
  @override
  ConsumerState<PositionMarginModeScreen> createState() => _PositionMarginModeScreenState();
}

class _PositionMarginModeScreenState extends ConsumerState<PositionMarginModeScreen> {
  PositionMarginMode? target;
  @override
  void initState() {
    super.initState();
    target = widget.initialTarget;
    if (widget.readOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(positionMarginModeProvider.notifier).load(widget.symbol);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (
      before,
      after,
    ) {
      if (before != after) setState(() => target = null);
    });
    final l10n = AppLocalizations.of(context), state = ref.watch(positionMarginModeProvider);
    final auth = ref.watch(authProvider), identity = auth.identity;
    final settings = state.context?.symbol == widget.symbol ? state.context : null;
    final otherBlocked = ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.marginMode);
    final controller = ref.read(positionMarginModeProvider.notifier);
    final intent = target == null ? null : controller.prepare(widget.symbol, target!);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.marginModeSettings)),
      body: SafeArea(
        child: ListView(
          key: const Key('margin-mode-page'),
          padding: const EdgeInsets.all(16),
          children: [
            const OrderRecoveryNotice(),
            SelectableText(widget.symbol, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l10n.marginModeSettingsScope),
            const SizedBox(height: 8),
            Text(l10n.marginModeCrossHint, style: Theme.of(context).textTheme.bodySmall),
            Text(l10n.marginModeIsolatedHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (identity?.walletAddress case final address?) SelectableText(address),
            const SymbolSettingsNotice(setting: SymbolSetting.marginMode),
            FilledButton.icon(
              key: const Key('margin-mode-read'),
              onPressed: state.busy || state.needsRecheck || otherBlocked || auth.busy
                  ? null
                  : identity?.signingAvailable == true && identity?.walletAddress != null
                  ? () => controller.load(widget.symbol)
                  : () => showAccountSheet(context),
              icon: const Icon(Icons.refresh),
              label: Text(
                identity == null
                    ? l10n.accountSignInToRead
                    : identity.walletAddress == null
                    ? l10n.createWallet
                    : !identity.signingAvailable
                    ? l10n.reconnectExternalWallet
                    : l10n.marginModeReadSettings,
              ),
            ),
            Text(l10n.marginModeReadHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const PositionMarginModeStatus(),
            if (settings != null)
              PositionMarginModeForm(
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

  Future<void> _confirm(MarginModeIntent intent) async {
    final controller = ref.read(positionMarginModeProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(l10n.marginModeConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.marginModeConfirmHint),
              const SizedBox(height: 12),
              SelectableText(intent.context.address),
              SelectableText(intent.context.symbol),
              ValueRow(
                l10n.marginModeCurrentSetting,
                marginModeLabel(l10n, intent.context.current),
              ),
              ValueRow(l10n.marginModeTarget, marginModeLabel(l10n, intent.target)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('margin-mode-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.marginModeSignChange),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) await controller.change(intent);
  }
}
