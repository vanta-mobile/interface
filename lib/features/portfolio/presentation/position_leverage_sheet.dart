import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart' show StatusColors;
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/application/public_leverage_provider.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../application/mode_settings_load_provider.dart';
import '../application/position_leverage_provider.dart';
import '../application/symbol_settings_activity.dart';
import 'mode_access_action.dart';
import 'mode_settings_sheet.dart';
import 'main_order_amount_slider.dart';

Future<void> openLeverageSettings(BuildContext context, String symbol) =>
    showModeSettingsSheet<void>(context, PositionLeverageSheet(symbol: symbol));

/// Leverage for one contract. Confirm signs the change; the sheet closes
/// only after a signed query verifies the selected leverage.
class PositionLeverageSheet extends ConsumerStatefulWidget {
  const PositionLeverageSheet({super.key, required this.symbol});
  final String symbol;
  @override
  ConsumerState<PositionLeverageSheet> createState() => _PositionLeverageSheetState();
}

class _PositionLeverageSheetState extends ConsumerState<PositionLeverageSheet> {
  int? target;
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(
      symbolModeSettingsLoadProvider((setting: SymbolSetting.leverage, symbol: widget.symbol)),
    );
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (a, b) {
      if (a != b) setState(() => target = null);
    });
    final l = AppLocalizations.of(context), state = ref.watch(positionLeverageProvider);
    final controller = ref.read(positionLeverageProvider.notifier);
    final settings = state.context?.symbol == widget.symbol ? state.context : null;
    // Before a signed read, the public brackets preview the market's range.
    final public = ref.watch(publicLeverageProvider.select((s) => s.value?[widget.symbol]));
    final maximum =
        settings?.maximum ?? (public == null ? null : math.min(125, public.maximumLeverage));
    final current = settings?.current ?? public?.defaultLeverage();
    final value = (target ?? current)?.clamp(1, maximum ?? 1);
    final busy = state.busy || submitting;
    final editable = settings != null && maximum != null && maximum > 1 && !busy;
    final failure = state.failure ?? state.result?.failure;
    final ready = ref.watch(modeAccessProvider) == ModeAccess.ready;
    // Until the first read lands, account values show as skeletons.
    final loading = ready && settings == null && failure == null;
    final remaining = settings == null || value == null ? null : settings.remainingNotional(value);
    void select(int next) => setState(() => target = next.clamp(1, maximum!));
    return ModeSheetBody(
      key: const Key('leverage-sheet'),
      title: l.leverageSheetTitle(widget.symbol),
      onRefresh: ready ? () => controller.load(widget.symbol) : null,
      children: [
        Text(l.leverage, style: TradeTypography.option),
        const SizedBox(height: 8),
        _LeverageStepper(
          value: value,
          loading: loading,
          onDecrease: editable && value! > 1 ? () => select(value - 1) : null,
          onIncrease: editable && value! < maximum ? () => select(value + 1) : null,
        ),
        const SizedBox(height: 8),
        if (maximum != null && maximum > 1) ...[
          const SizedBox(height: 8),
          // Same control as the order amount slider: the five stops are
          // drawn for orientation only; every whole leverage is reachable.
          MainOrderAmountSlider(
            sliderKey: const Key('leverage-slider'),
            continuous: true,
            position: ((value ?? 1) - 1) / (maximum - 1),
            semanticLabel: (p) => '${_at(p, maximum)}x',
            onCommit: editable ? (p) => select(_at(p, maximum)) : null,
          ),
          _TickLabels(maximum: maximum),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _NotionalCard(remaining: remaining, loading: loading),
        const SizedBox(height: 8),
        Text(l.leverageSheetNote, style: TradeTypography.body.copyWith(color: TradeColors.muted)),
        if (failure != null) ModeError(accountErrorText(context, failure)),
        const SizedBox(height: 48),
        ModeAccessAction(
          ready: ModeAction(
            key: const Key('leverage-confirm'),
            label: l.modeConfirm,
            large: true,
            busy: busy,
            onPressed: loading || value == null ? null : () => _confirm(value),
          ),
        ),
      ],
    );
  }

  static int _at(double position, int maximum) => (1 + position * (maximum - 1)).round();

  Future<void> _confirm(int leverage) async {
    final identity = ref.read(authProvider).identity;
    final controller = ref.read(positionLeverageProvider.notifier);
    setState(() => submitting = true);
    try {
      var state = ref.read(positionLeverageProvider);
      // Sign only against a fresh read of this contract.
      if (state.context?.symbol != widget.symbol || state.stale) {
        await controller.load(widget.symbol);
      }
      if (!mounted || identity != ref.read(authProvider).identity) return;
      state = ref.read(positionLeverageProvider);
      final settings = state.context;
      if (settings == null || settings.symbol != widget.symbol || state.stale) return;
      if (settings.current == leverage) {
        Navigator.pop(context);
        return;
      }
      final intent = controller.prepare(widget.symbol, '$leverage');
      if (intent == null) return;
      await controller.change(intent);
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          identity == ref.read(authProvider).identity &&
          ref.read(positionLeverageProvider).result?.observed == leverage) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}

