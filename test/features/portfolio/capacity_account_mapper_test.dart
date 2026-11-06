import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/capacity_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_margin_mapper.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

void main() {
  CapacityAccount map(Object? payload) => mapCapacityAccount(
    payload,
    address: accountAddress,
    receivedAt: liveOrderClock,
    units: capacityUnits(),
  );
  test('zero positions retain configuration and reserved order margin', () {
    final raw = capacityAccountPayload();
    (raw['positions'] as List).add(
      capacityPosition(symbol: 'ETHUSDT', isolated: true, orderMargin: '20'),
    );
    final result = map(raw);
    expect(result.positions.length, 2);
    expect(result.positions.last.quantity, Decimal.zero);
    expect(result.positions.last.orderMargin, Decimal.fromInt(20));
    expect(result.positions.last.isolated, true);
    expect(result.assets.single.available, Decimal.fromInt(100));
    expect(result.assets.single.crossWallet, Decimal.fromInt(150));
    expect(result.assets.single.crossPnl, Decimal.fromInt(-5));
    expect(result.address, accountAddress);
    expect(result.receivedAt, liveOrderClock);
    expect(() => result.positions.clear(), throwsUnsupportedError);
  });
  for (final key in [
    'availableBalance',
    'crossWalletBalance',
    'crossUnPnl',
    'initialMargin',
    'marginAvailable',
  ]) {
    test('missing asset field $key is never manufactured zero', () {
      final raw = capacityAccountPayload();
      ((raw['assets'] as List).single as Map).remove(key);
      expect(() => map(raw), throwsFormatException);
    });
  }
  for (final key in [
    'symbol',
    'positionSide',
    'positionAmt',
    'notional',
    'entryPrice',
    'isolated',
    'leverage',
    'openOrderInitialMargin',
    'maintMargin',
    'maxNotional',
    'isolatedWallet',
  ]) {
    test('missing zero-position field $key fails', () {
      final raw = capacityAccountPayload();
      ((raw['positions'] as List).single as Map).remove(key);
      expect(() => map(raw), throwsFormatException);
    });
  }
  for (final (quantity, notional, side) in [
    ('0', '1', 'BOTH'),
    ('1', '0', 'BOTH'),
    ('1', '-100', 'BOTH'),
    ('-1', '-100', 'LONG'),
    ('1', '100', 'SHORT'),
  ]) {
    test('inconsistent quantity/notional/direction $quantity $notional $side rejected', () {
      final raw = capacityAccountPayload();
      raw['positions'] = [
        {...capacityPosition(quantity: quantity, side: side), 'notional': notional},
      ];
      expect(() => map(raw), throwsFormatException);
    });
  }
  for (final key in ['openOrderInitialMargin', 'maintMargin', 'maxNotional', 'entryPrice']) {
    test('negative $key rejected including on hidden zero rows', () {
      final raw = capacityAccountPayload();
      ((raw['positions'] as List).single as Map)[key] = '-1';
      expect(() => map(raw), throwsFormatException);
    });
  }
  test('unknown units, missing margin asset and duplicate rows fail explicitly', () {
    for (final variant in ['units', 'asset', 'duplicate-position', 'duplicate-asset']) {
      final raw = capacityAccountPayload();
      if (variant == 'units') ((raw['positions'] as List).single as Map)['symbol'] = 'UNKNOWNUSDT';
      if (variant == 'asset') raw['assets'] = <dynamic>[];
      if (variant == 'duplicate-position') (raw['positions'] as List).add(capacityPosition());
      if (variant == 'duplicate-asset') (raw['assets'] as List).add(capacityAsset());
      expect(() => map(raw), throwsFormatException, reason: variant);
    }
  });
  test('numeric lexemes preserve fractional financial values through exact JSON decoding', () {
    final raw = capacityAccountPayload();
    // The decoder used by the capacity service converts a fractional JSON
    // number directly to its decimal spelling, without a double intermediate.
    final decoded =
        decodePositionMarginJson('{"amount":0.100000000000000001}') as Map<String, dynamic>;
    ((raw['assets'] as List).single as Map)['availableBalance'] = decoded['amount'];
    expect(map(raw).assets.single.available, Decimal.parse('0.100000000000000001'));
    ((raw['assets'] as List).single as Map)['availableBalance'] = 0.1;
    expect(() => map(raw), throwsFormatException);
  });
  for (final leverage in <Object?>[null, 10, '0', '-1', '1e1', '01', '10000']) {
    test('invalid leverage $leverage rejected', () {
      final raw = capacityAccountPayload();
      ((raw['positions'] as List).single as Map)['leverage'] = leverage;
      expect(() => map(raw), throwsFormatException);
    });
  }
  for (final payload in <Object?>[
    null,
    [],
    {},
    {'assets': <dynamic>[], 'positions': <dynamic>[], 'canTrade': 'true'},
  ]) {
    test(
      'malformed account ${payload.runtimeType} $payload rejected',
      () => expect(() => map(payload), throwsFormatException),
    );
  }
}
