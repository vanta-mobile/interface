import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/deposit_submission.dart';
import 'package:vanta/features/funding/domain/deposit_quote_validation.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/data/deposit_submission_codec.dart';

import '../../support/deposit_wallet.dart';
import '../../support/deposit_gas.dart';

void main() {
  test('manual minimum never replaces an advertised minimum or unknown value implicitly', () {
    final base = depositQuery(minimum: null), snapshot = depositSnapshot(query: base);
    DepositAmountCheck check(String? minimum, String amount) => checkDepositAmount(
      input: amount,
      query: DepositWalletQuery(
        market: base.market,
        asset: base.asset,
        verifiedMinimumDeposit: minimum == null ? null : Decimal.parse(minimum),
      ),
      snapshot: snapshot,
      stale: false,
    );
    expect(check(null, '1').errorKey, 'depositMinimumUnknown');
    expect(check('-1', '1').errorKey, 'depositMinimumUnknown');
    expect(check('0.25', '0.249999999999999999').errorKey, 'depositBelowMinimum');
    expect(check('0.25', '0.25').units, BigInt.parse('250000000000000000'));
    expect(check('0', '0.000000000000000001').units, BigInt.one);
    final advertised = depositQuery(minimum: '2');
    expect(
      checkDepositAmount(
        input: '1',
        query: DepositWalletQuery(
          market: advertised.market,
          asset: advertised.asset,
          verifiedMinimumDeposit: Decimal.zero,
        ),
        snapshot: depositSnapshot(query: advertised),
        stale: false,
      ).errorKey,
      'depositBelowMinimum',
    );
  });
  test(
    'recovery rejects malformed external minimum without interpreting exponents or negatives',
    () {
      final now = DateTime.utc(2026, 11, 4, 8), q = depositQuery();
      final quote = gasQuote(query: q, receivedAt: now);
      final record = DepositSubmissionRecord(
        query: q,
        kind: quote.transaction.kind,
        amountUnits: quote.transaction.amountUnits,
        transaction: validatedDepositQuote(
          quote: quote,
          address: quote.address,
          query: q,
          amount: '1',
          now: now,
        ),
        preparedAt: now,
        baseBlock: quote.wallet.blockNumber,
        baseBlockHash: quote.wallet.blockHash,
      );
      for (final value in ['-1', '1e999999', 'NaN', '01', '0x1', true, 0.1]) {
        final terms = encodeSubmissionRecord(record)..['verifiedMinimum'] = value;
        expect(
          () => decodeSubmissionJournal(
            jsonEncode({
              'version': 1,
              'records': [terms],
            }),
          ),
          throwsFormatException,
        );
      }
    },
  );
  for (final chain in [1, 56, 42161]) {
    for (final native in [false, true]) {
      for (final market in TransferMarket.values) {
        test(
          'deposit record native=$native chain=$chain $market restores exact intent and market flag',
          () {
            final now = DateTime.utc(2026, 11, 4, 8),
                q = depositQuery(native: native, chain: chain, market: market);
            final quote = gasQuote(query: q, receivedAt: now);
            final record = DepositSubmissionRecord(
              query: q,
              kind: quote.transaction.kind,
              amountUnits: quote.transaction.amountUnits,
              transaction: validatedDepositQuote(
                quote: quote,
                address: quote.address,
                query: q,
                amount: '1',
                now: now,
              ),
              preparedAt: now,
              baseBlock: quote.wallet.blockNumber,
              baseBlockHash: quote.wallet.blockHash,
            );
            final recovered = decodeSubmissionJournal(encodeSubmissionJournal([record])).single;
            expect(recovered.transaction.parameters, record.transaction.parameters);
            expect(recovered.query.market, market);
            expect(recovered.query.asset.isNative, native);
            expect(recovered.transaction.value, native ? record.amountUnits : BigInt.zero);
          },
        );
      }
    }
  }
}
