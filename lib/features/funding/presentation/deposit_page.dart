import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/deposit_approval_provider.dart';
import '../application/deposit_approval_wait_provider.dart';
import '../application/deposit_gas_provider.dart';
import '../application/deposit_entry_provider.dart';
import '../application/deposit_submission_provider.dart';
import '../application/deposit_wallet_provider.dart';
import '../application/funding_catalog_provider.dart';
import '../application/funding_icon_provider.dart';
import '../application/funding_flow_provider.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';
import 'add_funds_sheet.dart';
import 'deposit_components.dart';
import 'deposit_messages.dart';
import 'funding_components.dart';
import 'funding_dropdown.dart';
import 'funding_screen.dart';
import 'funding_selection.dart';
import 'funding_wallet_screens.dart';

const _depositCatalog = FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit);

/// Unsupported vault routes are not offered; the transaction builder rejects them.
bool _depositRoute(FundingAsset a) =>
    a.routeType == 'normal' && depositVaults.containsKey(a.chainId);

class DepositPage extends ConsumerStatefulWidget {
  const DepositPage({super.key, required this.selection, required this.onOperation});
  final FundingSelection selection;
  final ValueChanged<FundingOperation> onOperation;
  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends ConsumerState<DepositPage> {
  FundingSelection get selection => widget.selection;
  FundingActionError? actionError;
  Timer? gasTimer;
  (DepositWalletQuery, String)? estimated;
  DepositWalletQuery? estimatingQuery;
  int estimateRevision = 0;
  int inputRevision = 0;

  /// An in-app signature is running from this form.
  bool confirming = false;
  final approvalWaitScope = Object();
  void _selectionChanged() => setState(() {});
  @override
  void initState() {
    super.initState();
    selection.addListener(_selectionChanged);
  }

  @override
  void dispose() {
    selection.removeListener(_selectionChanged);
    gasTimer?.cancel();
    estimateRevision++;
    super.dispose();
  }

  void _edited(DepositWalletQuery? query) {
    inputRevision++;
    estimateRevision++;
    gasTimer?.cancel();
    if (estimatingQuery case final previous?) {
      ref.read(depositGasProvider(previous).notifier).stop();
    }
    setState(() {
      actionError = null;
      estimated = null;
    });
    if (query != null) _estimateLater(query);
  }

  /// Public RPC gas estimate, so a Max native amount reports missing fees early.
  void _estimateLater(DepositWalletQuery query) {
    gasTimer?.cancel();
    gasTimer = Timer(const Duration(milliseconds: 400), () => unawaited(_estimateNow(query)));
  }

  Future<void> _estimateNow(DepositWalletQuery query) async {
    gasTimer?.cancel();
    if (!mounted) return;
    final amount = selection.amount.text.trim(), wallet = ref.read(depositWalletProvider(query));
    final check = checkDepositAmount(
      input: amount,
      query: query,
      snapshot: wallet.account,
      stale: wallet.stale,
    );
    if (check.units == null || wallet.busy) return;
    final revision = ++estimateRevision;
    estimatingQuery = query;
    final controller = ref.read(depositGasProvider(query).notifier);
    controller.stop();
    await controller.estimate(amount);
    if (mounted && revision == estimateRevision && selection.amount.text.trim() == amount) {
      setState(() => estimated = (query, amount));
    }
  }

  Future<void> _submit(DepositWalletQuery query) async {
    setState(() => actionError = null);
    ref.read(depositApprovalWaitProvider((approvalWaitScope, query)).notifier).clear();
    final amount = selection.amount.text.trim(), revision = inputRevision;
    final review = await ref.read(depositEntryProvider.notifier).prepare(query, amount);
    if (!mounted) return;
    if (revision != inputRevision || selection.amount.text.trim() != amount) {
      if (review.approval case final approval?) {
        ref.read(depositApprovalProvider.notifier).cancel(approval);
      }
      if (review.deposit case final deposit?) {
        ref.read(depositSubmissionProvider.notifier).cancel(deposit);
      }
      setState(() => actionError = const FundingActionError('depositSubmissionChanged'));
      return;
    }
    if (review.failure case final failure?) {
      setState(() => actionError = FundingActionError(failure.key, failure.details));
      return;
    }
    // Privy embedded wallets sign in the app; external wallets confirm first.
    final inApp = fundingSignsInApp(ref);
    FundingActionError? error;
    setState(() => confirming = inApp);
    try {
      if (review.approval case final approval?) {
        error = inApp
            ? await confirmApprovalInApp(context, ref, approval)
            : await Navigator.of(context).push<FundingActionError>(
                MaterialPageRoute(builder: (_) => ApprovalConfirmScreen(review: approval)),
              );
      } else if (review.deposit case final deposit?) {
        error = inApp
            ? await confirmDepositInApp(context, ref, deposit)
            : await Navigator.of(context).push<FundingActionError>(
                MaterialPageRoute(builder: (_) => DepositConfirmScreen(review: deposit)),
              );
      } else {
        error = const FundingActionError('depositRpcFailed');
      }
    } finally {
      if (mounted) setState(() => confirming = false);
    }
    if (!mounted) return;
    // Returning from a wallet prompt never proves approval; reread allowance.
    if (review.approval != null && error == null) {
      final approval = ref.read(depositApprovalProvider);
      final record = ref
          .read(pendingDepositApprovalsProvider)
          .where((r) => r.key == approval.record?.key && r.hash != null)
          .firstOrNull;
      if (record != null && approval.failure == null) {
        ref
            .read(depositApprovalWaitProvider((approvalWaitScope, query)).notifier)
            .start(approval.record!.withHash(record.hash!));
      }
    }
    if (error != null) setState(() => actionError = error);
    await ref.read(depositWalletProvider(query).notifier).refresh();
  }

  /// Step 1: top up the wallet, then continue on the network and token the
  /// user sent, with a fresh balance read.
  Future<void> _addFunds(
    FundingChoice choice,
    DepositWalletQuery? query, {
    bool gas = false,
  }) async {
    final chain = choice.chainId;
    if (chain == null) return;
    final result = await showAddFundsSheet(
      context,
      assets: [
        for (final a
            in ref.read(fundingCatalogProvider(_depositCatalog)).catalog?.assets ??
                const <FundingAsset>[])
          if (_depositRoute(a)) a,
      ],
      chainId: chain,
      asset: choice.asset?.asset,
      gas: gas,
    );
    if (!mounted || result == null) return;
    if (result.chainId != chain || result.asset != null && result.asset != choice.asset?.asset) {
      selection.select(
        chainId: result.chainId,
        asset: result.asset,
        shownChain: chain,
        shownAsset: choice.asset?.asset,
      );
      _edited(null);
      return;
    }
    if (query != null) await _refresh(query);
  }

  Future<void> _refresh(DepositWalletQuery? query) async {
    await Future.wait([
      ref.read(fundingIconRefreshProvider)(),
      ref.read(fundingCatalogProvider(_depositCatalog).notifier).refresh(),
      if (query != null) ref.read(depositWalletProvider(query).notifier).refresh(),
    ]);
    if (mounted && query != null) await _estimateNow(query);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final catalog = ref.watch(fundingCatalogProvider(_depositCatalog));
    ref.watch(depositReceiptWatchProvider);
    // Earlier deposits keep resolving in the background while new ones proceed.
    for (final pending in ref.watch(pendingDepositSubmissionsProvider)) {
      ref.watch(depositCreditWatchProvider(pending.key));
    }
    final choice = FundingChoice.of(
      catalog.catalog?.assets.where(_depositRoute) ?? const [],
      selection,
      defaultChain: fundingDefaultChain(ref),
    );
    final asset = choice.asset;
    final query = asset == null
        ? null
        : DepositWalletQuery(market: TransferMarket.perp, asset: asset);
    final balances = <String, String?>{};
    final rawAmounts = <String, Decimal?>{};
    for (final a in choice.assets) {
      final q = DepositWalletQuery(market: TransferMarket.perp, asset: a);
      ref.watch(depositWalletAutoReadProvider(q));
      final snap = ref.watch(depositWalletProvider(q)).account;
      final raw = snap?.query.sameAsset(q) == true ? snap!.assetBalance : null;
      rawAmounts[a.asset] = raw;
      balances[a.asset] = raw != null ? fundingBalanceText(raw.toString(), a.asset) : null;
    }
    final sortedAssets = [
      ...choice.assets.where((a) => a.isNative),
      ...(choice.assets.where((a) => !a.isNative).toList()
        ..sort((a, b) {
          final ba = rawAmounts[a.asset], bb = rawAmounts[b.asset];
          if (ba == null && bb == null) return 0;
          if (ba == null) return 1;
          if (bb == null) return -1;
          return bb.compareTo(ba);
        })),
    ];
    final model = query == null ? null : _model(query);
    final catalogError = catalog.failureKey == null || catalog.catalog != null
        ? null
        : apiErrorText(context, catalog.failureKey!, catalog.errorDetails);
    return AccountsPage(
      title: l.fundingAccountTitle,
      showBack: false,
      actions: fundingHeaderActions(context),
      onRefresh: () => _refresh(query),
      footer: [
        if (model?.shortfall case final shortfall?) ...[
          DepositAlert(
            text: shortfall == _Shortfall.asset
                ? l.fundingAssetShort(query!.asset.asset)
                : l.fundingGasShort,
            action: shortfall == _Shortfall.asset ? l.fundingAddFund : l.fundingAddGas,
            onAction: () => _addFunds(choice, query, gas: shortfall == _Shortfall.gas),
          ),
          const SizedBox(height: 12),
        ],
        _footer(l, query, model),
      ],
      children: [
        FundingTabs(operation: FundingOperation.deposit, onChanged: widget.onOperation),
        const SizedBox(height: 12),
        DepositRoute(
          from: fundingWalletName(l, ref.watch(authProvider.select((s) => s.identity?.walletKind))),
          to: fundingAccountText(l, ref.watch(activeAccountEntryProvider)),
        ),
        const SizedBox(height: 12),
        _network(l, choice, query),
        const SizedBox(height: 12),
        _amount(choice, query, model, balances, sortedAssets),
        if (model?.error ?? catalogError case final error?) ...[
          const SizedBox(height: 12),
          FundingError(error),
        ],
        // The 44px Max target keeps the designed 28px row on 12px gaps.
        const SizedBox(height: 4),
        FundingBalanceRow(
          label: l.fundingBalance,
          value: model?.balance,
          loading: catalog.loading || (model?.loading ?? false),
          showMax: !(model?.empty ?? false),
          onAdd: choice.chainId == null ? null : () => _addFunds(choice, query),
          onMax: model?.max == null
              ? null
              : () {
                  selection.amount.text = model!.max!;
                  _edited(query);
                },
        ),
        const SizedBox(height: 4),
        if (choice.chainId case final chain?)
          FundingGuidance(l.fundingDepositTime(fundingNetworkName(l, chain))),
      ],
    );
  }

  Widget _network(AppLocalizations l, FundingChoice choice, DepositWalletQuery? query) =>
      FundingDropdown<int>(
        options: [
          for (final id in choice.chains)
            FundingOption(id, fundingNetworkName(l, id), FundingNetworkIcon(id)),
        ],
        selected: choice.chainId,
        onSelected: (id) {
          selection.select(chainId: id, shownChain: choice.chainId);
          _edited(null);
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

  Widget _amount(FundingChoice choice, DepositWalletQuery? query, _DepositModel? model, Map<String, String?> balances, List<FundingAsset> sortedAssets) {
    final asset = choice.asset;
    return FundingDropdown<String>(
      options: [
        for (final a in sortedAssets) FundingOption(a.asset, a.asset, FundingAssetIcon(a.asset), balance: balances[a.asset]),
      ],
      selected: asset?.asset,
      onSelected: (value) {
        selection.select(asset: value, shownAsset: asset?.asset);
        _edited(null);
      },
      builder: (context, open, toggle) => FundingAmountField(
        controller: selection.amount,
        decimals: asset?.decimals ?? 0,
        asset: asset?.asset ?? '—',
        enabled: asset != null,
        error: model?.amountError ?? false,
        onChanged: (_) => _edited(query),
        assetSelector: FundingAssetSelector(asset: asset?.asset ?? '—', open: open, onTap: toggle),
      ),
    );
  }

  Widget _footer(AppLocalizations l, DepositWalletQuery? query, _DepositModel? model) {
    final identity = ref.watch(authProvider.select((s) => s.identity));
    final preparingEntry = ref.watch(depositEntryProvider);
    final approving = model?.approving ?? false, approval = model?.needsApproval ?? false;
    final ready = query != null && model!.ready && !ref.watch(authProvider).busy;
    return AccountAction(
      fadeDisabled: true,
      key: const Key('funding-deposit-submit'),
      label: identity?.needsWalletConnection == true
          ? l.reconnectExternalWallet
          : approval
          ? l.fundingApproveAsset(query!.asset.asset)
          : l.fundingDeposit,
      busy:
          confirming ||
          (model?.initialLoading ?? false) ||
          (model?.waitingApproval ?? false) ||
          approving ||
          (model?.preparing ?? false) ||
          preparingEntry,
      onPressed:
          walletConnectionAction(context, ref, identity) ?? (!ready ? null : () => _submit(query)),
    );
  }

  _DepositModel _model(DepositWalletQuery query) {
    ref.watch(depositWalletAutoReadProvider(query));
    final wallet = ref.watch(depositWalletProvider(query)),
        gas = ref.watch(depositGasProvider(query));
    final approvalWait = ref.watch(depositApprovalWaitProvider((approvalWaitScope, query)));
    ref.listen(depositWalletProvider(query).select((s) => s.account), (_, _) {
      _estimateLater(query);
    });
    final amount = selection.amount.text.trim();
    final check = checkDepositAmount(
      input: amount,
      query: query,
      snapshot: wallet.account,
      // A background read retains the last observation for presentation.
      // The explicit entry/confirm controllers still await fresh preflight.
      stale: wallet.stale && !wallet.busy,
    );
    final estimateMatches = estimated == (query, amount);
    final hasEstimate =
        estimateMatches &&
        check.units != null &&
        gas.account?.transaction.amountUnits == check.units;
    final gasFailure = estimateMatches ? gas.failure : null;
    final gasReady = hasEstimate && (gas.busy || !gas.stale) && gas.failure == null;
    final transient = {'depositReadRequired', 'depositReadStale'}.contains(check.errorKey);
    final amountError =
        check.errorKey != null && !transient ||
        gasFailure != null ||
        {'depositBalanceInsufficient', 'depositGasBalanceInsufficient'}.contains(actionError?.key);
    // A balance or gas shortfall is shown in the footer with its top-up entry.
    String? error;
    _Shortfall? shortfall;
    if (check.errorKey == 'depositBalanceInsufficient' ||
        actionError?.key == 'depositBalanceInsufficient') {
      shortfall = _Shortfall.asset;
    } else if (gasFailure?.key == 'depositGasBalanceInsufficient' ||
        actionError?.key == 'depositGasBalanceInsufficient') {
      shortfall = _Shortfall.gas;
    } else if (actionError?.key == 'walletTransactionWrongChain') {
      final l = AppLocalizations.of(context);
      error = l.fundingSwitchNetwork(fundingNetworkName(l, query.asset.chainId));
    } else if (actionError case final e?) {
      error = apiErrorText(context, e.key, e.details, fallbackText: depositMessage(context, e.key));
    } else if (check.errorKey case final key? when !transient) {
      error = depositMessage(context, key);
    } else if (approvalWait.failure ?? gasFailure ?? wallet.failure case final f?) {
      error = apiErrorText(context, f.key, f.details, fallbackText: depositMessage(context, f.key));
    }
    final snapshot = wallet.account?.query.sameAsset(query) == true ? wallet.account : null;
    return _DepositModel(
      balance: snapshot == null
          ? null
          : fundingBalanceText(snapshot.assetBalance.toString(), query.asset.asset),
      max: snapshot == null || wallet.stale ? null : snapshot.assetBalance.toString(),
      empty: snapshot?.assetUnits == BigInt.zero,
      shortfall: shortfall,
      loading: wallet.busy && wallet.account == null,
      initialLoading:
          wallet.busy && wallet.account == null || gas.busy && check.units != null && !hasEstimate,
      error: error,
      amountError: amountError,
      approving: ref.watch(depositApprovalProvider).step == DepositApprovalStep.preparing,
      needsApproval: check.allowanceSufficient == false,
      preparing: ref.watch(depositSubmissionProvider).step == DepositSubmissionStep.preparing,
      waitingApproval: approvalWait.busy,
      ready: check.units != null && !amountError && wallet.failure == null && gasReady,
    );
  }
}

enum _Shortfall { asset, gas }

class _DepositModel {
  const _DepositModel({
    required this.balance,
    required this.max,
    required this.empty,
    required this.shortfall,
    required this.loading,
    required this.initialLoading,
    required this.error,
    required this.amountError,
    required this.approving,
    required this.needsApproval,
    required this.preparing,
    required this.waitingApproval,
    required this.ready,
  });
  final String? balance, max, error;
  final _Shortfall? shortfall;
  final bool empty,
      loading,
      initialLoading,
      amountError,
      approving,
      needsApproval,
      preparing,
      waitingApproval,
      ready;
}
