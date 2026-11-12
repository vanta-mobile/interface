import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import '../../../core/theme.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';
import '../application/asset_metadata_provider.dart';
import '../domain/asset_metadata.dart';
import '../domain/portfolio_overview.dart';
import 'asset_token_logo.dart';
import 'mode_settings_sheet.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';

void showPortfolioAssetDetails(
  BuildContext context, {
  required PortfolioAsset asset,
  required bool hidden,
  required bool preview,
}) => showModeSettingsSheet<void>(
  context,
  SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.viewInsetsOf(context).bottom),
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
    void open(FundingOperation operation) {
      if (preview) {
        portfolioPreviewNotice(context);
        return;
      }
      Navigator.pop(context);
      openFunding(context, operation);
    }

    return Column(
      key: const Key('portfolio-asset-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AssetHeader(symbol: asset.symbol),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: PortfolioColors.assetDivider),
        const SizedBox(height: 16),
        _AssetBalance(asset: asset, hidden: hidden),
        const SizedBox(height: 16),
        _AssetMetrics(asset: asset, hidden: hidden),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PortfolioAction(
                key: const Key('asset-details-withdraw'),
                label: l.fundingWithdraw,
                onPressed: () => open(FundingOperation.withdraw),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PortfolioAction(
                key: const Key('asset-details-deposit'),
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

class _AssetHeader extends ConsumerWidget {
  const _AssetHeader({required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref
        .watch(assetMetadataProvider(AssetMetadataSource.names))
        .snapshot
        ?.forSymbol(symbol)
        ?.displayName(Localizations.localeOf(context).languageCode == 'zh');
    return Row(
      children: [
        PortfolioAssetBadge(symbol: symbol, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(symbol, style: PortfolioTypography.assetSymbol),
              if (name != null && name != symbol) ...[
                const SizedBox(height: 4),
                Text(
                  name,
                  style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: const Key('asset-details-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.pop(context),
          icon: const PortfolioIcon('asset-close.svg', size: 24),
        ),
      ],
    );
  }
}

class _AssetBalance extends StatelessWidget {
  const _AssetBalance({required this.asset, required this.hidden});
  final PortfolioAsset asset;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(AppLocalizations.of(context).fundingBalance, style: PortfolioTypography.caption),
      LayoutBuilder(
        builder: (context, constraints) {
          final usd = AnimatedNumberText(
            hidden ? '••••' : portfolioUsd(asset.usd),
            comparisonValue: hidden ? null : asset.usd?.toString(),
            softWrap: true,
            style: PortfolioTypography.assetSymbol,
          );
          final quantity = SelectableText(
            hidden ? '••••' : '${portfolioAmount(asset.balance)} ${asset.symbol}',
            textAlign: TextAlign.right,
            style: PortfolioTypography.caption.copyWith(fontWeight: FontWeight.w400),
          );
          if (constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(12) > 16) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [usd, const SizedBox(height: 4), quantity],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: usd),
              const SizedBox(width: 8),
              Flexible(child: quantity),
            ],
          );
        },
      ),
    ],
  );
}

class _AssetMetrics extends StatelessWidget {
  const _AssetMetrics({required this.asset, required this.hidden});
  final PortfolioAsset asset;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String amount(Decimal? value) => hidden ? '••••' : portfolioAmount(value);
    return PortfolioCard(
      radius: 12,
      border: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final (index, label, value) in [
            (0, l.asterMarginBalance, amount(asset.margin)),
            (1, l.portfolioAvailableForOrder, amount(asset.available)),
            (2, l.accountUnrealizedPnl, hidden ? '••••' : portfolioUsd(asset.pnlUsd, signed: true)),
          ])
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: PortfolioTypography.caption.copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedNumberText(
                      value,
                      key: ValueKey('asset-details-metric-$index'),
                      softWrap: true,
                      textAlign: TextAlign.right,
                      style: PortfolioTypography.caption.copyWith(
                        fontWeight: index == 2 ? FontWeight.w500 : FontWeight.w400,
                        color: index == 2 && !hidden
                            ? portfolioPnlColor(asset.pnlUsd)
                            : PortfolioColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PortfolioAssetBadge extends StatelessWidget {
  const PortfolioAssetBadge({super.key, required this.symbol, this.size = 32});
  final String symbol;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = switch (symbol) {
      'USDT' => 'usdt.webp',
      'BNB' => 'bnb.svg',
      'BTC' => 'btc.svg',
      _ => null,
    };
    return AssetTokenLogo(
      symbol: symbol,
      size: size,
      fallback: asset == null
          ? CircleAvatar(
              radius: size / 2,
              backgroundColor: PortfolioColors.card,
              child: Text(
                symbol.isEmpty ? '?' : symbol.characters.first,
                style: PortfolioTypography.caption,
              ),
            )
          : asset.endsWith('.webp')
          ? Image.asset('assets/portfolio/$asset', width: size, height: size)
          : SizedBox.square(
              dimension: size,
              child: FittedBox(child: PortfolioIcon(asset, size: 32)),
            ),
    );
  }
}
