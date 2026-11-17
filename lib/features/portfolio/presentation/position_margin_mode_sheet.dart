import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/mode_settings_load_provider.dart';
import '../application/position_margin_mode_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/position_margin_mode.dart';
import 'mode_access_action.dart';
import 'mode_settings_sheet.dart';

Future<void> openMarginModeSettings(
  BuildContext context,
  String symbol, {
  PositionMarginMode? initialTarget,
}) => showModeSettingsSheet<void>(
  context,
  PositionMarginModeSheet(symbol: symbol, initialTarget: initialTarget),
);

String marginModeLabel(AppLocalizations l10n, PositionMarginMode mode) =>
    mode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode;

/// Cross / Isolated for one contract. Confirm signs the change; the sheet
/// closes only after a signed query verifies the selected mode.
class PositionMarginModeSheet extends ConsumerStatefulWidget {
  const PositionMarginModeSheet({super.key, required this.symbol, this.initialTarget});
  final String symbol;
  final PositionMarginMode? initialTarget;
  @override
  ConsumerState<PositionMarginModeSheet> createState() => _PositionMarginModeSheetState();
}

class _PositionMarginModeSheetState extends ConsumerState<PositionMarginModeSheet> {
  late PositionMarginMode? target = widget.initialTarget;
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(
      symbolModeSettingsLoadProvider((setting: SymbolSetting.marginMode, symbol: widget.symbol)),
    );
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (a, b) {
      if (a != b) setState(() => target = widget.initialTarget);
    });
    final l = AppLocalizations.of(context), state = ref.watch(positionMarginModeProvider);
    final controller = ref.read(positionMarginModeProvider.notifier);
    final settings = state.context?.symbol == widget.symbol ? state.context : null;
    final current = state.intent?.context.symbol == widget.symbol
        ? state.result?.observed ?? settings?.current
        : settings?.current;
    final selected = target ?? current;
    final busy = state.busy || submitting;
    final failure = state.failure ?? state.result?.failure;
    final ready = ref.watch(modeAccessProvider) == ModeAccess.ready;
    // Until the first read lands, the current mode shows as a skeleton.
    final loading = ready && settings == null && failure == null;
    // Positions or orders lock the contract to its current mode.
    final locked = settings?.blocked == true;
    Widget option(PositionMarginMode mode, String description) {
      final disabled = locked && mode != settings!.current;
      return ModeOptionCard(
        key: Key('margin-mode-${mode.name}'),
        title: marginModeLabel(l, mode),
        description: description,
        selected: !loading && selected == mode,
        loading: loading,
        disabled: disabled,
        onTap: busy || disabled ? null : () => setState(() => target = mode),
      );
    }

    return ModeSheetBody(
      key: const Key('margin-mode-sheet'),
      title: l.marginModeSheetTitle(widget.symbol),
      onRefresh: ready ? () => controller.load(widget.symbol) : null,
      children: [
        Text(
          l.marginModeSheetScope,
          style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        option(PositionMarginMode.cross, l.marginModeCrossDescription),
        option(PositionMarginMode.isolated, l.marginModeIsolatedDescription),
        if (locked) ModeError(l.marginModePositionsOrOrders),
        if (failure != null) ModeError(accountErrorText(context, failure)),
        const SizedBox(height: 48),
        ModeAccessAction(
          ready: ModeAction(
            key: const Key('margin-mode-confirm'),
            label: l.modeConfirm,
            large: true,
            busy: busy,
            onPressed: loading || selected == null ? null : () => _confirm(selected),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(PositionMarginMode mode) async {
    final identity = ref.read(authProvider).identity;
    final controller = ref.read(positionMarginModeProvider.notifier);
    setState(() => submitting = true);
    try {
      var state = ref.read(positionMarginModeProvider);
      // Sign only against a fresh read of this contract; a late read from
      // another account never submits.
      if (state.context?.symbol != widget.symbol || state.stale) {
        await controller.load(widget.symbol);
      }
      if (!mounted || identity != ref.read(authProvider).identity) return;
      state = ref.read(positionMarginModeProvider);
      final settings = state.context;
      if (settings == null || settings.symbol != widget.symbol || state.stale) return;
      if (settings.current == mode) {
        Navigator.pop(context);
        return;
      }
      final intent = controller.prepare(widget.symbol, mode);
      if (intent == null) return;
      await controller.change(intent);
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          identity == ref.read(authProvider).identity &&
          ref.read(positionMarginModeProvider).result?.observed == mode) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
