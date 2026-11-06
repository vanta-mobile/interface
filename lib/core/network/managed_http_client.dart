import 'dart:async';

import 'package:http/http.dart' as http;

import 'request_scope.dart';

/// A service-local lifetime over an owned client or a borrowed connection pool.
/// Closing it aborts only its own requests. Timeouts include the response body.
class ManagedHttpClient extends http.BaseClient {
  ManagedHttpClient(
    this._inner, {
    this.ownsClient = true,
    this.timeout = const Duration(seconds: 12),
    this.maxResponseBytes = 16 * 1024 * 1024,
  });
  final http.Client _inner;
  final bool ownsClient;
  final Duration timeout;
  final int maxResponseBytes;
  final _pending = <_PendingRequest>{};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest original) async {
    if (_closed) throw http.ClientException('HTTP client closed');
    final pending = _PendingRequest(original.url, timeout, RequestScope.current);
    _pending.add(pending);
    void finish() {
      _pending.remove(pending);
      pending.dispose();
    }

    try {
      pending.check();
      final http.BaseRequest request;
      if (original is http.Request) {
        request = http.AbortableRequest(
          original.method,
          original.url,
          abortTrigger: pending.aborted.future,
        )..bodyBytes = original.bodyBytes;
        original.finalize();
      } else {
        final streamed = http.AbortableStreamedRequest(
          original.method,
          original.url,
          abortTrigger: pending.aborted.future,
        );
        request = streamed;
        unawaited(
          streamed.sink
              .addStream(original.finalize())
              .then<void>(
                (_) async {
                  await streamed.sink.close();
                },
                onError: (Object error, StackTrace stack) {
                  pending.abort(error);
                },
              ),
        );
      }
      request
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection
        ..headers.addAll(original.headers);
      if (request is http.StreamedRequest) request.contentLength = original.contentLength;
      if (original is http.Abortable) {
        original.abortTrigger?.then(
          (_) => pending.abort(http.RequestAbortedException(original.url)),
        );
      }
      final response = await Future.any([
        _inner.send(request).then((response) {
          if (pending.stopped) {
            unawaited(response.stream.listen(null).cancel());
            pending.check();
          }
          return response;
        }),
        pending.aborted.future.then<http.StreamedResponse>((_) {
          pending.check();
          throw StateError('Unreachable');
        }),
      ]);
      pending.check();
      late StreamController<List<int>> output;
      StreamSubscription<List<int>>? subscription;
      var ended = false, bytes = 0;
      void end([Object? error, StackTrace? stack]) {
        if (ended) return;
        ended = true;
        if (error != null) output.addError(error, stack);
        unawaited(output.close());
        unawaited(subscription?.cancel());
        finish();
      }

      output = StreamController<List<int>>(
        onListen: () {
          if (pending.stopped) {
            end(pending.error);
            unawaited(response.stream.listen(null).cancel());
            return;
          }
          subscription = response.stream.listen(
            (chunk) {
              bytes += chunk.length;
              if (bytes > maxResponseBytes) {
                pending.abort(http.ClientException('Response exceeds size limit', original.url));
                return;
              }
              output.add(chunk);
            },
            onError: end,
            onDone: end,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () {
          if (ended) return;
          pending.abort(http.RequestAbortedException(original.url));
          end();
        },
      );
      pending.aborted.future.then((_) => end(pending.error));
      return http.StreamedResponse(
        output.stream,
        response.statusCode,
        contentLength: response.contentLength,
        request: original,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      finish();
      rethrow;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final request in _pending.toList()) {
      request.abort(http.RequestAbortedException(request.uri));
    }
    if (ownsClient) _inner.close();
  }
}

class _PendingRequest {
  _PendingRequest(this.uri, Duration timeout, RequestScope? scope) {
    _timeout = Timer(timeout, () => abort(TimeoutException('HTTP request timed out', timeout)));
    // Existing repositories expose revision predicates. Monitor only active
    // network work; no background polling or timers survive request completion.
    if (scope != null) {
      void checkScope() {
        try {
          if (!scope.active) abort(http.RequestAbortedException(uri));
        } catch (_) {
          abort(http.RequestAbortedException(uri));
        }
      }

      checkScope();
      if (!stopped) _scope = Timer.periodic(const Duration(milliseconds: 25), (_) => checkScope());
    }
  }
  final Uri uri;
  final aborted = Completer<void>();
  Object? error;
  Timer? _timeout, _scope;
  bool get stopped => aborted.isCompleted;
  void check() {
    if (error case final failure?) throw failure;
  }

  void abort(Object reason) {
    if (stopped) return;
    error = reason;
    aborted.complete();
    dispose();
  }

  void dispose() {
    _timeout?.cancel();
    _scope?.cancel();
  }
}
