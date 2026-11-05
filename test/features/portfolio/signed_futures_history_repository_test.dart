import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_futures_history_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';

import '../../support/aster_account.dart';
import '../../support/futures_history.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  late List<http.Request> requests;
  late List<Map<String, Object?>> signatures;
  late AsterAccountService service;
  late SignedFuturesHistoryRepository repository;
  late bool current, refused, changed, metadataFailed, inactive;
  Object? payload;
  late int status;
  setUp(() {
    requests = [];
    signatures = [];
    current = true;
    refused = changed = metadataFailed = false;
    payload = null;
    status = 200;
    inactive = false;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.followRedirects, false);
        if (request.url.path.endsWith('/time')) {
          return http.Response(
            jsonEncode({'serverTime': futuresHistoryNow.millisecondsSinceEpoch}),
            200,
          );
        }
        if (request.url.path.endsWith('/exchangeInfo')) {
          final metadata = liveExchangePayload();
          if (inactive) {
            (metadata['symbols'] as List).cast<Map<String, dynamic>>().first['status'] = 'CLOSE';
          }
          return http.Response(jsonEncode(metadataFailed ? {} : metadata), 200);
        }
        final row = switch (request.url.path) {
          '/fapi/v3/allOrders' => futuresOrderRow(),
          '/fapi/v3/userTrades' => futuresTradeRow(),
          '/fapi/v3/income' => futuresIncomeRow(),
          _ => throw StateError('Unexpected path'),
        };
        if (request.url.queryParameters['incomeType'] case final type?) row['incomeType'] = type;
        return http.Response(jsonEncode(payload ?? [row]), status);
      }),
    );
    repository = SignedFuturesHistoryRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        signatures.add(typedData);
        if (refused) throw const AuthFailure('authWalletRejected');
        if (changed) current = false;
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => futuresHistoryNow,
    );
  });
  tearDown(() => service.close());
  Future<FuturesHistoryPage> read(FuturesHistoryQuery query) => repository.read(
    address: accountAddress,
    query: query,
    isCurrent: () => current,
    onStep: (_) {},
  );
  Matcher failure(String key) => isA<AccountReadFailure>().having((e) => e.key, 'safe key', key);
  test('all three histories sign exact EOA query bytes, documented fields and increasing shared microsecond nonces', () async {
    for (final kind in FuturesHistoryKind.values) {
      final page = await read(
        futuresQuery(
          kind,
          symbol: 'BTCUSDT',
          incomeType: kind == FuturesHistoryKind.income ? 'COMMISSION' : '',
        ),
      );
      expect(page.records, hasLength(1));
      expect(page.receivedAt, futuresHistoryNow);
    }
    final private = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
    expect(private.map((r) => r.url.path), [
      '/fapi/v3/allOrders',
      '/fapi/v3/userTrades',
      '/fapi/v3/income',
    ]);
    for (var i = 0; i < 3; i++) {
      final params = private[i].url.queryParameters;
      expect(params.keys.toSet(), {
        'symbol',
        if (i == 2) 'incomeType',
        'startTime',
        'endTime',
        'limit',
        'nonce',
        'user',
        'signer',
        'signature',
      });
      expect(params['user'], accountAddress);
      expect(params['signer'], accountAddress);
      expect(params['nonce'], '${futuresHistoryNow.millisecondsSinceEpoch * 1000 + i}');
      expect(params['startTime'], '${futuresHistoryWindow.start}');
      expect(params['endTime'], '${futuresHistoryWindow.end}');
      expect(params['limit'], '1000');
      expect((signatures[i]['domain'] as Map)['chainId'], 1666);
      expect(
        (signatures[i]['message'] as Map)['msg'],
        private[i].url.query.split('&signature=').first,
      );
    }
    expect(requests.where((r) => r.url.path.endsWith('exchangeInfo')), hasLength(2));
  });
  for (final kind in [FuturesHistoryKind.orders, FuturesHistoryKind.income]) {
    test('optional symbol omitted for all-symbol $kind', () async {
      await read(futuresQuery(kind));
      final request = requests.singleWhere((r) => r.url.queryParameters.containsKey('signature'));
      expect(request.url.queryParameters.containsKey('symbol'), false);
    });
  }
  for (final q in [
    futuresQuery(FuturesHistoryKind.trades),
    futuresQuery(FuturesHistoryKind.orders, symbol: 'BTC&user=x'),
    futuresQuery(FuturesHistoryKind.income, incomeType: 'SECRET'),
    futuresQuery(FuturesHistoryKind.orders, incomeType: 'COMMISSION'),
    futuresQuery(
      FuturesHistoryKind.orders,
      window: const HistoryWindow(0, 7 * 24 * 60 * 60 * 1000),
    ),
  ]) {
    test(
      'invalid query never asks wallet or contacts any endpoint: ${q.kind}/${q.symbol}/${q.incomeType}/${q.window.end}',
      () async {
        await expectLater(read(q), throwsA(isA<AccountReadFailure>()));
        expect(signatures, isEmpty);
        expect(requests, isEmpty);
      },
    );
  }
  for (final kind in [FuturesHistoryKind.orders, FuturesHistoryKind.trades]) {
    test('metadata failure keeps exact signed amounts and unknown units $kind', () async {
      metadataFailed = true;
      final page = await read(futuresQuery(kind, symbol: 'BTCUSDT'));
      expect(page.unitsUnavailable, true);
      expect(page.records, hasLength(1));
      expect(signatures, hasLength(1));
    });
  }
  test('refused signature makes no private request and no retry', () async {
    refused = true;
    await expectLater(
      read(futuresQuery(FuturesHistoryKind.orders)),
      throwsA(failure('authWalletRejected')),
    );
    expect(signatures, hasLength(1));
    expect(requests, hasLength(1));
  });
  test('identity changes after wallet signature stop private dispatch', () async {
    changed = true;
    await expectLater(
      read(futuresQuery(FuturesHistoryKind.orders)),
      throwsA(failure('authWalletChanged')),
    );
    expect(requests, hasLength(1));
  });
  for (final kind in FuturesHistoryKind.values) {
    test('malformed private response surfaces safe failure without raw text $kind', () async {
      payload = {'message': 'private payload must not be rendered'};
      await expectLater(
        read(futuresQuery(kind, symbol: kind == FuturesHistoryKind.trades ? 'BTCUSDT' : '')),
        throwsA(failure('accountDataInvalid')),
      );
      expect(signatures, hasLength(1));
    });
  }
  test('exchange rejection preserves safe code and never calls write endpoint', () async {
    status = 400;
    payload = {'code': -2015, 'msg': 'untrusted sensitive text'};
    await expectLater(
      read(futuresQuery(FuturesHistoryKind.orders)),
      throwsA(isA<AccountReadFailure>().having((e) => e.code, 'code', -2015)),
    );
    expect(requests.where((r) => r.url.path.endsWith('allOrders')), hasLength(1));
  });
  test('inactive contracts still supply original symbol units', () async {
    inactive = true;
    final page = await read(futuresQuery(FuturesHistoryKind.trades, symbol: 'BTCUSDT'));
    expect((page.records.single as FuturesTradeRecord).units!.base, 'BTC');
  });
}
