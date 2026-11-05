import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/asset_index_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  Map<String, Object?> row() => {
    'symbol': 'USDTUSD',
    'index': '0.998360000000000000000001',
    'time': now.millisecondsSinceEpoch,
    'bidBuffer': 'irrelevant',
  };
  test('strict immutable index mapping preserves price and source timestamp', () {
    final mapped = mapAssetIndices([row()], receivedAt: now);
    expect(mapped.forAsset('USDT')!.usd, Decimal.parse('0.998360000000000000000001'));
    expect(mapped.forAsset('USDT')!.time, now);
    expect(mapped.forAsset('USDC'), null);
    expect(() => mapped.indices.clear(), throwsUnsupportedError);
    expect(mapAssetIndices([], receivedAt: now).indices, isEmpty);
  });
  for (final field in <(String, Object?)>[
    ('symbol', 'BTCUSDT'),
    ('symbol', 'USD'),
    ('symbol', 'USDT/USD'),
    ('index', 1.0),
    ('index', '0'),
    ('index', '-1'),
    ('index', '1e3'),
    ('index', 'NaN'),
    ('index', '1' * 161),
    ('index', null),
    ('time', 0),
    ('time', 1.5),
    ('time', '123'),
    ('time', 253402300800000),
  ]) {
    test('rejects invalid ${field.$1} ${field.$2}', () {
      expect(
        () => mapAssetIndices([row()..[field.$1] = field.$2], receivedAt: now),
        throwsFormatException,
      );
    });
  }
  test('rejects duplicate symbols, invalid envelope, entries and oversized response', () {
    for (final payload in [
      null,
      <String, Object?>{},
      [null],
      [row(), row()],
      List.filled(5001, row()),
    ]) {
      expect(() => mapAssetIndices(payload, receivedAt: now), throwsFormatException);
    }
  });
  test('repository uses one anonymous GET at the fixed public origin with no redirects', () async {
    var calls = 0;
    final service = AsterAccountService(
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://fapi.asterdex.com/fapi/v1/assetIndex');
        expect(request.headers.containsKey('authorization'), false);
        expect(request.body, isEmpty);
        expect(request.followRedirects, false);
        return http.Response(jsonEncode([row()]), 200);
      }),
    );
    addTearDown(service.close);
    final result = await AsterAssetIndexRepository(service, now: () => now).read();
    expect(calls, 1);
    expect(result.receivedAt, now);
    expect(result.indices.keys, ['USDTUSD']);
  });
  test('redirects and malformed successful JSON do not become prices', () async {
    for (final response in [http.Response('{}', 302), http.Response('not json', 200)]) {
      final service = AsterAccountService(client: MockClient((_) async => response));
      addTearDown(service.close);
      await expectLater(
        AsterAssetIndexRepository(service).read(),
        throwsA(isA<AccountReadFailure>()),
      );
    }
  });
}
