import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/funding_catalog_mapper.dart';
import 'package:vanta/features/funding/data/withdraw_info_mapper.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

import '../../support/aster_account.dart';
import '../../support/funding_info.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  const query = FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit);
  test('catalog retains chain-scoped immutable tokens, decimals and native identity', () {
    final rows = [
      fundingAssetRow(),
      fundingAssetRow(chain: 1),
      fundingAssetRow(asset: 'BNB', native: true),
    ];
    final catalog = mapFundingCatalog(fundingCatalogPayload(rows), query: query, receivedAt: now);
    expect(catalog.query, query);
    expect(catalog.receivedAt, now);
    expect(catalog.assets.length, 3);
    expect(catalog.assets.last.isNative, true);
    expect(catalog.assets.last.tokenAddress, fundingNativePlaceholder);
    rows.first['decimals'] = 6;
    expect(catalog.assets.first.decimals, 18);
    expect(() => catalog.assets.clear(), throwsUnsupportedError);
    expect(
      mapFundingCatalog(fundingCatalogPayload([]), query: query, receivedAt: now).assets,
      isEmpty,
    );
  });
  for (final field in <(String, Object?)>[
    ('name', ''),
    ('network', 'SOLANA'),
    ('chainId', 999),
    ('chainId', '56'),
    ('decimals', 1.5),
    ('decimals', 256),
    ('decimals', -1),
    ('isNative', 1),
    ('isProfit', 'true'),
    ('contractAddress', 'invalid'),
    ('contractAddress', '0x0000000000000000000000000000000000000000'),
    ('contractAddress', fundingNativePlaceholder),
    ('isNative', true),
    ('depositType', ''),
    ('displayName', null),
  ]) {
    test('catalog rejects malformed or inconsistent ${field.$1} ${field.$2}', () {
      expect(
        () => mapFundingCatalog(
          fundingCatalogPayload([fundingAssetRow()..[field.$1] = field.$2]),
          query: query,
          receivedAt: now,
        ),
        throwsFormatException,
      );
    });
  }
  test('catalog rejects failed business envelopes, duplicates and resource overflow', () {
    for (final data in [
      null,
      <String, Object?>{},
      fundingCatalogPayload()..['code'] = '100001',
      fundingCatalogPayload()..['success'] = false,
      fundingCatalogPayload([fundingAssetRow(), fundingAssetRow()]),
      fundingCatalogPayload(List.filled(5001, fundingAssetRow())),
    ]) {
      expect(() => mapFundingCatalog(data, query: query, receivedAt: now), throwsFormatException);
    }
  });
  test('unknown funding route is retained, never remapped to normal or autoWithdraw', () {
    final row = fundingAssetRow()..['depositType'] = 'futureRoute';
    expect(
      mapFundingCatalog(
        fundingCatalogPayload([row]),
        query: query,
        receivedAt: now,
      ).assets.single.routeType,
      'futureRoute',
    );
  });
  test(
    'withdraw snapshot keeps coin quantities, chain fees and dollar limits separate and exact',
    () {
      final info = mapWithdrawInfo(withdrawInfoPayload(), address: accountAddress, receivedAt: now);
      final asset = info.assets['USDT']!, chain = asset.chains[56]!;
      expect(info.userDailyLimitUsd, Decimal.fromInt(10000));
      expect(info.userRemainingDailyLimitUsd, Decimal.fromInt(9000));
      expect(info.totalRemainingDailyLimitUsd, Decimal.fromInt(980000));
      expect(asset.dailyLimitUsd, Decimal.fromInt(9000));
      expect(asset.total(TransferMarket.spot), Decimal.parse('12.300000000000000001'));
      expect(asset.total(TransferMarket.perp), Decimal.parse('23.400000000000000002'));
      expect(chain.maximum(TransferMarket.spot), Decimal.parse('1.230000000000000001'));
      expect(chain.maximum(TransferMarket.perp), Decimal.parse('2.340000000000000002'));
      expect(chain.chainLimit, Decimal.parse('3.450000000000000003'));
      expect(chain.fee, Decimal.parse('0.000000000000000001'));
      expect(() => info.assets.clear(), throwsUnsupportedError);
      expect(() => asset.chains.clear(), throwsUnsupportedError);
    },
  );
  test('empty balances and absent optional fields remain unknown, not zero', () {
    final info = mapWithdrawInfo(
      {'balances': <String, Object?>{}},
      address: accountAddress,
      receivedAt: now,
    );
    expect(info.assets, isEmpty);
    expect(info.userDailyLimitUsd, null);
    final balance = withdrawBalanceRow()..remove('perpTotalWithdrawAmount');
    final chain = withdrawChainRow()
      ..remove('perpMaxWithdrawAmount')
      ..['withdrawFee'] = '0';
    balance['chainBalances'] = {'56': chain};
    final partial = mapWithdrawInfo(
      {
        'balances': {'USDT': balance},
      },
      address: accountAddress,
      receivedAt: now,
    ).assets['USDT']!;
    expect(partial.perpTotalAmount, null);
    expect(partial.chains[56]!.perpMaxAmount, null);
    expect(partial.chains[56]!.fee, Decimal.zero);
  });
  test('reported negative balance is retained without manufacturing an allowance', () {
    final balance = withdrawBalanceRow()..['perpTotalWithdrawAmount'] = '-0.000000000000000001';
    final info = mapWithdrawInfo(
      {
        'balances': {'USDT': balance},
      },
      address: accountAddress,
      receivedAt: now,
    );
    expect(info.assets['USDT']!.perpTotalAmount, Decimal.parse('-0.000000000000000001'));
  });
  for (final value in <Object?>[1.5, 'NaN', '1' * 161, true]) {
    test(
      'withdraw totals that are not exact decimals stay unknown: ${value.toString().length}',
      () {
        final info = mapWithdrawInfo(
          withdrawInfoPayload()..['userDailyLimit'] = value,
          address: accountAddress,
          receivedAt: now,
        );
        expect(info.userDailyLimitUsd, isNull);
        expect(info.assets['USDT']!.chains[56]!.perpMaxAmount, isNotNull);
      },
    );
  }
  test('withdraw info keeps exact JSON numbers, exponents and string chain IDs', () {
    final payload = decodeWithdrawInfoJson('''{
      "userDailyLimit": 10000.000000000000000001,
      "balances": {"BNB": {
        "perpTotalWithdrawAmount": 1E-8,
        "chainBalances": {"56": {
          "chainId": "56", "perpMaxWithdrawAmount": 0.030355680000000001,
          "withdrawFee": "0E-8"}}}}
    }''');
    final info = mapWithdrawInfo(payload, address: accountAddress, receivedAt: now);
    expect(info.userDailyLimitUsd, Decimal.parse('10000.000000000000000001'));
    expect(info.assets['BNB']!.perpTotalAmount, Decimal.parse('0.00000001'));
    expect(info.assets['BNB']!.chains[56]!.perpMaxAmount, Decimal.parse('0.030355680000000001'));
    expect(info.assets['BNB']!.chains[56]!.fee, Decimal.zero);
  });
  test('whole-number amounts are exact', () {
    final info = mapWithdrawInfo(
      withdrawInfoPayload()..['userDailyLimit'] = 1000,
      address: accountAddress,
      receivedAt: now,
    );
    expect(info.userDailyLimitUsd, Decimal.fromInt(1000));
  });
  test('withdraw decoder keeps a numeric business code recognisable', () {
    expect(decodeWithdrawInfoJson('{"code":-2015,"msg":"x"}'), {'code': -2015, 'msg': 'x'});
    expect(
      mapWithdrawInfo({'balances': null}, address: accountAddress, receivedAt: now).assets,
      isEmpty,
    );
  });
  test('a malformed asset row is unknown without hiding other assets', () {
    final mismatchedAsset = withdrawBalanceRow()..['currency'] = 'BNB';
    final mismatchedChain = withdrawBalanceRow()..['chainBalances'] = {'1': withdrawChainRow()};
    final negativeFee = withdrawBalanceRow()
      ..['chainBalances'] = {'56': withdrawChainRow()..['withdrawFee'] = '-1'};
    for (final balance in [mismatchedAsset, mismatchedChain, negativeFee]) {
      final info = mapWithdrawInfo(
        {
          'balances': {'USDT': balance, 'ETH': withdrawBalanceRow()..['currency'] = 'ETH'},
        },
        address: accountAddress,
        receivedAt: now,
      );
      expect(info.assets.containsKey('USDT'), isFalse);
      expect(info.assets['ETH']!.chains[56]!.perpMaxAmount, isNotNull);
    }
    expect(
      () => mapWithdrawInfo(['not', 'an', 'object'], address: accountAddress, receivedAt: now),
      throwsFormatException,
    );
  });
}
