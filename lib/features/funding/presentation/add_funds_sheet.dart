import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../application/deposit_gas_reserve_provider.dart';
import '../application/deposit_wallet_provider.dart';
import '../application/funding_flow_provider.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';
import 'deposit_components.dart';
import 'deposit_messages.dart';
import 'funding_components.dart';
import 'funding_dropdown.dart';

/// The network and token the user topped up; [asset] is null after adding gas,
/// which keeps the deposit form's own asset.
typedef AddFundsResult = ({int chainId, String? asset});

/// Step 1 of a deposit: send tokens from another wallet to this app's wallet
/// on the same network. [gas] opens on the network's native gas token.
Future<AddFundsResult?> showAddFundsSheet(
  BuildContext context, {
  required List<FundingAsset> assets,
  required int chainId,
  String? asset,
  bool gas = false,
}) => showModalBottomSheet<AddFundsResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: PortfolioColors.inset,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    side: BorderSide(color: PortfolioColors.card),
  ),
  builder: (_) => AddFundsSheet(assets: assets, chainId: chainId, asset: asset, gas: gas),
);

class AddFundsSheet extends ConsumerStatefulWidget {
  const AddFundsSheet({
    super.key,
    required this.assets,
    required this.chainId,
    this.asset,
    this.gas = false,
  });
  final List<FundingAsset> assets;
  final int chainId;
  final String? asset;
  final bool gas;

