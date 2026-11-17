import 'package:flutter/material.dart';

import '../trade_theme.dart';

/// Exchange-advertised maximum, not the account's current leverage setting.
class MaxLeverageBadge extends StatelessWidget {
  const MaxLeverageBadge(this.leverage, {super.key});
  final int leverage;
  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    constraints: const BoxConstraints(minWidth: 40),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(8)),
    child: Text('${leverage}x', style: TradeTypography.small.copyWith(color: TradeColors.text)),
  );
}
