import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../notifications/data/futures_notification_mapper.dart';
import '../../notifications/data/spot_notification_mapper.dart';
import '../../notifications/domain/account_notification.dart';
import '../domain/account_change_stream.dart';
import '../domain/account_snapshot.dart';
import 'open_order_update_mapper.dart';
import 'account_update_mapper.dart';
import 'spot_open_orders_mapper.dart';

/// Private stream: no subscription message, payload logging or quiet-account
/// idle timeout. Disconnects require an explicit reconnect and invalidate all
/// dependent snapshots, since missed events cannot be replayed.
class AsterUserStream {
  AsterUserStream(String key, WebSocketChannel Function(Uri) connect) : this._(key, connect, false);
  AsterUserStream.spot(String key, WebSocketChannel Function(Uri) connect)
    : this._(key, connect, true);
  AsterUserStream._(String key, this.connect, this._spot)
    : _uri = Uri.https(
        _spot ? 'sstream.asterdex.com' : 'fstream.asterdex.com',
        '/ws/$key',
      ).replace(scheme: 'wss') {
    _output = StreamController<AccountChangeEvent>(
      onListen: () => unawaited(_open()),
      onCancel: _dispose,
    );
  }
  final Uri _uri;
  final bool _spot;
  final WebSocketChannel Function(Uri) connect;
  late final StreamController<AccountChangeEvent> _output;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false, _ended = false;
  Stream<AccountChangeEvent> get events => _output.stream;

  Future<void> _open() async {
    try {
      final socket = connect(_uri);
      _socket = socket;
      await socket.ready.timeout(const Duration(seconds: 12));
      if (_disposed || _ended) return;
      _output.add(const AccountChangeEvent.connected());
      _subscription = socket.stream.listen(_message, onError: (Object _) => _fail(), onDone: _fail);
    } catch (_) {
      _fail();
    }
  }

  void _message(dynamic raw) {
    if (_disposed || _ended) return;
    try {
      if (raw is! String || raw.length > 1024 * 1024) throw const FormatException();
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['e'] is! String) throw const FormatException();
      if (data['e'] == 'listenKeyExpired') {
        _output.add(const AccountChangeEvent.expired());
        _end();
        return;
      }
      final time = data['E'];
      if (time is! int || time <= 0 || time > 253402300799999) throw const FormatException();
      final kind = _spot
          ? switch (data['e']) {
              'executionReport' => AccountChangeKind.order,
              'outboundAccountPosition' => AccountChangeKind.account,
              _ => AccountChangeKind.unknown,
            }
          : switch (data['e']) {
              'ACCOUNT_UPDATE' => AccountChangeKind.account,
              'ORDER_TRADE_UPDATE' => AccountChangeKind.order,
              'ACCOUNT_CONFIG_UPDATE' => AccountChangeKind.configuration,
              'MARGIN_CALL' => AccountChangeKind.marginCall,
              _ => AccountChangeKind.unknown,
            };
      final notification = _spot
          ? data['e'] == 'executionReport'
                ? mapSpotNotification(data)
                : null
          : mapFuturesNotification(data);
      final riskOrder = notification is OrderNotification && notification.critical;
      // Do not discard older/duplicate E values: updates can arrive out of
      // order, and every event may invalidate a newer in-flight REST read.
      _output.add(
        AccountChangeEvent.changed(
          kind,
          DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
          order: !_spot && kind == AccountChangeKind.order && !riskOrder
              ? mapOpenOrderUpdate(data)
              : null,
          notification: notification,
          spotOrder: _spot && notification is SpotOrderNotification
              ? mapSpotOpenOrderUpdate(notification, timeInForce: data['f'])
              : null,
          account: !_spot && kind == AccountChangeKind.account ? mapAccountUpdate(data) : null,
        ),
      );
    } catch (_) {
      _fail(const AccountReadFailure('accountDataInvalid'));
    }
  }

  void _fail([Object? failure]) {
    if (_disposed || _ended) return;
    _output.addError(
      failure is AccountReadFailure ? failure : const AccountReadFailure('accountNetwork'),
    );
    _end();
  }

  void _end() {
    _ended = true;
    unawaited(_dispose());
    unawaited(_output.close());
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
      await _socket?.sink.close();
    } catch (_) {
      // Transport errors must not expose a private URI/listen key.
    }
    _socket = null;
  }
}
