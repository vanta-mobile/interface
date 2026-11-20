import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/futures_asset_mode_provider.dart';
import '../application/mode_settings_load_provider.dart';
import '../domain/futures_asset_mode.dart';
import 'mode_access_action.dart';
import 'mode_settings_sheet.dart';
import 'multi_asset_activation_sheet.dart';

Future<void> openAssetModeSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const FuturesAssetModeSheet());

String assetModeLabel(AppLocalizations l10n, FuturesAssetMode mode) =>
    mode == FuturesAssetMode.single ? l10n.assetModeSingle : l10n.assetModeMulti;

class FuturesAssetModeSheet extends ConsumerStatefulWidget {
  const FuturesAssetModeSheet({super.key});
  @override
  ConsumerState<FuturesAssetModeSheet> createState() => _FuturesAssetModeSheetState();
}

class _FuturesAssetModeSheetState extends ConsumerState<FuturesAssetModeSheet> {
  int selectionRevision = 0;
  FuturesAssetMode? pending;
  bool selecting = false, negativeBalance = false;
  @override
  Widget build(BuildContext context) {
    ref.watch(modeSettingsLoadProvider(AccountModeSetting.asset));
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
          negativeBalance = false;
        });
      },
    );
    final state = ref.watch(futuresAssetModeProvider), l = AppLocalizations.of(context);
    final current = state.result?.observed ?? state.context?.current;
    final busy = state.busy || selecting;
    final failure = state.failure ?? state.result?.failure;
    final ready = ref.watch(modeAccessProvider) == ModeAccess.ready;
    // Until the first read lands, the current mode shows as a skeleton.
    final loading = ready && state.context == null && failure == null;
    Widget option(FuturesAssetMode mode, String key, String title, String description) =>
        ModeOptionCard(
          key: Key(key),
          title: title,
          description: description,
          selected: !loading && current == mode,
          loading: loading && pending != mode,
          busy: busy && pending == mode,
          onTap: !ready || busy || current == mode ? null : () => _select(mode),
        );
    return ModeSheetBody(
      key: const Key('asset-mode-sheet'),
      title: l.modeAssetTitle,
      onRefresh: ready ? ref.read(futuresAssetModeProvider.notifier).load : null,
      children: [
        option(
          FuturesAssetMode.single,
          'asset-mode-single',
          l.modeSingleTitle,
          l.modeSingleDescription,
        ),
        option(
          FuturesAssetMode.multi,
          'asset-mode-multi',
          l.modeMultiTitle,
          l.modeMultiDescription,
        ),
        const _MultiAssetAbout(),
        if (negativeBalance)
          ModeError(
            state.context?.usdtWalletBalance == null ? l.rebalanceUnknownUsdt : l.modeNegativeUsdt,
          ),
        if (failure != null) ModeError(accountErrorText(context, failure)),
        if (state.result?.observed != null &&
            state.intent != null &&
            state.result!.observed != state.intent!.target)
          ModeError(
            l.assetModeObservedDifferent(
              state.result!.observed == FuturesAssetMode.single
                  ? l.modeSingleShort
                  : l.modeMultiShort,
              state.intent!.target == FuturesAssetMode.single
                  ? l.modeSingleShort
                  : l.modeMultiShort,
            ),
          ),
        if (!ready) ...[
          const SizedBox(height: 8),
          const ModeAccessAction(ready: SizedBox.shrink()),
        ],
      ],
    );
  }

  Future<void> _select(FuturesAssetMode target) async {
    final identity = ref.read(authProvider).identity;
    final revision = ++selectionRevision;
    setState(() {
      pending = target;
      selecting = true;
      negativeBalance = false;
    });
    final controller = ref.read(futuresAssetModeProvider.notifier);
    try {
      var state = ref.read(futuresAssetModeProvider);
      if (state.context == null || state.stale) await controller.load();
      if (!mounted || identity != ref.read(authProvider).identity) return;
      state = ref.read(futuresAssetModeProvider);
      if (state.context == null || state.stale || state.busy) return;
      if (target == FuturesAssetMode.multi) {
        setState(() {
          selecting = false;
          pending = null;
        });
        await showModeSettingsSheet<void>(context, const MultiAssetActivationSheet());
      } else if (state.context!.blocks(target)) {
        setState(() => negativeBalance = true);
      } else {
        final intent = controller.prepare(target);
        if (intent == null) return;
        await controller.change(intent);
        if (mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            identity == ref.read(authProvider).identity &&
            ref.read(futuresAssetModeProvider).result?.observed == target) {
          Navigator.pop(context);
        }
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

class _MultiAssetAbout extends StatelessWidget {
  const _MultiAssetAbout();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      key: const Key('multi-asset-about'),
      onTap: () => showModeSettingsSheet<void>(
        context,
        ModeSheetBody(
          title: l.modeMultiTitle,
          children: [
            Text(l.modeMultiDescription, style: TradeTypography.body),
            const SizedBox(height: 12),
            Text(
              l.modeMultiRequirements,
              style: TradeTypography.body.copyWith(color: TradeColors.muted),
            ),
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.modeReadAboutPrefix),
                TextSpan(
                  text: l.modeMultiTitle,
                  style: const TextStyle(color: TradeColors.accent),
                ),
                TextSpan(text: l.modeReadAboutSuffix),
              ],
            ),
            style: TradeTypography.body.copyWith(color: TradeColors.muted),
          ),
        ),
      ),
    );
  }
}
