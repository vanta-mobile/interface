import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/domain/transfer_history.dart';
import '../../funding/presentation/funding_info_screen.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';

void showPortfolioAssetDetails(
  BuildContext context, {
  required PortfolioAsset asset,
  required bool hidden,
  required bool preview,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: PortfolioColors.inset,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: _AssetDetails(asset: asset, hidden: hidden, preview: preview),
    ),
  ),
);

class _AssetDetails extends StatelessWidget {
  const _AssetDetails({required this.asset, required this.hidden, required this.preview});
  final PortfolioAsset asset;
  final bool hidden, preview;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String amount(Decimal? value) => hidden ? '••••' : portfolioAmount(value);
    void open(FundingOperation operation) {
      if (preview) {
        portfolioPreviewNotice(context);
        return;
      }
      Navigator.pop(context);
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              FundingInfoScreen(initialMarket: TransferMarket.perp, initialOperation: operation),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PortfolioAssetBadge(symbol: asset.symbol),
            const SizedBox(width: 12),
            Expanded(child: SelectableText(asset.symbol, style: PortfolioTypography.heading)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l.accountWalletBalance, style: PortfolioTypography.caption),
        Text(hidden ? '••••' : portfolioUsd(asset.usd), style: PortfolioTypography.detailValue),
        SelectableText(
          '${amount(asset.balance)} ${asset.symbol}',
          style: PortfolioTypography.caption,
        ),
        const SizedBox(height: 20),
        PortfolioCard(
          radius: 12,
          border: false,
          child: Column(
            children: [
              for (final (label, value) in [
                (l.asterMarginBalance, asset.margin),
                (l.available, asset.available),
                (l.accountUnrealizedPnl, asset.pnl),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: PortfolioTypography.caption)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${amount(value)} ${asset.symbol}',
                          textAlign: TextAlign.right,
                          style: PortfolioTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PortfolioAction(
                label: l.fundingWithdraw,
                onPressed: () => open(FundingOperation.withdraw),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PortfolioAction(
                label: l.fundingDeposit,
                onPressed: () => open(FundingOperation.deposit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PortfolioAssetBadge extends StatelessWidget {
  const PortfolioAssetBadge({super.key, required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context) {
    final asset = switch (symbol) {
      'USDT' => 'usdt.webp',
      'BNB' => 'bnb.svg',
      'BTC' => 'btc.svg',
      _ => null,
    };
    return SizedBox.square(
      dimension: 32,
      child: asset == null
          ? CircleAvatar(
              radius: 16,
              backgroundColor: PortfolioColors.card,
              child: Text(symbol.characters.first, style: PortfolioTypography.caption),
            )
          : asset.endsWith('.webp')
          ? Image.asset('assets/portfolio/$asset', width: 32, height: 32)
          : PortfolioIcon(asset, size: 32),
    );
  }
}
