import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_catalog_repository.dart';

void main() {
  test('network errors retain their transport cause instead of becoming invalid data', () async {
    final client = MockClient((_) async => throw http.ClientException('connection unavailable'));
    final service = AsterService(client);
    addTearDown(() async {
      client.close();
      await service.dispose();
    });
    await expectLater(
      MarketCatalogRepository(service).read(),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('malformed catalog responses become a controlled domain failure', () async {
    final client = MockClient(
      (request) async =>
          http.Response(request.url.path.endsWith('/time') ? '{"serverTime":123}' : '[]', 200),
    );
    final service = AsterService(client);
    addTearDown(() async {
      client.close();
      await service.dispose();
    });
    await expectLater(MarketCatalogRepository(service).read(), throwsA(isA<MarketFailure>()));
  });

  test('instrument snapshots copy their input instead of retaining a mutable alias', () {
    final values = <String, Object?>{'lastPrice': '123'};
    final instrument = AsterInstrument(symbol: 'BTCUSDT', base: 'BTC', ticker: values);
    values['lastPrice'] = '999';
    expect(instrument.ticker['lastPrice'], '123');
    expect(() => instrument.ticker.clear(), throwsUnsupportedError);
  });
}
