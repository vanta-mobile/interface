import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:decimal/decimal.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/market_failure.dart';
import '../domain/market.dart';
import '../domain/market_descriptor.dart';
import 'aster_stream.dart';
import 'market_descriptor_mapper.dart';

class AsterInstrument {
  const AsterInstrument({
    required this.symbol,
    required this.base,
    required this.ticker,
    this.precision = const MarketPrecision(),
    this.descriptor = const MarketDescriptor.empty(),
  });
  final String symbol, base;
  final Map<String, Object?> ticker;
  final MarketPrecision precision;
  final MarketDescriptor descriptor;
}

class AsterService {
  AsterService(this.client, {WebSocketChannel Function(Uri)? connect})
    : _connect = connect ?? WebSocketChannel.connect;
  final http.Client client;
  final WebSocketChannel Function(Uri) _connect;
  static final _streamUri = Uri.parse('wss://fstream.asterdex.com/stream');
  int _serverOffset = 0;
  final _weights = <(int, int)>[];
  int _blockedUntil = 0;
  Future<void> _reserve(int weight) async {
    while (true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _weights.removeWhere((entry) => entry.$1 <= now - 60000);
      final used = _weights.fold(0, (sum, e) => sum + e.$2);
      if (now >= _blockedUntil && used + weight <= 1000) {
        _weights.add((now, weight));
        return;
      }
      final budgetWait = used + weight > 1000 ? _weights.first.$1 + 60001 - now : 0;
      final blockWait = _blockedUntil - now;
      await Future<void>.delayed(
        Duration(milliseconds: (budgetWait > blockWait ? budgetWait : blockWait).clamp(1, 60000)),
      );
    }
  }

  int get serverNow => DateTime.now().millisecondsSinceEpoch + _serverOffset;
  Future<Object?> request(String path, [Map<String, String>? query]) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final limit = int.tryParse(query?['limit'] ?? '') ?? 0;
      await _reserve(
        path.endsWith('/klines')
            ? (limit < 100
                  ? 1
                  : limit < 500
                  ? 2
                  : limit <= 1000
                  ? 5
                  : 10)
            : path.endsWith('/ticker/24hr') && query?['symbol'] == null
            ? 40
            : 1,
      );
      final response = await client
          .get(Uri.https('fapi.asterdex.com', path, query))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 429 || response.statusCode == 418) {
        final wait = (int.tryParse(response.headers['retry-after'] ?? '') ?? 5).clamp(1, 86400);
        _blockedUntil = DateTime.now().millisecondsSinceEpoch + wait * 1000;
        if (attempt == 2) throw MarketFailure('Aster HTTP ${response.statusCode}: rate limit');
        await Future<void>.delayed(Duration(seconds: wait));
        continue;
      }
      if (response.statusCode != 200) {
        throw MarketFailure('Aster HTTP ${response.statusCode}');
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const MarketFailure('Invalid Aster response');
      }
    }
    throw const MarketFailure('Aster rate limit');
  }

  Future<List<AsterInstrument>> instruments() async {
    final results = await Future.wait([
      request('/fapi/v3/exchangeInfo'),
      request('/fapi/v3/ticker/24hr'),
      request('/fapi/v3/time'),
      request('/fapi/v3/premiumIndex'),
    ]);
    _serverOffset =
        ((results[2] as Map<String, dynamic>)['serverTime'] as num).toInt() -
        DateTime.now().millisecondsSinceEpoch;
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
  }

  Future<List<Candle>> history(
    String symbol,
    String interval, {
    int? start,
    int? end,
    int limit = 200,
  }) async {
    if (limit < 1 || limit > 1500) throw ArgumentError.value(limit, 'limit');
    final raw = await request('/fapi/v3/klines', {
      'symbol': symbol,
      'interval': interval,
      'limit': '$limit',
      if (start != null) 'startTime': '$start',
      if (end != null) 'endTime': '$end',
    });
    final now = serverNow;
    return (raw as List<dynamic>)
        .map((entry) {
          final row = entry as List<dynamic>;
          final candle = Candle(
            time: (row[0] as num).toInt(),
            open: numeric(row[1]),
            high: numeric(row[2]),
            low: numeric(row[3]),
            close: numeric(row[4]),
            volume: numeric(row[5]),
            closed: (row[6] as num).toInt() < now - 2000,
          );
          validateCandle(candle);
          return candle;
        })
        .toList(growable: false);
  }

  Stream<Map<String, Object?>> stream(List<String> streams) {
    if (streams.isEmpty || streams.length > 200) {
      return Stream.error(
        ArgumentError.value(streams.length, 'streams', 'Aster supports 1–200 streams'),
      );
    }
    return AsterMarketStream(_streamUri, streams, _connect).events;
  }

  Stream<Map<String, Object?>> bookStream(String symbol) {
    late StreamController<Map<String, Object?>> output;
    final subscriptions = <StreamSubscription<Map<String, Object?>>>[];
    output = StreamController<Map<String, Object?>>(
      onListen: () {
        for (final entry in [('depth', '$symbol@depth20@500ms'), ('trades', '$symbol@aggTrade')]) {
          subscriptions.add(
            stream([entry.$2]).listen((event) {
              if (!output.isClosed) output.add({...event, 'channel': entry.$1});
            }, onError: output.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return output.stream;
  }

  Future<Map<String, Map<String, Object?>>> refreshTickers({String? symbol}) async {
    final parameters = <String, String>{'symbol': ?symbol};
    final responses = await Future.wait([
      request('/fapi/v3/ticker/24hr', parameters),
      request('/fapi/v3/premiumIndex', parameters),
    ]);
    if (symbol != null) {
      final ticker = responses[0] as Map<String, dynamic>;
      final premium = responses[1] as Map<String, dynamic>;
      return {
        symbol: {...ticker, ...premium},
      };
    }
    final premiums = {
      for (final raw in responses[1] as List<dynamic>)
        (raw as Map<String, dynamic>)['symbol'] as String: raw,
    };
    return {
      for (final raw in responses[0] as List<dynamic>)
        (raw as Map<String, dynamic>)['symbol'] as String: {...raw, ...?premiums[raw['symbol']]},
    };
  }

  static Candle liveCandle(Map<String, Object?> event) {
    final k = event['k'] as Map<String, dynamic>;
    final candle = Candle(
      time: (k['t'] as num).toInt(),
      open: numeric(k['o']),
      high: numeric(k['h']),
      low: numeric(k['l']),
      close: numeric(k['c']),
      volume: numeric(k['v']),
      closed: k['x'] == true,
      eventTime: (event['E'] as num).toInt(),
    );
    validateCandle(candle);
    return candle;
  }

  static double numeric(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite) {
      throw const MarketFailure('Invalid Aster numeric data');
    }
    return number;
  }

  static void validateCandle(Candle c) {
    if (c.time < 0 ||
        c.low <= 0 ||
        c.high < c.low ||
        c.open < c.low ||
        c.open > c.high ||
        c.close < c.low ||
        c.close > c.high ||
        c.volume < 0) {
      throw const MarketFailure('Invalid Aster candle');
    }
  }
}
