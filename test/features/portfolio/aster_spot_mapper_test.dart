import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_spot_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';

import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';

void main() {
  AsterSpotAccount parse(Object? payload) =>
      mapAsterSpotAccount(payload, address: accountAddress, receivedAt: DateTime.utc(2026));

  test('preserves Decimal units, includes locked-only assets and returns immutable balances', () {
    final account = parse(spotPayload());
    expect(account.balances.first.total.toString(), '0.010000000000000001');
    expect(account.balances.first.free.toString(), '0.000000000000000001');
    expect(account.balances[1].total.toString(), '100.000000000000000001');
    expect(account.balances.last.total.toString(), '2');
    expect(() => account.balances.clear(), throwsUnsupportedError);
  });

  test('empty is valid but absent, null or malformed balance arrays are not', () {
    expect(parse({'balances': <Object?>[]}).balances, isEmpty);
    for (final value in [
      null,
      <String, Object?>{},
      {'balances': null},
      {'balances': <String, Object?>{}},
      {
        'balances': [null],
      },
    ]) {
      expect(() => parse(value), throwsFormatException);
    }
  });

  test(
    'rejects missing, negative, floating, scientific and excessive money without hiding rows',
    () {
      for (final amount in [null, '-1', 1.2, '1e-18', 'NaN', ' 1', '', '1' * 161]) {
        for (final key in ['free', 'locked']) {
          final row = <String, Object?>{'asset': 'BTC', 'free': '1', 'locked': '0', key: amount};
          expect(
            () => parse({
              'balances': [row],
            }),
            throwsFormatException,
            reason: '$key: $amount',
          );
        }
      }
    },
  );

  test(
    'accepts integer amounts and Unicode identifiers, rejects duplicate and unsafe identifiers',
    () {
      Map<String, Object?> row(Object? asset) => {'asset': asset, 'free': 0, 'locked': 2};
      expect(
        parse({
          'balances': [row('币安人生')],
        }).balances.single.asset,
        '币安人生',
      );
      for (final value in [null, '', 'BTC\n', 'BTC USDT', '<BTC>', 'B' * 51]) {
        expect(
          () => parse({
            'balances': [row(value)],
          }),
          throwsFormatException,
        );
      }
      expect(
        () => parse({
          'balances': [row('BTC'), row('BTC')],
        }),
        throwsFormatException,
      );
    },
  );
}
