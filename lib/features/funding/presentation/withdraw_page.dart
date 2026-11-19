import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/rebalance_provider.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/funding_catalog_provider.dart';
import '../application/funding_icon_provider.dart';
import '../application/funding_fee_provider.dart';
import '../application/funding_flow_provider.dart';
import '../application/withdraw_info_provider.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import '../domain/funding_fee.dart';
import '../domain/transfer_history.dart';
import '../domain/withdrawal_amount.dart';
import '../domain/withdrawal_receiver.dart';
import 'funding_components.dart';
import 'funding_dropdown.dart';
import 'funding_screen.dart';
import 'funding_selection.dart';
import 'funding_wallet_screens.dart';
import 'rebalance_sheet.dart';
import 'transfer_history_screen.dart';

const _withdrawCatalog = FundingCatalogQuery(TransferMarket.perp, FundingOperation.withdraw);

/// The withdrawal repository only submits automatic routes on these networks.
bool _withdrawRoute(FundingAsset a) =>
    a.routeType == 'autoWithdraw' && fundingEvmChainIds.contains(a.chainId);

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key, required this.selection, required this.onOperation});
  final FundingSelection selection;
  final ValueChanged<FundingOperation> onOperation;
  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  FundingSelection get selection => widget.selection;
  FundingActionError? actionError;
  void _selectionChanged() => setState(() {});
  @override
  void initState() {
    super.initState();
    selection.addListener(_selectionChanged);
  }

  @override
  void dispose() {
    selection.removeListener(_selectionChanged);
    super.dispose();
  }

  void _edited() => setState(() => actionError = null);

  /// An in-app signature is running from this form.
  bool submitting = false;

  Future<void> _withdraw(DepositWalletQuery query, Decimal fee, String? receiver) async {
    _edited();
    final amount = selection.amount.text.trim();
    // Privy embedded wallets sign in the app; external wallets confirm first.
    final FundingActionError? error;
    if (fundingSignsInApp(ref)) {
      setState(() => submitting = true);
      try {
        error = await submitWithdrawalInApp(
          context,
          ref,
          query: query,
          amount: amount,
          shownFee: fee,
          receiver: receiver,
        );
      } finally {
        if (mounted) setState(() => submitting = false);
      }
    } else {
      error = await Navigator.of(context).push<FundingActionError>(
        MaterialPageRoute(
          builder: (_) => WithdrawConfirmScreen(
            query: query,
            amount: amount,
            shownFee: fee,
            receiver: receiver,
          ),
        ),
      );
    }
    if (!mounted || error == null) return;
    setState(() => actionError = error);
    if (error.key == 'withdrawalFeeChanged') {
      unawaited(ref.read(fundingFeeProvider(_feeQuery(query.asset)).notifier).refresh());
    }
  }

  /// Private reads repeat only for snapshots already shown or a device grant.
  Future<void> _refresh(FundingAsset? asset) async {
    final silent = ref.read(fundingSilentReadsProvider);
    await Future.wait([
      ref.read(fundingIconRefreshProvider)(),
      ref.read(fundingCatalogProvider(_withdrawCatalog).notifier).refresh(),
      if (asset != null) ref.read(fundingFeeProvider(_feeQuery(asset)).notifier).refresh(),
      if (silent || ref.read(withdrawInfoProvider).account != null)
        ref.read(withdrawInfoProvider.notifier).refresh(),
      if (silent || ref.read(rebalanceProvider).context != null)
        ref.read(rebalanceProvider.notifier).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final catalog = ref.watch(fundingCatalogProvider(_withdrawCatalog));
    ref.watch(withdrawAutoLoadProvider);
    final choice = FundingChoice.of(
      catalog.catalog?.assets.where(_withdrawRoute) ?? const [],
      selection,
      defaultChain: fundingDefaultChain(ref),
    );
    final asset = choice.asset;
    final info = ref.watch(withdrawInfoProvider);
    // Aster's -5050 confirms the account has never deposited, so nothing is withdrawable.
    final depositRequired = info.account == null && info.failure?.requiresDeposit == true;
    final withdrawable = asset == null
        ? null
        : depositRequired
        ? Decimal.zero
        : info.account?.assets[asset.asset]?.chains[asset.chainId]?.maximum(TransferMarket.perp);
    final fee = asset == null ? null : ref.watch(fundingFeeProvider(_feeQuery(asset))).quote;
    final amountKey = asset == null
        ? null
        : withdrawAmountError(
            selection.amount.text.trim(),
            asset,
            withdrawable,
            fee: fee?.assetFee,
          );
    final receiverKey = _receiverKey();
    final error = switch ((actionError, amountKey ?? receiverKey)) {
      _ when depositRequired => l.fundingWithdrawDepositRequired,
      (_, 'fundingBalanceInsufficient') => l.fundingBalanceInsufficient(asset!.asset),
      (_, 'fundingWithdrawalFeeInsufficient') => l.fundingWithdrawalFeeInsufficient(asset!.asset),
      (final FundingActionError e, _) => apiErrorText(context, e.key, e.details),
      (_, final String key) => apiErrorText(context, key, null),
      _ when info.account == null && info.failure != null => apiErrorText(
        context,
        info.failure!.key,
        info.failure!.details,
      ),
      _ when catalog.catalog == null && catalog.failureKey != null => apiErrorText(
        context,
        catalog.failureKey!,
        catalog.errorDetails,
      ),
      _ => null,
    };
    return AccountsPage(
      title: l.fundingAccountTitle,
      showBack: false,
      actions: fundingHeaderActions(context),
      onRefresh: () => _refresh(asset),
      footer: _footer(l, asset, withdrawable, amountKey ?? receiverKey),
      children: [
        FundingTabs(operation: FundingOperation.withdraw, onChanged: widget.onOperation),
        const SizedBox(height: 12),
        FundingField(
          label: l.fundingWithdrawFrom,
          value: fundingAccountText(l, ref.watch(activeAccountEntryProvider)),
        ),
        const SizedBox(height: 12),
        _network(l, choice),
        if (_entersReceiver) ...[
          const SizedBox(height: 12),
          FundingAddressField(
            label: l.withdrawalReceiver,
            hint: l.fundingReceiverHint,
            controller: selection.receiver,
            error: receiverKey != null,
            onChanged: (_) => _edited(),
          ),
        ],
        const SizedBox(height: 12),
        _amount(choice, amountKey != null),
        if (error != null) ...[const SizedBox(height: 12), FundingError(error)],
        const SizedBox(height: 12),
        FundingGuidance(
          l.fundingWithdrawChainHint,
          style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted),
        ),
        const SizedBox(height: 4),
        FundingBalanceRow(
          label: l.fundingWithdrawable,
          value: asset == null || withdrawable == null
              ? null
              : fundingBalanceText(withdrawable.toString(), asset.asset),
          loading: info.busy,
          onMax:
              asset == null || withdrawable == null || fee == null || withdrawable <= fee.assetFee
              ? null
              : () {
                  selection.amount.text = (withdrawable - fee.assetFee)
                      .floor(scale: asset.decimals)
                      .toString();
                  _edited();
                },
        ),
        const SizedBox(height: 4),
        if (asset != null) _FeeRow(query: _feeQuery(asset)),
      ],
    );
  }

  bool get _entersReceiver =>
      entersWithdrawalReceiver(ref.watch(authProvider.select((s) => s.identity)));

  /// An entered receiver, or null when the wallet withdraws to itself.
  String? get _receiver => _entersReceiver ? selection.receiver.text.trim() : null;

  /// Empty input only disables the button; a malformed address is an error.
  String? _receiverKey() {
    final value = _receiver;
    return value == null || value.isEmpty || validWithdrawalReceiver(value)
        ? null
        : 'withdrawalReceiverInvalid';
  }

  Widget _network(AppLocalizations l, FundingChoice choice) => FundingDropdown<int>(
    options: [
      for (final id in choice.chains)
        FundingOption(id, fundingNetworkName(l, id), FundingNetworkIcon(id)),
    ],
    selected: choice.chainId,
    onSelected: (id) {
      selection.select(chainId: id, shownChain: choice.chainId);
      _edited();
    },
    builder: (context, open, toggle) => FundingField(
      key: const Key('funding-network'),
      label: l.fundingNetworkLabel,
      value: choice.chainId == null
          ? l.fundingSelectNetwork
          : fundingNetworkName(l, choice.chainId!),
      icon: choice.chainId == null ? null : FundingNetworkIcon(choice.chainId!),
      open: open,
      onTap: toggle,
    ),
  );

  Widget _amount(FundingChoice choice, bool error) {
    final asset = choice.asset;
    return FundingDropdown<String>(
      options: [
        for (final a in choice.assets) FundingOption(a.asset, a.asset, FundingAssetIcon(a.asset)),
      ],
      selected: asset?.asset,
      onSelected: (value) {
        selection.select(asset: value, shownAsset: asset?.asset);
        _edited();
      },
      builder: (context, open, toggle) => FundingAmountField(
        controller: selection.amount,
        decimals: asset?.decimals ?? 0,
        asset: asset?.asset ?? '—',
        enabled: asset != null,
        error: error,
        onChanged: (_) => _edited(),
        assetSelector: FundingAssetSelector(asset: asset?.asset ?? '—', open: open, onTap: toggle),
      ),
    );
  }

  List<Widget> _footer(
    AppLocalizations l,
    FundingAsset? asset,
    Decimal? withdrawable,
    String? inputKey,
  ) {
    final identity = ref.watch(authProvider.select((s) => s.identity));
    final entry = ref.watch(activeAccountEntryProvider);
    final child = entry != null && entry.roleKnown && !entry.main;
    final rebalance = ref.watch(rebalanceProvider).context;
    final fee = asset == null ? null : ref.watch(fundingFeeProvider(_feeQuery(asset))).quote;
    final receiver = _receiver;
    // An unknown withdrawable amount cannot be validated, so it never submits.
    final ready =
        asset != null &&
        fee != null &&
        withdrawable != null &&
        selection.amount.text.trim().isNotEmpty &&
        receiver?.isEmpty != true &&
        inputKey == null &&
        !ref.watch(authProvider).busy;
    final history = AccountAction(
      key: const Key('funding-view-history'),
      label: l.fundingViewHistory,
      primary: false,
      outlined: true,
      onPressed: () => openTransferHistory(context),
    );
    if (!child && rebalance != null && rebalance.needed) {
      return [
        RebalanceAlert(usdt: fundingAmountText(rebalance.usdt!.toString(), 'USDT')),
        const SizedBox(height: 8),
        AccountAction(
          fadeDisabled: true,
          key: const Key('funding-rebalance'),
          label: l.fundingRebalance,
          onPressed: () => showRebalanceSheet(context),
        ),
        const SizedBox(height: 8),
        history,
      ];
    }
    final connect = walletConnectionAction(context, ref, identity);
    return [
      AccountAction(
        fadeDisabled: true,
        key: const Key('funding-withdraw-submit'),
        label: identity?.needsWalletConnection == true
            ? l.reconnectExternalWallet
            : child
            ? l.accountsWithdrawMainOnly
            : l.fundingWithdraw,
        busy: submitting,
        onPressed:
            connect ??
            (child || !ready
                ? null
                : () => _withdraw(
                    DepositWalletQuery(market: TransferMarket.perp, asset: asset),
                    fee.assetFee,
                    receiver,
                  )),
      ),
      const SizedBox(height: 12),
      history,
    ];
  }
}

FundingFeeQuery _feeQuery(FundingAsset asset) =>
    FundingFeeQuery(market: TransferMarket.perp, chainId: asset.chainId, asset: asset.asset);

class _FeeRow extends ConsumerWidget {
  const _FeeRow({required this.query});
  final FundingFeeQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), state = ref.watch(fundingFeeProvider(query));
    final quote = state.quote;
    return Row(
      children: [
        Expanded(child: Text(l.fundingTransactionFee, style: PortfolioTypography.caption)),
        const SizedBox(width: 8),
        if (quote == null && state.loading)
          const FundingSkeleton(width: 120)
        else
          // Tight, so the right-aligned value ends at the row edge.
          Expanded(
            flex: 2,
            child: Text(
              quote == null
                  ? '—'
                  : l.fundingFeeWithUsd(
                      // An estimate, so the shared adaptive precision applies.
                      TokenAmountFormatter.format(
                        DecimalValue(quote.assetFee.toString()),
                        symbol: query.asset,
                      ),
                      TokenAmountFormatter.formatDecimal(DecimalValue(quote.usdFee.toString())),
                    ),
              key: const Key('funding-fee'),
              textAlign: TextAlign.right,
              style: FundingTypography.value,
            ),
          ),
      ],
    );
  }
}
