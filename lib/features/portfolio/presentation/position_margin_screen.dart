import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_margin_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/position_margin_adjustment.dart';
import 'position_margin_form.dart';
import 'position_margin_history.dart';
import 'position_margin_status.dart';
import 'symbol_settings_notice.dart';

void openPositionMargin(BuildContext context, {String? symbol, String? side}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PositionMarginScreen(symbol: symbol, side: side),
      ),
    );

class PositionMarginScreen extends ConsumerStatefulWidget {
  const PositionMarginScreen({super.key, this.symbol, this.side});
  final String? symbol, side;
  @override
  ConsumerState<PositionMarginScreen> createState() => _PositionMarginScreenState();
}

class _PositionMarginScreenState extends ConsumerState<PositionMarginScreen> {
  final amount = TextEditingController();
  MarginDirection direction = MarginDirection.add;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), state = ref.watch(positionMarginProvider);
    final auth = ref.watch(authProvider), identity = auth.identity;
    final controller = ref.read(positionMarginProvider.notifier);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (a, b) {
        if (a != b) {
          setState(() {
            amount.clear();
            direction = MarginDirection.add;
          });
        }
      },
    );
    final c = state.context;
    final target = widget.symbol != null && widget.side != null;
    final settings =
        target && c?.position.symbol == widget.symbol && c?.position.side == widget.side ? c : null;
    final intent = settings == null ? null : controller.prepare(direction, amount.text);
    final blocked = ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.positionMargin);
    return PopScope(
      onPopInvokedWithResult: (popped, _) {
        if (popped) controller.stop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop() ? const CloseButton() : null,
          title: Text(l.marginAdjustTitle),
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('margin-adjust-page'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.marginAdjustScope),
              if (target) ...[
                SelectableText('${widget.symbol} · ${widget.side}'),
                if (identity?.walletAddress case final address?) SelectableText(address),
                const SymbolSettingsNotice(setting: SymbolSetting.positionMargin),
                FilledButton.icon(
                  key: const Key('margin-adjust-read'),
                  onPressed: state.busy || auth.busy || blocked
                      ? null
                      : identity?.signingAvailable == true && identity?.walletAddress != null
                      ? () => controller.load(widget.symbol!, widget.side!)
                      : () => showAccountSheet(context),
                  icon: const Icon(Icons.refresh),
                  label: Text(identity == null ? l.accountSignInToRead : l.marginAdjustRead),
                ),
                Text(l.marginAdjustReadHint, style: Theme.of(context).textTheme.bodySmall),
              ],
              const PositionMarginStatus(),
              if (settings != null)
                PositionMarginForm(
                  settings: settings,
                  direction: direction,
                  amount: amount,
                  stale: state.stale,
                  busy: state.busy,
                  onDirection: (d) => setState(() => direction = d),
                  onInput: () => setState(() {}),
                  onReview: intent == null ? null : () => _review(intent),
                ),
              if (target && Navigator.of(context).canPop())
                TextButton(
                  key: const Key('margin-adjust-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.cancel),
                ),
              const PositionMarginHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _review(PositionMarginIntent intent) async {
    final controller = ref.read(positionMarginProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context), c = intent.context;
        return AlertDialog(
          scrollable: true,
          title: Text(l.marginAdjustReview),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.marginAdjustConfirmHint),
              const SizedBox(height: 12),
              SelectableText(c.account.address),
              SelectableText('${c.position.symbol} · ${c.position.side}'),
              ValueRow(marginDirectionLabel(l, intent.direction), '${intent.amount} ${c.asset}'),
              Text(l.marginAdjustReference),
              SelectableText(intent.reference),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(
              key: const Key('margin-adjust-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.marginAdjustConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final originalInput = amount.text;
    await controller.change(intent);
    if (!mounted) return;
    final state = ref.read(positionMarginProvider);
    final result = state.result;
    if (result?.verified == true &&
        result?.record.terms['clientTranId'] == intent.reference &&
        amount.text == originalInput) {
      setState(amount.clear);
      if (result?.failure == null &&
          result?.account != null &&
          result?.positions != null &&
          Navigator.of(context).canPop()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).marginAdjustVerified)));
        Navigator.of(context).pop();
      }
    } else if (state.failure?.key == 'marginAdjustClosed' && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
