import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_position_mode_provider.dart';
import '../application/mode_settings_load_provider.dart';
import '../domain/futures_position_mode.dart';
import 'mode_access_action.dart';
import 'mode_settings_sheet.dart';

Future<void> openPositionModeSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const FuturesPositionModeSheet());

String positionModeLabel(AppLocalizations l10n, FuturesPositionMode mode) =>
    mode == FuturesPositionMode.oneWay ? l10n.positionModeOneWay : l10n.positionModeHedge;

class FuturesPositionModeSheet extends ConsumerStatefulWidget {
  const FuturesPositionModeSheet({super.key});
  @override
  ConsumerState<FuturesPositionModeSheet> createState() => _FuturesPositionModeSheetState();
}

class _FuturesPositionModeSheetState extends ConsumerState<FuturesPositionModeSheet> {
  int selectionRevision = 0;
  FuturesPositionMode? pending;
  bool selecting = false;
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
        });
      },
    );
    final state = ref.watch(futuresPositionModeProvider), l = AppLocalizations.of(context);
    final controller = ref.read(futuresPositionModeProvider.notifier);
    final current = state.result?.observed ?? state.context?.current;
    final failure = state.failure ?? state.result?.failure;
    final busy = state.busy || selecting;
    final ready = ref.watch(modeAccessProvider) == ModeAccess.ready;
    // Until the first read lands, the current mode shows as a skeleton.
    final loading = ready && state.context == null && failure == null;
    // Positions or orders lock the account to its current mode.
    final locked = state.context?.blocked == true;
    return ModeSheetBody(
      key: const Key('position-mode-sheet'),
      title: l.modePositionTitle,
      onRefresh: ready ? controller.load : null,
      children: [
        for (final mode in FuturesPositionMode.values)
          ModeOptionCard(
            key: ValueKey('position-mode-${mode.name}'),
            title: positionModeLabel(l, mode),
            description: mode == FuturesPositionMode.oneWay
                ? l.modeOneWayDescription
                : l.modeHedgeDescription,
            selected: !loading && current == mode,
            loading: loading && pending != mode,
            busy: busy && pending == mode,
            disabled: locked && mode != current,
            onTap: !ready || busy || current == mode || locked ? null : () => _select(mode),
          ),
        if (locked) ModeError(l.modePositionBlocked),
        if (failure != null) ModeError(accountErrorText(context, failure)),
        if (state.result?.observed != null &&
            state.intent != null &&
            state.result!.observed != state.intent!.target)
          ModeError(
            l.positionModeObservedDifferent(
              positionModeLabel(l, state.result!.observed!),
              positionModeLabel(l, state.intent!.target),
            ),
          ),
        if (!ready) ...[
          const SizedBox(height: 8),
          const ModeAccessAction(ready: SizedBox.shrink()),
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
    });
    final controller = ref.read(futuresPositionModeProvider.notifier);
    try {
      var state = ref.read(futuresPositionModeProvider);
      if (state.context == null || state.stale) await controller.load();
      if (!mounted || identity != ref.read(authProvider).identity) return;
      state = ref.read(futuresPositionModeProvider);
      if (state.context?.blocked == true) return;
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
