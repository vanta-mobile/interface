import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';

import '../../support/aster_account.dart';

void main() {
  final time = DateTime.utc(2026);
  test('REST refresh retains zero-position isolated debt and clocks for hidden zero rows', () {
    final payload = accountPayload()
      ..['positions'] = [
        {
          'symbol': 'BTCUSDT',
          'positionSide': 'BOTH',
          'positionAmt': '0',
          'isolated': true,
          'isolatedWallet': '-2',
          'updateTime': 1793620800123,
        },
        {
          'symbol': 'ETHUSDT',
          'positionSide': 'BOTH',
          'positionAmt': '0',
          'isolated': true,
          'isolatedWallet': '2',
          'updateTime': 1793620800124,
        },
      ];
    final account = mapAsterAccount(payload, address: accountAddress, receivedAt: time);
    expect(account.positions.single.symbol, 'BTCUSDT');
    expect(account.positions.single.isolatedWallet, Decimal.parse('-2'));
    expect(account.positionUpdatedAt['ETHUSDT:BOTH']!.millisecondsSinceEpoch, 1793620800124);
    expect(() => account.positionUpdatedAt.clear(), throwsUnsupportedError);
  });

  test('retains exact money, missing fields, units, inactive contracts and short direction', () {
    final account = accountFixture();
    expect(account.walletBalance, Decimal.parse('100.000000000000000001'));
    expect(account.canTrade, false);
    expect(account.assets.last.availableBalance, null);
    expect(account.positions, hasLength(1));
    expect(account.positions.single.quantity, Decimal.parse('-0.000000000000000001'));
    expect(account.positions.single.long, false);
    expect(account.positions.single.units?.base, 'BTC');
    expect(account.positions.single.units?.margin, 'USDT');
    expect(() => account.assets.clear(), throwsUnsupportedError);
    expect(() => account.positions.clear(), throwsUnsupportedError);
  });

  for (final invalid in ['NaN', '1e5', '', '0.1x', 0.1, true, List.filled(161, '1').join()]) {
    test('rejects malformed or rounded money $invalid', () {
      final payload = accountPayload()..['totalWalletBalance'] = invalid;
      expect(
        () => mapAsterAccount(payload, address: accountAddress, receivedAt: time),
        throwsFormatException,
      );
    });
  }

  test('missing summaries remain unknown and zero is preserved', () {
    final payload = accountPayload()
      ..remove('totalMarginBalance')
      ..['totalWalletBalance'] = '0';
    final account = mapAsterAccount(payload, address: accountAddress, receivedAt: time);
    expect(account.marginBalance, null);
    expect(account.walletBalance, Decimal.zero);
  });

  test('invalid required lists, duplicate balances and malformed positions fail the snapshot', () {
    final cases = <Map<String, Object?>>[
      accountPayload()..remove('assets'),
      accountPayload()..['positions'] = null,
      accountPayload()
        ..['assets'] = [
          {'asset': 'USDT', 'walletBalance': null},
        ],
      accountPayload()
        ..['assets'] = [
          {'asset': 'USDT', 'walletBalance': '1'},
          {'asset': 'USDT', 'walletBalance': '2'},
        ],
      for (final replacement in [
        {'positionSide': 'unknown'},
        {'positionSide': 'LONG'}, // negative long is contradictory
        {'leverage': '0'},
        {'entryPrice': '-1'},
        {'isolated': 'true'},
      ])
        accountPayload()
          ..['positions'] = [
            {
              ...(accountPayload()['positions']! as List).first as Map<String, Object?>,
              ...replacement,
            },
          ],
      accountPayload()
        ..['positions'] = [
          ...(accountPayload()['positions']! as List),
          (accountPayload()['positions']! as List).first,
        ],
    ];
    for (final payload in cases) {
      expect(
        () => mapAsterAccount(payload, address: accountAddress, receivedAt: time),
        throwsFormatException,
      );
    }
  });

  test('unknown contract units stay unknown instead of being inferred from the symbol', () {
    final account = mapAsterAccount(accountPayload(), address: accountAddress, receivedAt: time);
    expect(account.positions.single.units, null);
    expect(
      () => mapAsterContractUnits({
        'symbols': [<String, Object?>{}],
      }),
      throwsFormatException,
    );
  });

  test('valid Unicode contract identifiers are not rejected as malformed account data', () {
    final payload = accountPayload()
      ..['positions'] = [
        {'symbol': '币安人生USDT', 'positionSide': 'BOTH', 'positionAmt': '1'},
      ];
    final account = mapAsterAccount(payload, address: accountAddress, receivedAt: time);
    expect(account.positions.single.symbol, '币安人生USDT');
    final invalid = accountPayload()
      ..['positions'] = [
        {'symbol': 'BTC\nUSDT', 'positionSide': 'BOTH', 'positionAmt': '1'},
      ];
    expect(
      () => mapAsterAccount(invalid, address: accountAddress, receivedAt: time),
      throwsFormatException,
    );
  });
}