class _LeverageStepper extends StatelessWidget {
  const _LeverageStepper({
    required this.value,
    required this.loading,
    this.onDecrease,
    this.onIncrease,
  });
  final int? value;
  final bool loading;
  final VoidCallback? onDecrease, onIncrease;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget button(String icon, String tooltip, VoidCallback? onPressed, Key key) => IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: TradeIcon(
        icon,
        size: 16,
        color: onPressed == null ? TradeColors.muted : TradeColors.text,
      ),
    );
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          button('minus', l.leverageDecrease, onDecrease, const Key('leverage-decrease')),
          Expanded(
            child: loading
                ? const Center(
                    child: SkeletonBox(
                      key: Key('leverage-value-pending'),
                      width: 32,
                      height: 20,
                      color: StatusColors.skeletonOnCard,
                    ),
                  )
                : Text(
                    value == null ? '—' : '$value',
                    key: const Key('leverage-value'),
                    textAlign: TextAlign.center,
                    style: TradeTypography.symbol,
                  ),
          ),
          button('plus', l.leverageIncrease, onIncrease, const Key('leverage-increase')),
        ],
      ),
    );
  }
}

/// 1x, the three quarter marks and the maximum, under the slider's stops.
class _TickLabels extends StatelessWidget {
  const _TickLabels({required this.maximum});
  final int maximum;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final travel = box.maxWidth - 12;
      final style = TradeTypography.body.copyWith(color: TradeColors.muted);
      return SizedBox(
        height: 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, child: Text('1x', style: style)),
            for (var i = 1; i <= 3; i++)
              Positioned(
                left: 6 + travel * i / 4,
                child: FractionalTranslation(
                  translation: const Offset(-.5, 0),
                  child: Text('${(1 + (maximum - 1) * i / 4).round()}x', style: style),
                ),
              ),
            Positioned(right: 0, child: Text('${maximum}x', style: style)),
          ],
        ),
      );
    },
  );
}

class _NotionalCard extends StatelessWidget {
  const _NotionalCard({required this.remaining, required this.loading});
  final Decimal? remaining;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('leverage-notional'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(
            l.leverageRemainingNotional,
            textAlign: TextAlign.center,
            style: TradeTypography.small.copyWith(color: TradeColors.text),
          ),
          const SizedBox(height: 12),
          if (loading)
            const SkeletonBox(width: 120, height: 20, color: StatusColors.skeletonOnCard)
          else
            Text(
              remaining == null ? '—' : '${marketNumber(remaining!)} USDT',
              textAlign: TextAlign.center,
              style: TradeTypography.body.copyWith(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            l.leverageRemainingNotionalHint,
            textAlign: TextAlign.center,
            style: TradeTypography.small,
          ),
        ],
      ),
    );
  }
}
