import 'package:decimal/decimal.dart';

import '../../../core/market_failure.dart';
import '../domain/market_precision.dart';
import 'aster_service.dart';
import 'market_descriptor_mapper.dart';

class MarketCatalogRepository {
  const MarketCatalogRepository(this.service);
  final AsterService service;
  Future<List<AsterInstrument>> read() async {
    final results = await Future.wait([
      service.request('/fapi/v3/exchangeInfo'),
      service.request('/fapi/v3/ticker/24hr'),
      service.request('/fapi/v3/time'),
      service.request('/fapi/v3/premiumIndex'),
    ]);
    try {
      final server = results[2];
      if (server is! Map || server['serverTime'] is! int || (server['serverTime'] as int) <= 0) {
        throw const MarketFailure('Invalid Aster server time');
      }
      service.calibrateClock(server['serverTime'] as int);
      final premiums = {
        for (final raw in results[3] as List<dynamic>)
          (raw as Map<String, dynamic>)['symbol'] as String: raw,
      };
      final info = results[0] as Map<String, dynamic>;
      final tickers = {
        for (final raw in results[1] as List<dynamic>)
          (raw as Map<String, dynamic>)['symbol'] as String: raw,
      };
      final instruments = <AsterInstrument>[];
      final seen = <String>{};
      for (final item in info['symbols'] as List<dynamic>) {
        final data = item as Map<String, dynamic>;
        final ticker = tickers[data['symbol']];
        if (data['status'] != 'TRADING' ||
            data['contractType'] != 'PERPETUAL' ||
            data['quoteAsset'] != 'USDT' ||
            ticker == null ||
            !seen.add(data['symbol'] as String)) {
          continue;
        }
        instruments.add(
          AsterInstrument(
            symbol: data['symbol'] as String,
            base: data['baseAsset'] as String,
            quote: data['quoteAsset'] as String,
            ticker: {...ticker, ...?premiums[data['symbol']]},
            precision: MarketPrecision.fromExchange(data),
            descriptor: mapMarketDescriptor(data),
          ),
        );
      }
      Decimal? volume(AsterInstrument instrument) {
        final value = Decimal.tryParse('${instrument.ticker['quoteVolume']}');
        return value != null && value >= Decimal.zero ? value : null;
      }

      instruments.sort((a, b) {
        final av = volume(a), bv = volume(b);
        final order = av == null
            ? (bv == null ? 0 : 1)
            : bv == null
            ? -1
            : bv.compareTo(av);
        return order == 0 ? a.symbol.compareTo(b.symbol) : order;
      });
      final first =
          instruments.where((e) => ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'].contains(e.symbol)).toList()
            ..sort(
              (a, b) => [
                'BTCUSDT',
                'ETHUSDT',
                'SOLUSDT',
              ].indexOf(a.symbol).compareTo(['BTCUSDT', 'ETHUSDT', 'SOLUSDT'].indexOf(b.symbol)),
            );
      return List.unmodifiable([...first, ...instruments.where((e) => !first.contains(e))]);
    } on MarketFailure {
      rethrow;
    } catch (_) {
      throw const MarketFailure('Invalid Aster instrument response');
    }
  }
}
