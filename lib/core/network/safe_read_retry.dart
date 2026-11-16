import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'request_scope.dart';

/// Explicitly opted-in reads only. Parsing and business failures stay outside
/// this transport policy; financial writes must never use it.
class SafeReadRetry {
  final _closed = Completer<void>();

  Future<http.Response> run(Future<http.Response> Function() read) async {
    final scope = RequestScope.current;
    void check() {
      if (_closed.isCompleted || scope != null && !scope.active) {
        throw http.RequestAbortedException();
      }
    }

    for (var attempt = 0; ; attempt++) {
      check();
      http.Response? response;
      try {
        response = await read();
        if (attempt == 2 || !_retryStatus(response.statusCode)) return response;
      } on http.RequestAbortedException {
        rethrow;
      } on TimeoutException {
        if (attempt == 2) rethrow;
      } on SocketException {
        if (attempt == 2) rethrow;
      } on http.ClientException {
        if (attempt == 2) rethrow;
      }
      check();
      final backoff = Duration(milliseconds: 300 * (1 << attempt));
      final retryAfter = _retryAfter(response?.headers['retry-after']);
      final delay = retryAfter != null && retryAfter > backoff ? retryAfter : backoff;
      final ready = Completer<void>();
      final timer = Timer(delay, ready.complete);
      final monitor = Timer.periodic(const Duration(milliseconds: 25), (_) {
        try {
          check();
        } catch (error, stack) {
          if (!ready.isCompleted) ready.completeError(error, stack);
        }
      });
      try {
        await Future.any([
          ready.future,
          _closed.future.then((_) => throw http.RequestAbortedException()),
        ]);
      } finally {
        timer.cancel();
        monitor.cancel();
      }
    }
  }

  void close() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

bool _retryStatus(int status) => const {408, 418, 429, 500, 502, 503, 504}.contains(status);

Duration? _retryAfter(String? header) {
  if (header == null) return null;
  final seconds = int.tryParse(header);
  if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
  try {
    return HttpDate.parse(header).difference(DateTime.now());
  } on FormatException {
    return null;
  }
}
