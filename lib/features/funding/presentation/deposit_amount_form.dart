import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/deposit_wallet_provider.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_messages.dart';
import 'deposit_gas_panel.dart';
import 'deposit_submission_panel.dart';

class DepositAmountForm extends ConsumerStatefulWidget {
  const DepositAmountForm({super.key, required this.query});
  final DepositWalletQuery query;
  @override
  ConsumerState<DepositAmountForm> createState() => _DepositAmountFormState();
}

class _DepositAmountFormState extends ConsumerState<DepositAmountForm>
    with AutomaticKeepAliveClientMixin {
  final amount = TextEditingController(), minimum = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    amount.dispose();
    minimum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context), asset = widget.query.asset;
    final text = minimum.text.trim();
    final verified = text.length <= 160 && RegExp(r'^(0|[1-9]\d*)(?:\.\d+)?$').hasMatch(text)
        ? Decimal.tryParse(text)
        : null;
    final query = DepositWalletQuery(
      market: widget.query.market,
      asset: asset,
      verifiedMinimumDeposit: verified,
    );
    final state = ref.watch(depositWalletProvider(widget.query));
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (before, after) {
        if (before != after) {
          setState(() {
            amount.clear();
            minimum.clear();
          });
        }
      },
    );
    final check = checkDepositAmount(
      input: amount.text,
      query: query,
      snapshot: state.account,
      stale: state.stale,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asset.minimumDeposit == null) ...[
          Text(l10n.depositVerifiedMinimumScope),
          TextField(
            key: const Key('deposit-verified-minimum'),
            controller: minimum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.depositVerifiedMinimum),
            onChanged: (_) => setState(() {}),
          ),
        ],
        TextField(
          key: const Key('deposit-amount'),
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.depositAmount),
          onChanged: (_) => setState(() {}),
        ),
        OutlinedButton(
          key: const Key('deposit-wallet-max'),
          onPressed: asset.isNative || state.account == null || state.stale || state.busy
              ? null
              : () => setState(() => amount.text = state.account!.assetBalance.toString()),
          child: Text(l10n.depositWalletMax),
        ),
        Text(asset.isNative ? l10n.depositNativeMaxUnavailable : l10n.depositWalletMaxScope),
        if (check.errorKey case final key?)
          Text(depositMessage(context, key), style: const TextStyle(color: AppColors.warning)),
        if (check.units case final units?) ...[
          Text(l10n.depositSmallestUnits),
          SelectableText(units.toString(), key: const Key('deposit-smallest-units')),
          Text(
            check.allowanceSufficient == null
                ? l10n.depositNativeNoApproval
                : check.allowanceSufficient!
                ? l10n.depositAllowanceEnough
                : l10n.depositAllowanceNeeded,
          ),
        ],
        DepositGasPanel(
          query: query,
          amount: amount.text,
          canEstimate: check.units != null && !state.busy,
        ),
        DepositSubmissionPanel(
          query: query,
          amount: amount.text,
          canPrepare: check.units != null && !state.busy,
        ),
      ],
    );
  }
}
