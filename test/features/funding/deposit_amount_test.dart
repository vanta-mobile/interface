import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/funding_catalog_mapper.dart';
import 'package:vanta/features/funding/data/funding_json.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

import '../../support/deposit_wallet.dart';
import '../../support/funding_info.dart';

void main() {
  const catalogQuery = FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit);
  final query = depositQuery(), snapshot = depositSnapshot(query: depositQuery());
  DepositAmountCheck check(String input) =>
      checkDepositAmount(input: input, query: query, snapshot: snapshot, stale: false);
  test('amount uses exact smallest units and token allowance boundary', () {
    expect(check(' 1.230000000000000001 ').units.toString(), '1230000000000000001');
    expect(check('2').allowanceSufficient, true);
    expect(check('2.000000000000000001').allowanceSufficient, false);
    expect(check('123.456789012345678901').units, snapshot.assetUnits);
    expect(check('123.456789012345678902').errorKey, 'depositBalanceInsufficient');
    expect(depositQuantity(BigInt.one, 18), Decimal.parse('0.000000000000000001'));
  });
  for (final input in [
    '0',
    '-1',
    'NaN',
    'Infinity',
    '1e2',
    '1.',
    '+1',
    '.1',
    '1,000',
    '1 2',
    '1' * 161,
  ]) {
    test('invalid amount $input cannot pass precheck', () {
      expect(check(input).errorKey, 'depositAmountInvalid');
      expect(check(input).units, null);
    });
  }
  test('empty input is untouched and too many fractional digits are rejected', () {
    expect(check('').errorKey, null);
    expect(check('').units, null);
    expect(check('1.0000000000000000001').errorKey, 'depositAmountPrecision');
    expect(check('0.099999999999999999').errorKey, 'depositBelowMinimum');
    expect(check('0.1').errorKey, null);
  });
  test('missing minimum, absent/wrong/stale wallet cannot qualify amount', () {
    expect(
      checkDepositAmount(
        input: '1',
        query: depositQuery(minimum: null),
        snapshot: snapshot,
        stale: false,
      ).errorKey,
      'depositMinimumUnknown',
    );
    expect(
      checkDepositAmount(input: '1', query: query, snapshot: null, stale: false).errorKey,
      'depositReadRequired',
    );
    expect(
      checkDepositAmount(
        input: '1',
        query: query,
        snapshot: depositSnapshot(query: depositQuery(chain: 1)),
        stale: false,
      ).errorKey,
      'depositReadRequired',
    );
    expect(
      checkDepositAmount(input: '1', query: query, snapshot: snapshot, stale: true).errorKey,
      'depositReadStale',
    );
  });
  test('native amount has no fabricated ERC20 allowance; uint256 overflow rejected', () {
    final native = depositQuery(native: true);
    expect(
      checkDepositAmount(
        input: '1',
        query: native,
        snapshot: depositSnapshot(query: native),
        stale: false,
      ).allowanceSufficient,
      null,
    );
    expect(check((BigInt.one << 256).toString()).errorKey, 'depositAmountInvalid');
  });
  test('zero-decimal tokens preserve large integer amounts', () {
    final zero = depositQuery(decimals: 0, minimum: '0');
    final units = BigInt.parse('9007199254740993123456789');
    expect(
      checkDepositAmount(
        input: units.toString(),
        query: zero,
        snapshot: depositSnapshot(query: zero, assetUnits: units),
        stale: false,
      ).units,
      units,
    );
    expect(
      checkDepositAmount(
        input: '1.0',
        query: zero,
        snapshot: depositSnapshot(query: zero),
        stale: false,
      ).errorKey,
      'depositAmountPrecision',
    );
  });
  test('invalid model precision cannot allocate an unbounded decimal exponent', () {
    expect(
      checkDepositAmount(
        input: '1',
        query: depositQuery(decimals: 1000000),
        snapshot: null,
        stale: false,
      ).errorKey,
      'depositAmountPrecision',
    );
  });
  test('query identity includes token metadata, minimum and market', () {
    expect(depositQuery(), depositQuery());
    expect(depositQuery().hashCode, depositQuery().hashCode);
    expect(depositQuery(), isNot(depositQuery(decimals: 6)));
    expect(depositQuery(), isNot(depositQuery(minimum: '0.2')));
    expect(depositQuery(), isNot(depositQuery(market: TransferMarket.spot)));
  });
  for (final raw in [
    '0',
    '1e-18',
    '0.123456789012345678901234567890123456789',
    '"0.100000000000000001"',
  ]) {
    test('catalog minimum $raw decoded without floating point', () {
      final source = jsonEncode(fundingCatalogPayload([fundingAssetRow()..['minDeposit'] = '0']))
          .replaceFirst('"minDeposit":"0"', '"minDeposit":$raw');
      final catalog = mapFundingCatalog(
        decodeFundingCatalogJson(source),
        query: catalogQuery,
        receivedAt: DateTime.now(),
      );
      expect(catalog.assets.single.minimumDeposit, Decimal.parse(raw.replaceAll('"', '')));
    });
  }
  for (final field in [
    ('minDeposit', -1),
    ('minDeposit', 0.1),
    ('minDeposit', true),
    ('minDeposit', '1e99999'),
  ]) {
    test('catalog rejects invalid direct ${field.$1} ${field.$2}', () {
      expect(
        () => mapFundingCatalog(
          fundingCatalogPayload([fundingAssetRow()..[field.$1] = field.$2]),
          query: catalogQuery,
          receivedAt: DateTime.now(),
        ),
        throwsFormatException,
      );
    });
  }
  test('catalog decoder preserves numeric metadata types and unknown minimum', () {
    final row = fundingAssetRow()..['chainId'] = '56';
    expect(
      () => mapFundingCatalog(
        decodeFundingCatalogJson(jsonEncode(fundingCatalogPayload([row]))),
        query: catalogQuery,
        receivedAt: DateTime.now(),
      ),
      throwsFormatException,
    );
    expect(
      mapFundingCatalog(
        decodeFundingCatalogJson(jsonEncode(fundingCatalogPayload())),
        query: catalogQuery,
        receivedAt: DateTime.now(),
      ).assets.first.minimumDeposit,
      null,
    );
  });
  for (final source in [
    '{"a":0,"a":1}',
    '[${'[' * 33}0${']' * 33}]',
    '{"a":1,}',
    '[1,]',
    '{1:0}',
    'true false',
  ]) {
    test('lossless funding JSON rejects ambiguity/depth/syntax $source', () {
      expect(() => decodeFundingJson(source), throwsFormatException);
    });
  }
}
