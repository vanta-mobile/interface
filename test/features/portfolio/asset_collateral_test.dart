import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/asset_index_repository.dart';
import 'package:vanta/features/portfolio/domain/account_event_reconciliation.dart';
import 'package:vanta/features/portfolio/domain/account_update_book.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_collateral.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 13);
  Map<String, Object?> index({String bid = '0.9', String ask = '1.1'}) => {
    'symbol': 'USDTUSD',
    'index': '1.00000001',
    'bidRate': bid,
    'askRate': ask,
    'time': now.millisecondsSinceEpoch,
  };
  AssetIndexState prices({
    Map<String, Object?>? row,
    DateTime? checkedAt,
    bool active = true,
    bool failed = false,
  }) => AssetIndexState(
    checkedAt: checkedAt ?? now,
    active: active,
    failed: failed,
    snapshot: mapAssetIndices([row ?? index()], receivedAt: now),
  );
  AsterAssetBalance asset({
    String? wallet = '100',
    String? pnl = '2',
    bool? eligible = true,
    String total = '999',
    String totalPnl = '888',
    DateTime? eventTime,
  }) => AsterAssetBalance(
    asset: 'USDT',
    walletBalance: Decimal.parse(total),
    unrealizedProfit: Decimal.parse(totalPnl),
    availableBalance: Decimal.parse('555'),
    crossWalletBalance: wallet == null ? null : Decimal.parse(wallet),
    crossUnrealizedProfit: pnl == null ? null : Decimal.parse(pnl),
    marginAvailable: eligible,
    eventTime: eventTime,
  );
  AssetCollateralValue contribution({
    AsterAssetBalance? balance,
    AssetIndexState? rates,
    DateTime? accountTime,
    bool stale = false,
    bool events = false,
  }) => AssetCollateralValue(
    asset: balance ?? asset(),
    prices: rates ?? prices(),
    accountReceivedAt: accountTime ?? now,
    accountStale: stale,
    hasAccountEvents: events,
  );

  test(
    'positive crossed equity uses lower USD rate and excludes isolated/total/available balances',
    () {
      final value = contribution();
      expect(value.equity, Decimal.fromInt(102));
      expect(value.usd, Decimal.parse('91.8'));
      expect(value.fresh, true);
      expect(value.issue, null);
    },
  );
  test('negative equity uses ask rate through minimum of products, not minimum of rates', () {
    final value = contribution(
      balance: asset(wallet: '-100', pnl: '-2'),
    );
    expect(value.equity, Decimal.fromInt(-102));
    expect(value.usd, Decimal.parse('-112.2'));
  });
  test('cross profit can reverse wallet sign without clamping at zero', () {
    expect(
      contribution(
        balance: asset(wallet: '2', pnl: '-5'),
      ).usd,
      Decimal.parse('-3.3'),
    );
    expect(
      contribution(
        balance: asset(wallet: '-2', pnl: '5'),
      ).usd,
      Decimal.parse('2.7'),
    );
  });
  test('tiny high-precision quantities and rates are never rounded to double', () {
    final value = contribution(
      balance: asset(wallet: '0.000000000000000001', pnl: '0.000000000000000001'),
      rates: prices(
        row: index(bid: '0.900000000000000001', ask: '1.100000000000000001'),
      ),
    );
    expect(value.usd, Decimal.parse('0.000000000000000001800000000000000002'));
  });
  test('explicit zero equity or zero bid rates are preserved, missing rates never become zero', () {
    expect(
      contribution(
        balance: asset(wallet: '2', pnl: '-2'),
      ).usd,
      Decimal.zero,
    );
    expect(
      contribution(
        rates: prices(row: index(bid: '0')),
      ).usd,
      Decimal.zero,
    );
    final row = index()..remove('bidRate');
    expect(
      contribution(
        balance: asset(wallet: '0', pnl: '0'),
        rates: prices(row: row),
      ).usd,
      null,
    );
  });
  for (final missing in ['wallet', 'pnl', 'both']) {
    test('missing $missing never substitutes totals or zero', () {
      final value = contribution(
        balance: asset(
          wallet: missing == 'pnl' ? '100' : null,
          pnl: missing == 'wallet' ? '2' : null,
        ),
      );
      expect(value.usd, null);
      expect(value.issue, AssetCollateralIssue.equityUnknown);
    });
  }
  for (final eligible in [false, null]) {
    test('eligibility $eligible never implies contribution zero or active multi-asset mode', () {
      final value = contribution(balance: asset(eligible: eligible));
      expect(value.usd, null);
      expect(
        value.issue,
        eligible == null
            ? AssetCollateralIssue.eligibilityUnknown
            : AssetCollateralIssue.ineligible,
      );
    });
  }
  test('account or balance events block mixed old cross pnl and new snapshot', () {
    expect(contribution(events: true).issue, AssetCollateralIssue.events);
    expect(contribution(balance: asset(eventTime: now)).issue, AssetCollateralIssue.events);
  });
  for (final spec in [(59, true), (60, false), (61, false), (-1, false)]) {
    test('account snapshot age ${spec.$1}s has freshness ${spec.$2}', () {
      final value = contribution(accountTime: now.subtract(Duration(seconds: spec.$1)));
      expect(value.fresh, spec.$2);
      expect(value.usd, Decimal.parse('91.8'));
    });
  }
  test('account stale, paused/failed rates, expired rate snapshot stay visibly historical', () {
    expect(contribution(stale: true).fresh, false);
    expect(contribution(rates: prices(active: false)).fresh, false);
    expect(contribution(rates: prices(failed: true)).fresh, false);
    expect(
      contribution(rates: prices(checkedAt: now.add(const Duration(seconds: 60)))).fresh,
      false,
    );
    final row = index()
      ..['time'] = now.subtract(const Duration(seconds: 90)).millisecondsSinceEpoch;
    expect(contribution(rates: prices(row: row)).fresh, false);
  });
  test('missing asset index and rates never use the reference index as collateral rate', () {
    final row = index()
      ..remove('bidRate')
      ..remove('askRate');
    final mapped = prices(row: row);
    expect(mapped.snapshot!.forAsset('USDT')!.usd, Decimal.parse('1.00000001'));
    expect(contribution(rates: mapped).issue, AssetCollateralIssue.ratesUnknown);
    expect(contribution(rates: AssetIndexState(checkedAt: now)).usd, null);
  });
  for (final spec in <(String, Object?)>[
    ('bidRate', null),
    ('askRate', null),
    ('bidRate', 1.0),
    ('askRate', true),
    ('bidRate', '-1'),
    ('askRate', 'NaN'),
    ('bidRate', '1e-3'),
    ('askRate', '1' * 161),
    ('bidRate', '2'),
    ('askRate', '0.1'),
  ]) {
    test(
      'invalid optional ${spec.$1} ${spec.$2} leaves USD index usable and contribution unknown',
      () {
        final mapped = mapAssetIndices([
          index()..[spec.$1] = spec.$2,
        ], receivedAt: now).forAsset('USDT')!;
        expect(mapped.usd, Decimal.parse('1.00000001'));
        expect(mapped.bidRate, null);
        expect(mapped.askRate, null);
        expect(contribution(rates: prices(row: index()..[spec.$1] = spec.$2)).usd, null);
      },
    );
  }
  test('account mapping preserves exact crossed PnL independently of total PnL', () {
    final payload = accountPayload()
      ..['assets'] = [
        {
          'asset': 'USDT',
          'walletBalance': '1000',
          'crossWalletBalance': '100',
          'unrealizedProfit': '500',
          'crossUnPnl': '-0.000000000000000001',
          'marginAvailable': true,
        },
      ];
    final mapped = mapAsterAccount(payload, address: accountAddress, receivedAt: now).assets.single;
    expect(mapped.crossUnrealizedProfit, Decimal.parse('-0.000000000000000001'));
    expect(mapped.unrealizedProfit, Decimal.fromInt(500));
  });
  for (final value in ['NaN', '1e3', 0.1, true, '1' * 161]) {
    test('malformed signed crossUnPnl $value rejects snapshot', () {
      final payload = accountPayload()
        ..['assets'] = [
          {'asset': 'USDT', 'walletBalance': '1', 'crossUnPnl': value},
        ];
      expect(
        () => mapAsterAccount(payload, address: accountAddress, receivedAt: now),
        throwsFormatException,
      );
    });
  }
  test('missing signed cross pnl remains unknown and zero remains exact', () {
    for (final pnl in [null, '0']) {
      final payload = accountPayload()
        ..['assets'] = [
          {'asset': 'USDT', 'walletBalance': '1', 'crossUnPnl': pnl},
        ];
      expect(
        mapAsterAccount(
          payload,
          address: accountAddress,
          receivedAt: now,
        ).assets.single.crossUnrealizedProfit,
        pnl == null ? null : Decimal.zero,
      );
    }
  });
  test('balance events discard unavailable signed cross pnl and eligibility instead of carrying old values', () {
    final payload = accountPayload()
      ..['assets'] = [
        {
          'asset': 'USDT',
          'walletBalance': '1',
          'crossWalletBalance': '1',
          'crossUnPnl': '0',
          'marginAvailable': true,
        },
      ];
    final original = mapAsterAccount(payload, address: accountAddress, receivedAt: now);
    final updated = reconcileAccountUpdates(
      original,
      AccountUpdateBook()..add(accountUpdate()),
      since: 0,
    );
    final row = updated.assets.firstWhere((a) => a.asset == 'USDT');
    expect(row.crossUnrealizedProfit, null);
    expect(row.marginAvailable, null);
    expect(updated.lastEventAt, isNotNull);
  });
  test(
    'position-only events invalidate contribution even if no matching asset balance patch exists',
    () {
      final payload = accountPayload()
        ..['assets'] = [
          {
            'asset': 'USDT',
            'walletBalance': '100',
            'crossWalletBalance': '100',
            'crossUnPnl': '2',
            'marginAvailable': true,
          },
        ];
      final original = mapAsterAccount(payload, address: accountAddress, receivedAt: now);
      final updated = reconcileAccountUpdates(
        original,
        AccountUpdateBook()..add(accountUpdate(balances: [])),
        since: 0,
      );
      expect(
        contribution(balance: updated.assets.single, events: updated.lastEventAt != null).usd,
        null,
      );
    },
  );
}
