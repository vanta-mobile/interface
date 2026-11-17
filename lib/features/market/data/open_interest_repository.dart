import 'dart:async';
import 'dart:collection';

import 'package:decimal/decimal.dart';

import '../../../core/market_failure.dart';
import 'aster_service.dart';

/// Public per-symbol open interest in base-asset units. Aster offers no
/// all-market query, so reads are queued to bound concurrent requests.
class OpenInterestRepository {
  OpenInterestRepository(this.service, {this.maxConcurrent = 4});
  final AsterService service;
  final int maxConcurrent;
  final _waiting = Queue<Completer<void>>();
  int _running = 0;
  Completer<void>? _idle;

  Future<Decimal> read(String symbol) async {
    if (_running >= maxConcurrent) {
      // A finishing read hands its slot over directly.
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _running++;
    }
    try {
      return mapOpenInterest(
        await service.request('/fapi/v3/openInterest', {'symbol': symbol}),
        symbol,
      );
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else if (--_running == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  /// Completes once every queued and in-flight read has settled.
  Future<void> settled() {
    if (_running == 0 && _waiting.isEmpty) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }
}

Decimal mapOpenInterest(Object? payload, String symbol) {
  final value = payload is Map && payload['symbol'] == symbol
      ? Decimal.tryParse('${payload['openInterest']}')
      : null;
  if (value == null || value < Decimal.zero) {
    throw const MarketFailure('Invalid Aster open interest');
  }
  return value;
}
