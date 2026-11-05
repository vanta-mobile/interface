import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_leverage_provider.dart';
import '../domain/position_leverage.dart';
import 'position_leverage_status.dart';
import '../application/symbol_settings_activity.dart';
import 'symbol_settings_notice.dart';

void openLeverageSettings(BuildContext context, String symbol) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => PositionLeverageScreen(symbol: symbol)));

class PositionLeverageScreen extends ConsumerStatefulWidget {
  const PositionLeverageScreen({super.key, required this.symbol});
  final String symbol;
  @override
  ConsumerState<PositionLeverageScreen> createState() => _PositionLeverageScreenState();
}

class _PositionLeverageScreenState extends ConsumerState<PositionLeverageScreen> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (
      before,
      after,
    ) {
      if (before != after) input.clear();
    });
    final symbol = widget.symbol;
    final l10n = AppLocalizations.of(context), state = ref.watch(positionLeverageProvider);
    final auth = ref.watch(authProvider), identity = auth.identity;
    final settings = state.context?.symbol == symbol ? state.context : null;
    final otherBlocked = ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.leverage);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leverageSettings)),
      body: SafeArea(
        child: ListView(
          key: const Key('leverage-page'),
          padding: const EdgeInsets.all(16),
          children: [
            const OrderRecoveryNotice(),
            SelectableText(symbol, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l10n.leverageSettingsScope),
            const SizedBox(height: 12),
            if (identity?.walletAddress case final address?) SelectableText(address),
            const SymbolSettingsNotice(setting: SymbolSetting.leverage),
            FilledButton.icon(
              key: const Key('leverage-read'),
              onPressed: state.busy || state.needsRecheck || otherBlocked || auth.busy
                  ? null
                  : identity?.signingAvailable == true && identity?.walletAddress != null
                  ? () => ref.read(positionLeverageProvider.notifier).load(symbol)
                  : () => showAccountSheet(context),
              icon: const Icon(Icons.refresh),
              label: Text(
                identity == null
                    ? l10n.accountSignInToRead
                    : identity.walletAddress == null
                    ? l10n.createWallet
                    : !identity.signingAvailable
                    ? l10n.reconnectExternalWallet
                    : l10n.leverageReadSettings,
              ),
            ),
            Text(l10n.leverageSettingsReadHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const PositionLeverageStatus(),
            if (settings != null) ...[
              const SizedBox(height: 16),
              ValueRow(l10n.leverageCurrentSetting, '${settings.current}×'),
              Text(
                '${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(settings.receivedAt.toUtc())} UTC',
              ),
              if (state.stale)
                Text(l10n.leverageContextExpired, style: const TextStyle(color: AppColors.warning)),
              _LeverageForm(symbol: symbol, input: input),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeverageForm extends ConsumerStatefulWidget {
  const _LeverageForm({required this.symbol, required this.input});
  final String symbol;
  final TextEditingController input;
  @override
  ConsumerState<_LeverageForm> createState() => _LeverageFormState();
}

class _LeverageFormState extends ConsumerState<_LeverageForm> {
  TextEditingController get input => widget.input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), state = ref.watch(positionLeverageProvider);
    final settings = state.context!;
    ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(positionLeverageProvider.notifier);
    final intent = controller.prepare(widget.symbol, input.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TextField(
          key: const Key('leverage-target'),
          controller: input,
          readOnly: state.busy,
          keyboardType: const TextInputType.numberWithOptions(),
          decoration: InputDecoration(
            labelText: l10n.leverageTarget,
            errorText: input.text.isNotEmpty && settings.target(input.text) == null
                ? l10n.leverageInvalidTarget
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.leverageInputHint(settings.maximum),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('leverage-review'),
          onPressed: intent == null ? null : () => _confirm(intent),
          child: Text(l10n.leverageReviewChange),
        ),
      ],
    );
  }

  Future<void> _confirm(LeverageIntent intent) async {
    final controller = ref.read(positionLeverageProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(l10n.leverageConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.leverageConfirmHint),
              const SizedBox(height: 12),
              SelectableText(intent.context.address),
              SelectableText(intent.context.symbol),
              Text(l10n.leverageRequestedChange(intent.context.current, intent.target)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('leverage-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.leverageSignChange),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) await controller.change(intent);
  }
}
