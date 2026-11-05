import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/internal_transfer_mapper.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';

import '../../support/internal_transfer.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4);
  test('public whitelist preserves exact IDs; website precision caps and fallbacks', () {
    final catalog = mapInternalTransferCatalog(
      publicRows(['USDT', 'BTC', 'MSTRB', 'ZERO', 'HIGH']),
      publicRows([
        {'assetCode': 'USDT', 'assetDecimal': 2},
        {'assetCode': 'BTC', 'assetDecimal': 7},
        {'assetCode': 'HIGH', 'assetDecimal': 18},
        {'assetCode': 'ZERO', 'assetDecimal': 0},
        {'assetCode': 'BONUSUSD', 'assetDecimal': 2},
        {'assetCode': 'BONUSUSD', 'assetDecimal': 2},
      ]),
      now,
    );
    expect(
      {for (final a in catalog.assets) a.asset: a.precision},
      {'USDT': 2, 'BTC': 7, 'MSTRB': 2, 'ZERO': 2, 'HIGH': 8},
    );
    expect(() => catalog.assets.clear(), throwsUnsupportedError);
  });
  for (final invalid in [
    publicRows(['USDT', 'USDT']),
    publicRows(['USDT/BTC']),
    {
      'code': '000000',
      'data': ['USDT'],
    },
    {
      'code': '000001',
      'success': true,
      'data': ['USDT'],
    },
  ]) {
    test('invalid support envelope/list $invalid blocks', () {
      expect(() => mapInternalTransferCatalog(invalid, publicRows([]), now), throwsFormatException);
    });
  }
  for (final decimals in [
    [
      {'assetCode': 'USDT', 'assetDecimal': 2},
      {'assetCode': 'USDT', 'assetDecimal': 3},
    ],
    [
      {'assetCode': 'USDT', 'assetDecimal': '2'},
    ],
    [
      {'assetCode': 'USDT', 'assetDecimal': -1},
    ],
    [
      {'assetCode': 'USDT', 'assetDecimal': 256},
    ],
  ]) {
    test('invalid/conflicting precision $decimals blocks', () {
      expect(
        () => mapInternalTransferCatalog(publicRows(['USDT']), publicRows(decimals), now),
        throwsFormatException,
      );
    });
  }
  test('Spot limit uses free excluding locked; Futures uses selected asset cap, not balances', () {
    final spot = transferContext(now: now),
        futures = transferContext(now: now, direction: InternalTransferDirection.futuresToSpot);
    expect(spot.maximum.toString(), '99.000000000000000001');
    expect(spot.spotFree.toString(), '99.000000000000000001');
    expect(futures.maximum.toString(), '19.999999999999999999');
    expect(futures.futuresWallet.toString(), '100.000000000000000001');
    expect(futures.maxInput.toString(), '19.99');
    expect(spot.validate('99.01'), 'internalTransferTooLarge');
    expect(spot.validate('99'), null);
  });
  test('exact Max floors every supported step, including whole units and tiny balances', () {
    for (final p in [0, 2, 7, 8]) {
      final a = InternalTransferAsset('BTC', p);
      final n = a.floor(Decimal.parse('123456789012345678.123456789123456789'));
      expect(n <= Decimal.parse('123456789012345678.123456789123456789'), true);
      expect(n.scale <= p, true);
      expect(n + a.step > Decimal.parse('123456789012345678.123456789123456789'), true);
    }
    expect(InternalTransferAsset('USDT', 2).floor(Decimal.parse('0.009')).toString(), '0');
  });
  for (final text in ['', '0', '-1', '+1', '1e2', '.1', '1.', ' 1', '1,000', 'NaN', '1.001']) {
    test('invalid/overprecision amount $text cannot submit', () {
      expect(transferContext(now: now).validate(text), isNotNull);
    });
  }
  test('trailing zero amount is the same exact value, not extra input precision', () {
    expect(transferContext(now: now).validate('1.0100'), null);
  });
  for (final permission in [false, null, 'true']) {
    test('explicit true permissions required; unknown/wrong $permission fails closed', () {
      final p = transferSpotPayload()..['canWithdraw'] = permission;
      if (permission is String) {
        expect(() => transferContext(now: now, spot: p), throwsFormatException);
      } else {
        expect(transferContext(now: now, spot: p).validate('1'), 'internalTransferPermission');
      }
    });
  }
  for (final missing in [true, false]) {
    test('missing ${missing ? 'cap' : 'asset'} never uses available/root balance', () {
      final p = transferFuturesPayload();
      if (missing) {
        (p['assets'] as List).first.remove('maxWithdrawAmount');
      } else {
        (p['assets'] as List).removeAt(0);
      }
      final c = transferContext(
        now: now,
        futures: p,
        direction: InternalTransferDirection.futuresToSpot,
      );
      expect(c.maximum, null);
      expect(c.validate('1'), 'internalTransferMaximumUnknown');
    });
  }
  test('unsupported asset and negative cap remain unavailable', () {
    expect(
      transferContext(now: now, asset: 'NOPE').validate('1'),
      'internalTransferAssetUnavailable',
    );
    final p = transferFuturesPayload();
    (p['assets'] as List).first['maxWithdrawAmount'] = '-1';
    expect(
      transferContext(
        now: now,
        futures: p,
        direction: InternalTransferDirection.futuresToSpot,
      ).maxInput,
      null,
    );
  });
  for (final payload in [
    null,
    <String, Object?>{},
    {'status': 'PENDING', 'tranId': 1},
    {'status': 'SUCCESS', 'tranId': '1'},
    {'status': 'SUCCESS', 'tranId': 0},
    {'status': 'SUCCESS', 'tranId': -1},
    {'status': 'SUCCESS', 'tranId': 1.1},
  ]) {
    test('nonterminal/malformed reply $payload is unknown', () {
      expect(() => mapInternalTransferReply(payload), throwsFormatException);
    });
  }
  test('reported transaction ID remains exact beyond JS safe int', () {
    expect(
      mapInternalTransferReply({'status': 'SUCCESS', 'tranId': 9007199254740993}).transactionId,
      '9007199254740993',
    );
  });
}
