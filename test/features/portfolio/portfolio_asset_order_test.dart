import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';

void main() {
  PortfolioAsset asset(String symbol, String? usd, {String balance = '1'}) => PortfolioAsset(
    symbol: symbol,
    balance: Decimal.parse(balance),
    usd: usd == null ? null : Decimal.parse(usd),
  );
  PortfolioOverview overview(Iterable<PortfolioAsset> assets) =>
      PortfolioOverview(performance: PortfolioPerformance(), assets: assets);

  test('sorts by exact USD value rather than token quantity or rounded display', () {
    final data = overview([
      asset('SMALL', '10.000000000000000001', balance: '1000'),
      asset('LARGE', '10.000000000000000002', balance: '0.00001'),
      asset('MID', '10.0000000000000000015'),
    ]);
    expect(data.assets.map((a) => a.symbol), ['LARGE', 'MID', 'SMALL']);
    expect(data.assets.first.balance, Decimal.parse('0.00001'));
  });

  test('unknown values follow known positive, zero and negative values', () {
    final data = overview([
      asset('UNKNOWN_A', null),
      asset('NEGATIVE', '-2'),
      asset('ZERO', '0'),
      asset('UNKNOWN_B', null),
      asset('POSITIVE', '3'),
      asset('LESS_NEGATIVE', '-1'),
    ]);
    expect(data.assets.map((a) => a.symbol), [
      'POSITIVE',
      'ZERO',
      'LESS_NEGATIVE',
      'NEGATIVE',
      'UNKNOWN_A',
      'UNKNOWN_B',
    ]);
  });

  test('equal estimates keep source order and the input remains untouched', () {
    final source = [asset('FIRST', '1'), asset('SECOND', '1'), asset('TOP', '2')];
    final data = overview(source);
    expect(data.assets.map((a) => a.symbol), ['TOP', 'FIRST', 'SECOND']);
    expect(source.map((a) => a.symbol), ['FIRST', 'SECOND', 'TOP']);
    expect(() => data.assets.clear(), throwsUnsupportedError);
  });

  test('empty and single-asset snapshots retain their values', () {
    expect(overview([]).assets, isEmpty);
    final only = asset('ONLY', null);
    expect(overview([only]).assets.single, same(only));
  });
}
