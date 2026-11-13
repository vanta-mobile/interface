import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_read_provider.dart';
import '../application/asset_index_provider.dart';
import '../application/known_asset_mode_provider.dart';
import '../application/open_orders_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/aster_open_orders.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/position_card_metrics.dart';
import '../domain/position_risk.dart';
import 'position_close_sheet.dart';
import 'position_margin_screen.dart';
import 'position_tpsl_screen.dart';
import 'trade_position_card.dart';

/// [TradePositionCard] wired to the signed account reads, as shown on both the
/// Futures Positions tab and the Portfolio page: margin ratio from account
/// totals, TP/SL rows from the same wallet's open orders, and the shared
/// TP/SL, close and margin flows.
class AccountPositionCard extends ConsumerWidget {
  const AccountPositionCard({super.key, required this.position, this.hidden = false});
  final PositionRisk position;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(positionRiskProvider.select((s) => s.account?.address));
    final account = ref.watch(accountReadProvider.select((s) => s.account));
    final known = ref.watch(knownAssetModeProvider);
    final orders = ref.watch(openOrdersReadProvider.select((s) => s.account));
    final assetMode = known != null && known.address.toLowerCase() == address?.toLowerCase()
        ? known.mode
        : null;
    // Public USD index rates are needed only for multi-asset cross ratios.
    final rates = assetMode == FuturesAssetMode.multi ? ref.watch(assetIndexProvider) : null;
    final sameWallet = address != null && orders?.address.toLowerCase() == address.toLowerCase();
    final p = position;
    return TradePositionCard(
      position: p,
      hidden: hidden,
      marginRatio: address == null
          ? null
          : positionMarginRatio(p, account, address, assetMode: assetMode, rates: rates),
      exits: positionExitOrders(p, sameWallet ? orders!.orders : const <AsterOpenOrder>[]),
      onTpSl: () => openPositionTpSl(context, ref, p),
      onEditPartial: () => openPositionTpSl(context, ref, p),
      onMarket: () => showPositionCloseSheet(context, p),
      onLimit: () => showPositionCloseSheet(context, p, limit: true),
      onAdjustMargin: p.isolated
          ? () => openPositionMargin(context, symbol: p.symbol, side: p.side)
          : null,
    );
  }
}
