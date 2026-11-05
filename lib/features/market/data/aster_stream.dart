import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A cancellable public subscription. Cancelling on symbol/interval changes
/// closes the socket immediately, including when no market events arrive.
class AsterMarketStream {
  AsterMarketStream(this.uri, List<String> streams, this.connect)
    : streams = List.unmodifiable(streams) {
    _output = StreamController<Map<String, Object?>>(
      onListen: () => unawaited(_open()),
      onCancel: _dispose,
    );
  }

  final Uri uri;
  final List<String> streams;
  final WebSocketChannel Function(Uri) connect;
  late final StreamController<Map<String, Object?>> _output;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _idle;
  bool _disposed = false;
  int _delay = 1;
  Stream<Map<String, Object?>> get events => _output.stream;

  Future<void> _open() async {
    try {
      final socket = connect(uri);
      _socket = socket;
      await socket.ready.timeout(const Duration(seconds: 12));
      if (_disposed) {
        await socket.sink.close();
        return;
      }
      socket.sink.add(jsonEncode({'method': 'SUBSCRIBE', 'params': streams, 'id': 1}));
      _output.add({'connected': true});
      _resetIdle();
      _subscription = socket.stream.listen(
        _onMessage,
        onError: (Object _) => unawaited(_disconnect()),
        onDone: () => unawaited(_disconnect()),
      );
    } on Object {
      await _disconnect();
    }
  }

  void _resetIdle() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 35), () => unawaited(_disconnect()));
  }

  void _onMessage(dynamic raw) {
    if (_disposed || _retry != null) return;
    try {
      final envelope = jsonDecode(raw as String);
      if (envelope is Map<String, dynamic> && envelope['code'] != null) {
        unawaited(_disconnect());
        return;
      }
      _resetIdle();
      // Acknowledgements are control messages. Both combined and raw market
      // events are accepted, as defined by Aster's public stream protocol.
      final data = envelope is Map<String, dynamic> ? envelope['data'] ?? envelope : envelope;
      // All-market ticker / mark streams send arrays containing only the
      // symbols changed in this update. Flatten without replacing any state.
      for (final event in data is List ? data : [data]) {
        if (event is Map<String, dynamic> && event['e'] is String) {
          _delay = 1;
          _output.add(event);
        }
      }
    } on Object {
      unawaited(_disconnect());
    }
  }

  Future<void> _disconnect() async {
    if (_disposed || _retry != null) return;
    _idle?.cancel();
    _output.add({'disconnected': true});
    _retry = Timer(Duration(seconds: _delay), () {
      _retry = null;
      if (!_disposed) unawaited(_open());
    });
    _delay = (_delay * 2).clamp(1, 20);
    await _closeSocket();
  }

  Future<void> _closeSocket() async {
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    await subscription?.cancel();
    await socket?.sink.close();
  }

  Future<void> _dispose() async {
    _disposed = true;
    _retry?.cancel();
    _idle?.cancel();
    await _closeSocket();
  }
}