  @override
  ConsumerState<AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<AddFundsSheet> {
  late int chainId = widget.chainId;
  late FundingAsset token = _initialToken();

  List<int> get _chains => [
    for (final id in fundingEvmChainIds)
      if (widget.assets.any((a) => a.chainId == id)) id,
  ];

  /// The network's gas token leads; it is offered even when the catalog does
  /// not list it as a deposit asset, since every deposit needs it for fees.
  List<FundingAsset> _tokens(int chain) {
    final onChain = widget.assets.where((a) => a.chainId == chain);
    final native =
        onChain.where((a) => a.isNative).firstOrNull ??
        FundingAsset(
          asset: fundingNativeSymbol(chain),
          displayName: fundingNativeSymbol(chain),
          chainId: chain,
          tokenAddress: fundingNativePlaceholder,
          decimals: 18,
          isNative: true,
          routeType: 'normal',
        );
    return [native, ...onChain.where((a) => !a.isNative)];
  }

  FundingAsset _initialToken() {
    final tokens = _tokens(chainId);
    if (widget.gas) return tokens.first;
    return tokens.where((a) => a.asset == widget.asset).firstOrNull ??
        tokens.skip(1).firstOrNull ??
        tokens.first;
  }

  DepositWalletQuery get _query => DepositWalletQuery(market: TransferMarket.perp, asset: token);

  void _selectChain(int chain) => setState(() {
    final tokens = _tokens(chain);
    chainId = chain;
    token =
        tokens.where((a) => a.asset == token.asset && a.isNative == token.isNative).firstOrNull ??
        (token.isNative ? tokens.first : tokens.skip(1).firstOrNull ?? tokens.first);
  });

  /// A refresh the user asked for; background polls do not spin the icon.
  bool refreshing = false;

  Future<void> _refresh() async {
    setState(() => refreshing = true);
    try {
      await Future.wait([
        ref.read(depositWalletProvider(_query).notifier).refresh(),
        ref.refresh(depositGasReserveProvider(chainId).future).then<void>((_) {}, onError: (_) {}),
      ]);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), query = _query;
    final identity = ref.watch(authProvider.select((s) => s.identity));
    ref.watch(depositWalletAutoReadProvider(query));
    final wallet = ref.watch(depositWalletProvider(query));
    final snapshot = wallet.account?.query.sameAsset(query) == true ? wallet.account : null;
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height - media.padding.top - 24),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(l),
              const Divider(height: 1, thickness: 1, color: PortfolioColors.line),
              Flexible(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    key: const Key('funding-add-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FundingField(
                          label: l.fundingAddFundsTo,
                          value: fundingWalletName(l, identity?.walletKind),
                        ),
                        const SizedBox(height: 8),
                        _selectors(l),
                        const SizedBox(height: 8),
                        Text(
                          l.fundingAddFundsHint,
                          style: FundingTypography.value.copyWith(color: PortfolioColors.secondary),
                        ),
                        if (identity?.walletAddress case final address?) ...[
                          const SizedBox(height: 16),
                          Center(child: DepositAddressQr(address)),
                          const SizedBox(height: 8),
                          _address(l, address),
                        ],
                        const SizedBox(height: 8),
                        _balances(l, wallet, snapshot),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AccountAction(
                key: const Key('funding-add-transferred'),
                label: l.fundingTransferred,
                onPressed: () => Navigator.pop<AddFundsResult>(context, (
                  chainId: chainId,
                  asset: token.isNative ? null : token.asset,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: Row(
      children: [
        Expanded(child: Text(l.fundingAddFunds, style: AccountTypography.heading)),
        IconButton(
          key: const Key('funding-add-close'),
          tooltip: tr(context, 'close'),
          onPressed: () => Navigator.pop(context),
          icon: const PortfolioIcon('close.svg', size: 24),
        ),
      ],
    ),
  );

  // Both cards share one layout, so they keep the same height side by side.
  Widget _selectors(AppLocalizations l) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: FundingDropdown<int>(
          options: [
            for (final id in _chains)
              FundingOption(id, fundingNetworkName(l, id), FundingNetworkIcon(id)),
          ],
          selected: chainId,
          onSelected: _selectChain,
          builder: (context, open, toggle) => FundingField(
            key: const Key('funding-add-network'),
            label: l.fundingNetworkLabel,
            value: fundingNetworkName(l, chainId),
            icon: FundingNetworkIcon(chainId),
            open: open,
            onTap: toggle,
            radius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
        ),
      ),
      Expanded(
        child: FundingDropdown<String>(
          options: [
            for (final a in _tokens(chainId))
              FundingOption(a.asset, a.asset, FundingAssetIcon(a.asset)),
          ],
          selected: token.asset,
          onSelected: (value) =>
              setState(() => token = _tokens(chainId).firstWhere((a) => a.asset == value)),
          builder: (context, open, toggle) => FundingField(
            key: const Key('funding-add-token'),
            label: token.isNative ? l.fundingGasToken : l.fundingTokenAsset,
            value: token.asset,
            icon: FundingAssetIcon(token.asset),
            open: open,
            onTap: toggle,
            radius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ),
      ),
    ],
  );

  Widget _address(AppLocalizations l, String address) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(l.fundingDepositAddress, style: FundingTypography.value),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: PortfolioColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                address,
                key: const Key('funding-add-address'),
                style: AccountTypography.body,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('funding-add-copy'),
              tooltip: tr(context, 'copyAddress'),
              onPressed: () {
                copyAccountAddress(address);
                AppToast.showSuccess(context, l.pointsAddressCopied);
              },
              icon: const PortfolioIcon('funding-copy.svg', size: 18),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _balances(
    AppLocalizations l,
    AccountSnapshotState<DepositWalletSnapshot> wallet,
    DepositWalletSnapshot? snapshot,
  ) {
    final native = fundingNativeSymbol(chainId), loading = snapshot == null && wallet.busy;
    final reserve = ref.watch(depositGasReserveProvider(chainId)).value;
    final refresh = _RefreshAction(
      spinning: refreshing,
      onTap: refreshing ? null : () => unawaited(_refresh()),
    );
    final failure = wallet.failure;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!token.isNative)
            _BalanceRow(
              key: const Key('funding-add-balance'),
              label: l.fundingBalance,
              value: snapshot == null
                  ? null
                  : fundingAmountText(snapshot.assetBalance.toString(), token.asset),
              loading: loading,
              trailing: refresh,
            ),
          _BalanceRow(
            key: const Key('funding-add-gas-balance'),
            label: l.fundingGasBalance,
            value: snapshot == null
                ? null
                : fundingAmountText(snapshot.nativeBalance.toString(), native),
            loading: loading,
            trailing: token.isNative
                ? refresh
                : FundingTextAction(
                    tapKey: const Key('funding-add-gas'),
                    label: l.fundingAdd,
                    onTap: () => setState(() => token = _tokens(chainId).first),
                  ),
          ),
          if (snapshot != null && reserve != null && snapshot.nativeBalance < reserve)
            Row(
              key: const Key('funding-add-gas-hint'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: PortfolioIcon('info.svg', size: 16, color: PortfolioColors.warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.fundingGasReserveHint(fundingAmountText(reserve.toString(), native)),
                    style: FundingTypography.value.copyWith(color: PortfolioColors.warning),
                  ),
                ),
              ],
            ),
          if (failure != null) ...[
            const SizedBox(height: 8),
            FundingError(
              apiErrorText(
                context,
                failure.key,
                failure.details,
                fallbackText: depositMessage(context, failure.key),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    super.key,
    required this.label,
    required this.value,
    required this.loading,
    required this.trailing,
  });
  final String label;
  final String? value;
  final bool loading;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 28),
    child: Row(
      children: [
        Expanded(child: Text(label, style: PortfolioTypography.caption)),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: value == null && loading
                ? const FundingSkeleton(width: 72)
                : AnimatedNumberText(
                    value ?? '—',
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: FundingTypography.value,
                  ),
          ),
        ),
        const SizedBox(width: 6),
        trailing,
      ],
    ),
  );
}

class _RefreshAction extends StatefulWidget {
  const _RefreshAction({required this.spinning, this.onTap});
  final bool spinning;
  final VoidCallback? onTap;
  @override
  State<_RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<_RefreshAction> with SingleTickerProviderStateMixin {
  late final spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  @override
  void initState() {
    super.initState();
    if (widget.spinning) spin.repeat();
  }

  @override
  void didUpdateWidget(_RefreshAction old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      spin.repeat();
    } else if (!widget.spinning && old.spinning) {
      // Finish the current turn instead of snapping back.
      spin.forward(from: spin.value);
    }
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: AppLocalizations.of(context).fundingRefreshBalance,
    child: InkWell(
      key: const Key('funding-add-refresh'),
      onTap: widget.onTap,
      child: SizedBox(
        width: 32,
        height: 44,
        child: Align(
          alignment: Alignment.centerRight,
          child: RotationTransition(
            turns: spin,
            child: const PortfolioIcon('funding-refresh.svg', size: 16),
          ),
        ),
      ),
    ),
  );
}
