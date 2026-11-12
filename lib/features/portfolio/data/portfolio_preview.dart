import 'package:decimal/decimal.dart';

import '../domain/aster_account.dart';
import '../domain/portfolio_overview.dart';
import '../domain/position_risk.dart';

/// Figma sample values, available only in the explicitly labelled local preview.
/// This data is never passed to signing, account snapshots or order providers.
PortfolioOverview portfolioPreview() {
  Decimal d(String value) => Decimal.parse(value);
  return PortfolioOverview(
    totalUsd: d('3840'),
    performance: PortfolioPerformance(
      pnl: d('124.35'),
      returnPercent: d('3.24'),
      volume: d('14205.80'),
      todayPnl: d('24.41'),
      todayPercent: d('0.64'),
      start: DateTime.utc(2026, 10, 27),
      end: DateTime.utc(2026, 11, 2),
      history: [
        '0',
        '-1',
        '4',
        '14',
        '7',
        '-2',
        '18',
        '13',
        '9',
        '16',
        '15',
        '22',
        '19',
        '30',
        '33',
        '56',
        '49',
        '34',
        '42',
        '46',
        '37',
        '63',
        '59',
        '68',
        '65',
        '77',
        '70',
        '83',
        '74',
        '81',
        '85',
        '79',
        '87',
        '82',
        '89',
        '124.35',
      ].map(d),
      dailyPnl: {
        DateTime.utc(2026, 11, 1): d('18.40'),
        DateTime.utc(2026, 11, 2): d('24.41'),
        DateTime.utc(2026, 11, 3): d('-8.60'),
        DateTime.utc(2026, 11, 4): d('-12.38'),
      },
    ),
    assets: [
      PortfolioAsset(
        symbol: 'USDT',
        balance: d('3000'),
        available: d('2986.45'),
        margin: d('3000.07'),
        pnl: d('0.07'),
        pnlUsd: d('0.07'),
        usd: d('3000'),
      ),
      PortfolioAsset(
        symbol: 'BNB',
        balance: d('1.2'),
        available: d('1.2'),
        margin: d('1.2'),
        usd: d('840'),
      ),
      PortfolioAsset(
        symbol: 'BTC',
        balance: Decimal.zero,
        available: Decimal.zero,
        margin: Decimal.zero,
        usd: Decimal.zero,
      ),
    ],
  );
}

/// Labeled preview positions for the shared position card; never account data.
List<PositionRisk> portfolioPreviewPositions() {
  Decimal d(String value) => Decimal.parse(value);
  return [
    for (final long in [true, false])
      PositionRisk(
        symbol: 'AAPLUSDT',
        side: long ? 'LONG' : 'SHORT',
        quantity: d(long ? '0.04' : '-0.04'),
        entryPrice: d('338.5200'),
        markPrice: d('322.0455'),
        liquidationPrice: d('310.5200'),
        unrealizedProfit: d(long ? '0.07' : '-0.07'),
        notional: d('13.55'),
        isolated: false,
        isolatedWallet: Decimal.zero,
        leverage: 20,
        units: const AsterContractUnits(base: 'AAPL', quote: 'USDT', margin: 'USDT'),
      ),
  ];
}
