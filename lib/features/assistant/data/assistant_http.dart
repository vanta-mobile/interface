import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../market/data/market_http_client.dart';
import '../domain/assistant.dart';
import 'assistant_configuration.dart';
import 'assistant_sse.dart';

class AssistantHttp {
  AssistantHttp({
    http.Client? client,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 20),
    this.chatTimeout = const Duration(minutes: 5),
    this.idleTimeout = const Duration(minutes: 2),
  }) : _client = client ?? createMarketHttpClient(),
       now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() now;
  final Duration requestTimeout, chatTimeout, idleTimeout;
  final _active = <_RequestLease>{};
  AssistantConfiguration? _configuration;
  bool _closed = false;

  void close() {
    _closed = true;
    for (final lease in _active.toList()) {
      lease.abort();
    }
    _client.close();
  }

  Future<AssistantConfiguration> configuration(AssistantCancellation cancellation) async {
    cancellation.check();
    if (_closed) throw const AssistantFailure('assistantCancelled');
    if (_configuration case final config?) return config;
    final source = await _text(
      'GET',
      AssistantConfiguration.runtimeUri,
      cancellation: cancellation,
      limit: 65536,
      accept: 'application/javascript, text/javascript, text/plain',
    );
    cancellation.check();
    return _configuration = AssistantConfiguration.fromRuntime(source);
  }

  Future<Object?> json(
    String method,
    String path, {
    required AssistantCancellation cancellation,
    String? token,
    Map<String, String>? query,
    Map<String, String> headers = const {},
    Object? body,
    void Function()? guard,
  }) async {
    guard?.call();
    final config = await configuration(cancellation);
    guard?.call();
    final text = await _text(
      method,
      config.origin.replace(path: path, queryParameters: query),
      cancellation: cancellation,
      body: body,
      headers: {..._headers(config, token), ...headers},
    );
    guard?.call();
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const AssistantFailure('assistantInvalidResponse');
    }
  }

  Stream<AssistantDelta> chat({
    required String token,
    required String userId,
    required String requestId,
    required List<Map<String, String>> messages,
    required AssistantCancellation cancellation,
  }) async* {
    final config = await configuration(cancellation);
    final lease = _lease(cancellation, chatTimeout, idle: idleTimeout);
    try {
      final request = _request(
        'POST',
        config.origin.replace(path: '/functions/v1/starchild-chat'),
        lease,
        headers: {..._headers(config, token), 'Accept': 'text/event-stream'},
        body: {'stream': true, 'user': userId, 'request_id': requestId, 'messages': messages},
      );
      final response = await _send(request, lease);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _failure(response, lease);
      }
      if (!_mime(response, 'text/event-stream')) {
        await response.stream.listen(null).cancel();
        throw const AssistantFailure('assistantInvalidResponse');
      }
      yield* decodeAssistantSse(_read(response.stream, lease));
    } on AssistantFailure {
      rethrow;
    } catch (_) {
      lease.check();
      throw const AssistantFailure('assistantUnavailable');
    } finally {
      _release(lease);
    }
  }

  Future<AssistantReply> complete({
    required String token,
    required String userId,
    required String requestId,
    required List<Map<String, String>> messages,
    required AssistantCancellation cancellation,
    bool finalAnswerOnly = false,
  }) async {
    final config = await configuration(cancellation);
    final source = await _text(
      'POST',
      config.origin.replace(path: '/functions/v1/starchild-chat'),
      cancellation: cancellation,
      timeout: chatTimeout,
      headers: _headers(config, token),
      body: {
        'stream': false,
        'user': userId,
        'request_id': requestId,
        'messages': [
          ...messages,
          if (finalAnswerOnly)
            {
              'role': 'system',
              'content': 'Please provide only the final answer to the user. Do not include reasoning or thinking process.',
            },
        ],
      },
    );
    try {
      final value = jsonDecode(source);
      if (value is! Map<String, Object?>) throw const FormatException();
      final content = value['content'], reasoning = value['reasoning_content'];
      if ((content != null && content is! String) || (reasoning != null && reasoning is! String)) {
        throw const FormatException();
      }
      final answer = content as String? ?? '', thoughts = reasoning as String? ?? '';
      if (answer.length + thoughts.length > 131072) {
        throw const AssistantFailure('assistantTooLarge');
      }
      return AssistantReply(content: answer.trim(), reasoning: thoughts.trim());
    } on AssistantFailure {
      rethrow;
    } catch (_) {
      throw const AssistantFailure('assistantInvalidResponse');
    }
  }

  Map<String, String> _headers(AssistantConfiguration config, String? token) => {
    'apikey': config.publicKey,
    'Authorization': 'Bearer ${token ?? config.publicKey}',
  };

  Future<String> _text(
    String method,
    Uri uri, {
    required AssistantCancellation cancellation,
    Object? body,
    Map<String, String> headers = const {},
    int limit = 262144,
    String accept = 'application/json',
    Duration? timeout,
  }) async {
    final lease = _lease(cancellation, timeout ?? requestTimeout);
    try {
      final response = await _send(
        _request(method, uri, lease, headers: {'Accept': accept, ...headers}, body: body),
        lease,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _failure(response, lease);
      }
      if (accept == 'application/json' && !_mime(response, 'application/json')) {
        await response.stream.listen(null).cancel();
        throw const AssistantFailure('assistantInvalidResponse');
      }
      final text = await _boundedText(response.stream, lease, limit);
      lease.check();
      return text;
    } on AssistantFailure {
      rethrow;
    } catch (_) {
      lease.check();
      throw const AssistantFailure('assistantUnavailable');
    } finally {
      _release(lease);
    }
  }

  http.AbortableRequest _request(
    String method,
    Uri uri,
    _RequestLease lease, {
    Map<String, String> headers = const {},
    Object? body,
  }) {
    lease.check();
    final request = http.AbortableRequest(method, uri, abortTrigger: lease.stopped.future)
      ..followRedirects = false
      ..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return request;
  }

  Future<http.StreamedResponse> _send(http.BaseRequest request, _RequestLease lease) async {
    final pending = _client.send(request).then((response) async {
      if (lease.stopped.isCompleted) {
        await response.stream.listen(null).cancel();
        lease.check();
      }
      return response;
    });
    return Future.any([
      pending,
      lease.stopped.future.then<http.StreamedResponse>((_) {
        lease.check();
        throw const AssistantFailure('assistantCancelled');
      }),
    ]);
  }

  Stream<List<int>> _read(Stream<List<int>> source, _RequestLease lease) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var ended = false;
    Future<void> stop([Object? error]) async {
      if (ended) return;
      ended = true;
      if (error != null) controller.addError(error);
      unawaited(controller.close());
      await subscription?.cancel();
    }

    controller = StreamController<List<int>>(
      onListen: () {
        if (lease.stopped.isCompleted) {
          unawaited(source.listen(null).cancel());
          stop(AssistantFailure(lease.reason));
          return;
        }
        subscription = source.listen(
          (chunk) {
            if (!ended) {
              lease.touch();
              controller.add(chunk);
            }
          },
          onError: (Object _) => stop(const AssistantFailure('assistantUnavailable')),
          onDone: stop,
        );
        lease.stopped.future.then((_) => stop(AssistantFailure(lease.reason)));
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        ended = true;
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<String> _boundedText(Stream<List<int>> source, _RequestLease lease, int limit) async {
    final bytes = <int>[];
    await for (final chunk in _read(source, lease)) {
      if (bytes.length + chunk.length > limit) throw const AssistantFailure('assistantTooLarge');
      bytes.addAll(chunk);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const AssistantFailure('assistantInvalidResponse');
    }
  }

  Future<Never> _failure(http.StreamedResponse response, _RequestLease lease) async {
    Object? value;
    try {
      value = jsonDecode(await _boundedText(response.stream, lease, 65536));
    } on AssistantFailure {
      lease.check();
    } catch (_) {
      /* Raw server diagnostics never escape this data boundary. */
    }
    lease.check();
    final quotaExceeded =
        response.statusCode == 429 || (value is Map && value['code'] == 'daily_quota_exceeded');
    AssistantQuota? quota;
    if (value is Map && quotaExceeded) {
      int? count(String key) =>
          value is Map &&
              value[key] is int &&
              (value[key] as int) >= 0 &&
              (value[key] as int) <= 1000000000
          ? value[key] as int
          : null;
      quota = AssistantQuota(
        day: now().toUtc().toIso8601String().substring(0, 10),
        limit: count('limit'),
        used: count('used'),
        remaining: count('remaining'),
        resetAt: value['reset_at'] is String
            ? DateTime.tryParse(value['reset_at'] as String)?.toUtc()
            : null,
      );
    }
    throw AssistantFailure(
      quotaExceeded
          ? 'assistantQuotaExceeded'
          : response.statusCode == 401 || response.statusCode == 403
          ? 'assistantAuthorization'
          : 'assistantUnavailable',
      status: response.statusCode,
      quota: quota,
    );
  }

  bool _mime(http.StreamedResponse response, String expected) =>
      response.headers['content-type']?.split(';').first.trim().toLowerCase() == expected;
  _RequestLease _lease(AssistantCancellation cancellation, Duration timeout, {Duration? idle}) {
    cancellation.check();
    if (_closed) throw const AssistantFailure('assistantCancelled');
    final lease = _RequestLease(cancellation, timeout, idle);
    _active.add(lease);
    return lease;
  }

  void _release(_RequestLease lease) {
    _active.remove(lease);
    lease.dispose();
  }
}

class _RequestLease {
  _RequestLease(AssistantCancellation cancellation, Duration timeout, this.idle) {
    _total = Timer(timeout, () => abort('assistantTimeout'));
    cancellation.whenCancelled.then((_) => abort());
    touch();
  }
  final stopped = Completer<void>();
  final Duration? idle;
  Timer? _total, _idle;
  bool _disposed = false;
  String reason = 'assistantCancelled';
  void check() {
    if (stopped.isCompleted) throw AssistantFailure(reason);
  }

  void touch() {
    _idle?.cancel();
    if (!_disposed && !stopped.isCompleted && idle != null) {
      _idle = Timer(idle!, () => abort('assistantTimeout'));
    }
  }

  void abort([String key = 'assistantCancelled']) {
    if (_disposed || stopped.isCompleted) return;
    reason = key;
    stopped.complete();
    _total?.cancel();
    _idle?.cancel();
  }

  void dispose() {
    abort();
    _disposed = true;
    _total?.cancel();
    _idle?.cancel();
  }
}
