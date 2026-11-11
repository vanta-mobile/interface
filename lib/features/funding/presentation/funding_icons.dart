import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../portfolio/presentation/asset_token_logo.dart';
import '../application/funding_icon_provider.dart';

class FundingAssetIcon extends StatelessWidget {
  const FundingAssetIcon(this.symbol, {super.key});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final fallback = switch (symbol) {
      'BNB' => const PortfolioIcon('funding-bnb.svg', size: 24),
      'USDT' => Image.asset('assets/portfolio/usdt.webp', width: 24, height: 24),
      _ => CircleAvatar(
        radius: 12,
        backgroundColor: PortfolioColors.button,
        child: Text(
          symbol.isEmpty ? '?' : symbol.characters.first,
          style: FundingTypography.fieldLabel.copyWith(color: PortfolioColors.text),
        ),
      ),
    };
    return AssetTokenLogo(symbol: symbol, size: 24, fallback: fallback);
  }
}

class FundingNetworkIcon extends ConsumerWidget {
  const FundingNetworkIcon(this.chainId, {super.key});
  final int chainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AssetLogoImage(
    size: 24,
    image: ref.watch(fundingNetworkLogoProvider(chainId)),
    fallback: const Icon(Icons.public, size: 24, color: PortfolioColors.secondary),
  );
}
