import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/exact_json.dart';
import 'package:vanta/features/points/data/points_mapper.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/points.dart';
import '../../support/points_payloads.dart';

void main() {
  test('current campaign keeps source/broker/period and exact pool', () {
    final c = mapCurrentPointsCampaign({'campaign': cycle()})!;
    expect(c.number, 17);
    expect(c.pool.toString(), '1000000.000000000000000001');
    expect(c.start, DateTime.utc(2026, 10, 29));
    expect(c.end, DateTime.utc(2026, 11, 5));
    expect(c.broker, 'vanta_exchange');
    expect(c.current, true);
  });
  test('null current is explicit absence, missing current is invalid', () {
    expect(mapCurrentPointsCampaign({'campaign': null}), null);
    expect(() => mapCurrentPointsCampaign(<String, dynamic>{}), throwsFormatException);
    expect(
      () => mapCurrentPointsCampaign({'campaign': cycle(current: false)}),
      throwsFormatException,
    );
  });
  test('empty cycle list and source order are preserved and immutable', () {
    expect(mapPointsCampaigns({'items': <Object?>[]}), isEmpty);
    final c = mapPointsCampaigns({
      'items': [cycle(number: 2, current: false), cycle(number: 1)],
    });
    expect(c.map((e) => e.number), [2, 1]);
    expect(() => c.clear(), throwsUnsupportedError);
  });
  test('duplicate cycle IDs and multiple current cycles reject the whole collection', () {
    expect(
      () => mapPointsCampaigns({
        'items': [cycle(current: false), cycle()],
      }),
      throwsFormatException,
    );
    expect(
      () => mapPointsCampaigns({
        'items': [cycle(), cycle(number: 18)],
      }),
      throwsFormatException,
    );
  });
  for (final date in [
    '2026-02-30T00:00:00Z',
    '2026-10-29T24:00:00Z',
    '2026-10-29T00:60:00Z',
    '2026-10-29T00:00:60Z',
    '2026-10-29T00:00:00',
    '2026-10-29T00:00:00+99:00',
  ]) {
    test('invalid period timestamp $date', () {
      expect(
        () => mapCurrentPointsCampaign({'campaign': cycle()..['startTime'] = date}),
        throwsFormatException,
      );
    });
  }
  test('end must follow start; future unknown published status is preserved', () {
    expect(
      () => mapCurrentPointsCampaign({'campaign': cycle()..['endTime'] = '2026-10-01T00:00:00Z'}),
      throwsFormatException,
    );
    expect(
      mapCurrentPointsCampaign({'campaign': cycle()..['status'] = 'FUTURE_STATUS'})!.status,
      'FUTURE_STATUS',
    );
  });
  for (final amount in [null, 1.1, -1, '-1', 'NaN', 'Infinity', '1e3', '', '1' * 161]) {
    test('invalid cycle pool ($amount) is not coerced or defaulted', () {
      expect(
        () => mapCurrentPointsCampaign({'campaign': cycle()..['totalVantaPoints'] = amount}),
        throwsFormatException,
      );
    });
  }
  test('raw numeric JSON points and int64 cycle IDs never pass through double', () {
    final payload = decodeFundingJson(
      jsonEncode({'campaign': cycle()})
          .replaceFirst('"campaignNumber":17', '"campaignNumber":9223372036854775807')
          .replaceFirst('"1000000.000000000000000001"', '1000000.000000000000000001'),
    );
    final c = mapCurrentPointsCampaign(payload)!;
    expect(c.number, 9223372036854775807);
    expect(c.pool.toString(), '1000000.000000000000000001');
    expect(
      () => pointsPositiveInt(const FundingJsonNumber('9223372036854775808')),
      throwsFormatException,
    );
  });
  test('source leaderboard ranks/amounts/optional parts stay exact and immutable', () {
    final board = mapPointsLeaderboard({
      'items': [
        ranking(rank: 7),
        ranking(address: '0x2222222222222222222222222222222222222222', rank: 7),
      ],
    }, campaign: null);
    expect(board.rows.map((e) => e.rank), [7, 7]);
    expect(board.rows.first.points.toString(), '12.000000000000000001');
    expect(board.rows.first.current.toString(), '1.000000000000000001');
    expect(board.rankFor(pointsTestAddress), 7);
    expect(board.rankFor('0x3333333333333333333333333333333333333333'), null);
    expect(() => board.rows.clear(), throwsUnsupportedError);
  });
  test('per-cycle rows must match requested campaign and use points rather than total', () {
    expect(
      mapPointsLeaderboard({
        'items': [ranking(campaign: 1)..['totalPoint'] = '999'],
      }, campaign: 1).rows.first.points.toString(),
      '12.000000000000000001',
    );
    expect(
      () => mapPointsLeaderboard({
        'items': [ranking(campaign: 2)],
      }, campaign: 1),
      throwsFormatException,
    );
    expect(
      () => mapPointsLeaderboard({
        'items': [ranking()],
      }, campaign: 1),
      throwsFormatException,
    );
  });
  test(
    'rows above100 are not represented as a full leaderboard; duplicate validation includes tail',
    () {
      final rows = List.generate(
        101,
        (i) => ranking(address: '0x${(i + 1).toRadixString(16).padLeft(40, '0')}', rank: i + 1),
      );
      final board = mapPointsLeaderboard({'items': rows}, campaign: null);
      expect(board.rows.length, 100);
      expect(board.truncated, true);
      rows[100] = rows[0];
      expect(() => mapPointsLeaderboard({'items': rows}, campaign: null), throwsFormatException);
    },
  );
  test('EVM duplicate keys are case-insensitive; Solana base58 stays case-sensitive', () {
    const evm = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    expect(
      () => mapPointsLeaderboard({
        'items': [ranking(address: evm), ranking(address: '0x${'A' * 40}')],
      }, campaign: null),
      throwsFormatException,
    );
    final board = mapPointsLeaderboard({
      'items': [ranking(address: 'A' * 44), ranking(address: 'a' * 44)],
    }, campaign: null);
    expect(board.rows.length, 2);
    expect(pointsAddressKey('A' * 44), 'A' * 44);
  });
  for (final address in [
    '',
    'not-a-wallet',
    '0x1',
    '0x${'g' * 40}',
    '0x${'a' * 40}/../x',
    '1' * 129,
    '\u202e$pointsTestAddress',
  ]) {
    test('invalid financial address rejected ($address)', () {
      expect(
        () => mapPointsLeaderboard({
          'items': [ranking(address: address)],
        }, campaign: null),
        throwsFormatException,
      );
    });
  }
  for (final rank in [0, -1, 1.5, '1', null]) {
    test('invalid server rank is not replaced by local position ($rank)', () {
      expect(
        () => mapPointsLeaderboard({
          'items': [ranking()..['rank'] = rank],
        }, campaign: null),
        throwsFormatException,
      );
    });
  }
  test('only declared score is used; missing fields stay unknown or invalid', () {
    final row = ranking()..remove('currentPoint');
    expect(
      mapPointsLeaderboard({
        'items': [row],
      }, campaign: null).rows.first.current,
      null,
    );
    row.remove('totalPoint');
    expect(
      () => mapPointsLeaderboard({
        'items': [row],
      }, campaign: null),
      throwsFormatException,
    );
  });
  test('explicit wallet summary is bound to request; no returned identity substitution', () {
    final row = ranking();
    final wallet = mapWalletPoints(row, address: pointsTestAddress);
    expect(wallet.total.toString(), '12.000000000000000001');
    expect(wallet.address, pointsTestAddress);
    row['address'] = '0x2222222222222222222222222222222222222222';
    expect(() => mapWalletPoints(row, address: pointsTestAddress), throwsFormatException);
    row.remove('address');
    expect(mapWalletPoints(row, address: pointsTestAddress).address, pointsTestAddress);
  });
  test('unknown summary is never a zero wallet; explicit zero is valid', () {
    expect(
      () => mapWalletPoints(<String, dynamic>{}, address: pointsTestAddress),
      throwsFormatException,
    );
    expect(
      mapWalletPoints({'totalPoint': '0', 'currentPoint': '0'}, address: pointsTestAddress).total,
      Decimal.zero,
    );
  });
  test('history exact scores and campaign IDs retained; missing campaign not inserted as zero', () {
    final h = mapWalletPointsHistory({
      'items': [
        {'campaignNumber': 1, 'campaignName': 'Cycle 1', 'points': '123.000000000000000001'},
      ],
    }, address: pointsTestAddress);
    expect(h.rows.single.points.toString(), '123.000000000000000001');
    expect(h.rows.single.campaign, 1);
    expect(() => h.rows.clear(), throwsUnsupportedError);
    expect(
      mapWalletPointsHistory({'items': <Object?>[]}, address: pointsTestAddress).rows,
      isEmpty,
    );
  });
  test('duplicate or mismatched wallet history cannot cross scope', () {
    final row = {'campaignNumber': 1, 'points': '1'};
    expect(
      () => mapWalletPointsHistory({
        'items': [row, row],
      }, address: pointsTestAddress),
      throwsFormatException,
    );
    expect(
      () => mapWalletPointsHistory({
        'address': '0x2222222222222222222222222222222222222222',
        'items': [row],
      }, address: pointsTestAddress),
      throwsFormatException,
    );
    expect(
      () => mapWalletPointsHistory({
        'items': [
          {...row, 'address': '0x2222222222222222222222222222222222222222'},
        ],
      }, address: pointsTestAddress),
      throwsFormatException,
    );
  });
  test('missing / excessive lists and duplicate JSON keys are invalid', () {
    expect(() => mapPointsCampaigns({'items': List.filled(5001, cycle())}), throwsFormatException);
    expect(() => mapPointsLeaderboard(<String, dynamic>{}, campaign: null), throwsFormatException);
    expect(() => decodeFundingJson('{"totalPoint":1,"totalPoint":2}'), throwsFormatException);
  });
}
