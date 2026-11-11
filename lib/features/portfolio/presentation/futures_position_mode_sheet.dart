import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_position_mode_provider.dart';
import '../application/mode_settings_load_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/futures_position_mode.dart';
import 'mode_read_action.dart';
import 'mode_settings_sheet.dart';

class FuturesPositionModeSheet extends ConsumerStatefulWidget {
  const FuturesPositionModeSheet({super.key});
  @override
  ConsumerState<FuturesPositionModeSheet> createState() => _FuturesPositionModeSheetState();
}

class _FuturesPositionModeSheetState extends ConsumerState<FuturesPositionModeSheet> {
  int selectionRevision = 0;
  FuturesPositionMode? pending;
  bool selecting = false, blockedSelection = false;
  @override
  Widget build(BuildContext context) {
    ref.watch(modeSettingsLoadProvider(AccountModeSetting.position));
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (_, next) {
        setState(() {
          selectionRevision++;
          selecting = false;
          pending = null;
          blockedSelection = false;
        });
      },
    );
    final state = ref.watch(futuresPositionModeProvider), l = AppLocalizations.of(context);
    final controller = ref.read(futuresPositionModeProvider.notifier);
    final current = state.result?.observed ?? state.context?.current;
    final blocked = ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.positionMode);
    final failure = state.failure ?? state.result?.failure;
    return ModeSheetBody(
      key: const Key('position-mode-sheet'),
      title: l.modePositionTitle,
      onRefresh: state.needsRecheck ? controller.recheck : controller.load,
      children: [
        for (final mode in FuturesPositionMode.values)
          ModeOptionCard(
            key: ValueKey('position-mode-${mode.name}'),
            title: mode == FuturesPositionMode.oneWay ? l.positionModeOneWay : l.positionModeHedge,
            description: mode == FuturesPositionMode.oneWay
                ? l.modeOneWayDescription
                : l.modeHedgeDescription,
            selected: current == mode,
            busy: (state.busy || selecting) && pending == mode,
            onTap: state.busy || selecting || blocked || state.needsRecheck || current == mode
                ? null
                : () => _select(mode),
          ),
        if (blockedSelection) ModeError(l.modePositionBlocked),
        if (failure != null) ModeError(accountErrorText(context, failure)),
        if (state.needsRecheck) ModeError(l.positionModeOutcomeUnknown),
        if (state.result?.observed != null &&
            state.intent != null &&
            state.result!.observed != state.intent!.target)
          ModeError(
            l.positionModeObservedDifferent(
              state.result!.observed == FuturesPositionMode.oneWay
                  ? l.positionModeOneWay
                  : l.positionModeHedge,
              state.intent!.target == FuturesPositionMode.oneWay
                  ? l.positionModeOneWay
                  : l.positionModeHedge,
            ),
          ),
        if (state.context == null || state.stale || state.needsRecheck || state.busy) ...[
          const SizedBox(height: 8),
          ModeReadAction(
            key: const Key('position-mode-sheet-read'),
            onRead: state.needsRecheck ? controller.recheck : controller.load,
            busy: state.busy,
            blocked: blocked,
            recheck: state.needsRecheck,
          ),
        ],
      ],
    );
  }

  Future<void> _select(FuturesPositionMode target) async {
    final identity = ref.read(authProvider).identity;
    final revision = ++selectionRevision;
    setState(() {
      pending = target;
      selecting = true;
      blockedSelection = false;
    });
    final controller = ref.read(futuresPositionModeProvider.notifier);
    try {
      var state = ref.read(futuresPositionModeProvider);
      if (state.context == null || state.stale) await controller.load();
      if (!mounted || identity != ref.read(authProvider).identity) return;
      state = ref.read(futuresPositionModeProvider);
      if (state.context?.blocked == true) {
        setState(() => blockedSelection = true);
        return;
      }
      final intent = controller.prepare(target);
      if (intent == null) return;
      await controller.change(intent);
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          identity == ref.read(authProvider).identity &&
          ref.read(futuresPositionModeProvider).result?.observed == target) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted && revision == selectionRevision) {
        setState(() {
          selecting = false;
          pending = null;
        });
      }
    }
  }
}
