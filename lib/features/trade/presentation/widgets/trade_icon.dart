import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../trade_theme.dart';

class TradeIcon extends StatelessWidget {
  const TradeIcon(this.asset, {super.key, this.size = 20, this.color = TradeColors.secondary});
  final String asset;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: SvgPicture.asset(
        'assets/trade/$asset.svg',
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ),
  );
}
