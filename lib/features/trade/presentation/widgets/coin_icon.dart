import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../portfolio/presentation/asset_token_logo.dart';
import '../trade_theme.dart';

/// Market symbols use official Aster metadata with verified design fallbacks.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.base = 'BTC', this.size = 32});
  final String base;
  final double size;

  static const _assets = {
    'BTC': (path: 'assets/trade/btc.svg', stock: false),
    'ETH': (path: 'assets/trade/eth.svg', stock: false),
    'SOL': (path: 'assets/trade/sol.svg', stock: false),
    'BNB': (path: 'assets/trade/bnb.svg', stock: false),
    'TSLA': (path: 'assets/trade/tsla.svg', stock: true),
    'AMZN': (path: 'assets/trade/amzn.svg', stock: true),
    'NVDA': (path: 'assets/trade/nvda.svg', stock: true),
    'AMD': (path: 'assets/trade/amd.svg', stock: true),
    'AAPL': (path: 'assets/trade/aapl.svg', stock: true),
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[base];
    return AssetTokenLogo(
      symbol: base,
      size: size,
      fallback: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: asset?.stock == true ? TradeColors.assetIconBackground : TradeColors.card,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: asset == null
              ? Text(
                  '◎',
                  style: TextStyle(fontSize: size * .67, color: TradeColors.text),
                )
              : SvgPicture.asset(
                  asset.path,
                  width: asset.stock ? size * .5625 : size,
                  height: asset.stock ? size * .5625 : size,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
