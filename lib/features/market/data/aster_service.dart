import '../../../core/errors/api_error_parser.dart';
export '../domain/aster_instrument.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/market_failure.dart';
import '../domain/market.dart';
import 'aster_stream.dart';
import 'shared_market_streams.dart';

class AsterService {
  AsterService(this.client, {WebSocketChannel Function(Uri)? connect})
    : _connect = connect ?? WebSocketChannel.connect {
    _streams = SharedMarketStreams(
      (channels) => AsterMarketStream(_streamUri, channels, _connect).events,
    );
  }
  final http.Client client;
  final WebSocketChannel Function(Uri) _connect;
  static final _streamUri = Uri.parse('wss://fstream.asterdex.com/stream');
  late final SharedMarketStreams _streams;
  Future<void> dispose() => _streams.dispose();
  int _serverOffset = 0;
  int get serverNow => DateTime.now().millisecondsSinceEpoch + _serverOffset;
  Future<Object?> request(String path, [Map<String, String>? query]) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final response = await client
          .get(Uri.https('fapi.asterdex.com', path, query))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 429 || response.statusCode == 418) {
        if (attempt == 2) {
          throw MarketFailure(
            'Aster HTTP ${response.statusCode}: rate limit',
            details: apiErrorDetails(
              decodeErrorPayload(response.body),
              status: response.statusCode,
            ),
          );
        }
        continue;
      }
      if (response.statusCode != 200) {
        throw MarketFailure(
          'Aster HTTP ${response.statusCode}',
          details: apiErrorDetails(decodeErrorPayload(response.body), status: response.statusCode),
        );
      }
      try {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        if (payload is Map && payload['code'] is int && (payload['code'] as int) < 0) {
          throw MarketFailure(
            'Aster error ${payload['code']}',
            details: apiErrorDetails(payload, status: response.statusCode),
          );
        }
        return payload;
      } on FormatException {
        throw const MarketFailure('Invalid Aster response');
      }
    }
    throw const MarketFailure('Aster rate limit');
  }

  void calibrateClock(int serverTime) {
    _serverOffset = serverTime - DateTime.now().millisecondsSinceEpoch;
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
    return _streams.stream(streams);
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
