import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/funding_fee_repository.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/funding_fee.dart';

void main() {
  for (final market in TransferMarket.values) {
    for (final chain in [1, 56, 42161]) {
      test(
        'public fee GET carries exact $market / $chain query, no signature or redirects',
        () async {
          final query = FundingFeeQuery(market: market, chainId: chain, asset: 'USDT');
          final service = FundingFeeService(
            client: MockClient((request) async {
              expect(request.url.scheme, 'https');
              expect(request.url.host, 'www.asterdex.com');
              expect(
                request.url.path,
                '/bapi/futures/v1/public/future/aster/estimate-withdraw-fee',
              );
              expect(request.method, 'GET');
              expect(request.followRedirects, false);
              expect(request.url.queryParameters, {
                'chainId': '$chain',
                'network': 'EVM',
                'currency': 'USDT',
                'accountType': market.name,
              });
              expect(request.body, isEmpty);
              expect(
                request.headers.keys.any(
                  (key) =>
                      key.toLowerCase().contains('authorization') ||
                      key.toLowerCase().contains('api-key'),
                ),
                false,
              );
              return http.Response.bytes(utf8.encode(fundingFeePayload), 200);
            }),
          );
          addTearDown(service.close);
          final now = DateTime.utc(2026, 11, 3);
          final quote = await AsterFundingFeeRepository(service, now: () => now).read(query);
          expect(quote.query, query);
          expect(quote.receivedAt, now);
          expect(quote.assetFee.toString(), '0.123456789012345678901234567890123456789');
        },
      );
    }
  }
  for (final query in [
    const FundingFeeQuery(market: TransferMarket.perp, chainId: 999, asset: 'USDT'),
    const FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT&signature=bad'),
  ]) {
    test(
      'unsupported scope never sends network request: ${query.chainId}/${query.asset}',
      () async {
        var calls = 0;
        final service = FundingFeeService(
          client: MockClient((_) async {
            calls++;
            return http.Response(fundingFeePayload, 200);
          }),
        );
        addTearDown(service.close);
        await expectLater(
          AsterFundingFeeRepository(service).read(query),
          throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
        );
        expect(calls, 0);
      },
    );
  }
  for (final (status, body, key) in [
    (302, '{}', 'accountReadFailed'),
    (429, '{}', 'accountRateLimited'),
    (200, '{bad', 'accountDataInvalid'),
    (403, 'secret response', 'accountReadFailed'),
    (200, '{"code":-2015,"msg":"private server detail"}', 'accountPermissionRequired'),
  ]) {
    test('transport rejects $status safely as $key', () async {
      final service = FundingFeeService(
        client: MockClient((_) async => http.Response(body, status)),
      );
      addTearDown(service.close);
      await expectLater(
        AsterFundingFeeRepository(service).read(fundingFeeQuery),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key)),
      );
    });
  }
  test('business envelope failure is rejected even with HTTP 200', () async {
    final service = FundingFeeService(
      client: MockClient(
        (_) async => http.Response(
          '{"code":"100001","success":false,"message":"Fee unavailable","data":{}}',
          200,
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      AsterFundingFeeRepository(service).read(fundingFeeQuery),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.details?.message, 'reason', 'Fee unavailable'),
      ),
    );
  });
  test('timeout is safe and no response content is exposed', () async {
    final gate = Completer<http.Response>();
    final service = FundingFeeService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => gate.future),
    );
    addTearDown(service.close);
    await expectLater(
      AsterFundingFeeRepository(service).read(fundingFeeQuery),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountNetwork')),
    );
    gate.complete(http.Response(fundingFeePayload, 200));
  });
}
