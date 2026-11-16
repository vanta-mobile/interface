// Exercise the pinned SDK transport, including its JSON-RPC client.
// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_core/crypto/i_crypto.dart';
import 'package:reown_core/relay_client/relay_client.dart';
import 'package:reown_core/relay_client/json_rpc_2/src/exception.dart';
import 'package:reown_core/relay_client/websocket/i_websocket_handler.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReownCore core;
  late RelayClient relay;
  late _Crypto crypto;
  late _Socket socket;
  late List<Object?> errors;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (_) async => {
        'appName': 'Vanta test',
        'packageName': 'test.vanta',
        'version': '1',
        'buildNumber': '1',
      },
    );
    socket = _Socket();
    crypto = _Crypto();
    core = ReownCore(projectId: 'test', memoryStore: true, webSocketHandler: socket);
    core.crypto = crypto;
    relay = core.relayClient as RelayClient;
    errors = [];
    relay.onRelayClientError.subscribe((event) => errors.add(event.error));
    await core.storage.init();
    await relay.init();
    await relay.disconnect();
    socket.connections = 0;
    crypto.calls = 0;
  });

  tearDown(() async {
    socket.connectGate?.completeIfPending();
    socket.closeGate?.completeIfPending();
    crypto.gate?.completeIfPending();
    await relay.disconnect();
    core.heartbeat.stop();
  });

  test('relay IDs satisfy the 19-digit string contract without losing precision', () async {
    await relay.connect();
    final before = DateTime.now().millisecondsSinceEpoch;
    final subscriptions = [
      for (var i = 0; i < 4; i++) relay.subscribe(options: SubscribeOptions(topic: 'topic-$i')),
    ];
    await pumpEventQueue();
    final after = DateTime.now().millisecondsSinceEpoch;
    final ids = socket.requests.map((r) => r['id'] as String).toList();
    expect(ids.toSet(), hasLength(4));
    expect(ids, orderedEquals(ids.toList()..sort()));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[1-9][0-9]{18}$')));
      expect(int.parse(id.substring(0, 13)), inInclusiveRange(before, after));
      // JSON string IDs survive a JavaScript JSON parse/stringify unchanged.
      expect(jsonDecode(jsonEncode({'id': id}))['id'], id);
      socket.reply(id, 'subscription-$id');
    }
    await Future.wait(subscriptions);
  });

  test('relay contract rejects the old small counter with the reported error', () async {
    await relay.connect();
    await expectLater(
      relay.jsonRPC!.sendRequest('irn_subscribe', {'topic': 'topic'}, 1),
      throwsA(
        isA<RpcException>()
            .having((e) => e.code, 'code', -32500)
            .having((e) => e.message, 'message', 'Invalid request ID'),
      ),
    );
  });

  test('unrelated malformed response IDs cannot break a valid relay response', () async {
    await relay.connect();
    final pending = relay.subscribe(options: SubscribeOptions(topic: 'topic'));
    await pumpEventQueue();
    socket.reply('not-a-decimal-id', true);
    socket.reply('999999999999999999999999999999', true);
    socket.reply(null, true);
    socket.reply(1.5, true);
    socket.reply(socket.requests.single['id'], 'subscription');
    expect(await pending, 'subscription');
    expect(errors, isEmpty);
  });

  test('legacy integer requests still accept decimal string response IDs', () async {
    await relay.connect();
    final pending = relay.jsonRPC!.sendRequest('fixture', <String, Object?>{}, 42);
    await pumpEventQueue();
    socket.reply('42', 'legacy-result');
    expect(await pending, 'legacy-result');
  });

  for (final accepted in [true, false]) {
    test('publish acknowledgement is emitted only after relay acceptance: $accepted', () async {
      await relay.connect();
      final published = <RelayPublishEvent>[];
      relay.onRelayClientPublish.subscribe(published.add);
      final pending = relay.publish(
        topic: 'session-topic',
        message: 'fixture-encrypted',
        options: const PublishOptions(ttl: 300, tag: 1108, correlationId: 42),
      );
      await pumpEventQueue();
      expect(published, isEmpty);
      final request = socket.requests.single;
      expect(request['method'], 'irn_publish');
      socket.reply(request['id'], accepted);
      await pending;
      if (accepted) {
        expect(published.single.topic, 'session-topic');
        expect(published.single.correlationId, 42);
        expect(errors, isEmpty);
      } else {
        expect(published, isEmpty);
        expect(errors, hasLength(1));
      }
    });
  }

  test('concurrent foreground and signing reconnects open only one socket', () async {
    socket.connectGate = Completer<void>();
    final first = relay.connect();
    await pumpEventQueue();
    final second = relay.connect();
    await pumpEventQueue();
    socket.connectGate!.complete();
    await Future.wait([first, second]);

    expect(socket.connections, 1);
    expect(crypto.calls, 1);
    expect(relay.isConnected, true);
    expect(errors, isEmpty);
  });

  test('a delayed overlapping reconnect preserves an in-flight irn_subscribe', () async {
    socket.connectGate = Completer<void>();
    final first = relay.connect();
    await pumpEventQueue();
    // On the unpatched SDK this second attempt waits in JWT preparation while
    // the first socket opens and starts restoring the session subscription.
    crypto.gate = Completer<void>();
    final second = relay.connect();
    await pumpEventQueue();
    socket.connectGate!.complete();
    await first;
    final subscription = relay.subscribe(options: SubscribeOptions(topic: 'test-topic'));
    await pumpEventQueue();
    final request = socket.requests.single;
    expect(request['method'], 'irn_subscribe');

    crypto.gate!.complete();
    await second;
    await pumpEventQueue();
    socket.reply(request['id'], 'subscription-id');

    expect(errors, isEmpty);
    expect(await subscription, 'subscription-id');
    expect(socket.connections, 1);
  });

  test('disconnect during JWT preparation prevents a late socket from opening', () async {
    crypto.gate = Completer<void>();
    final pending = relay.connect();
    await pumpEventQueue();
    await relay.disconnect();
    crypto.gate!.complete();
    await pending;

    expect(socket.connections, 0);
    expect(relay.isConnected, false);
    await relay.connect();
    expect(socket.connections, 1);
    expect(relay.isConnected, true);
  });

  test('disconnect while a socket is opening closes the late connection', () async {
    socket.connectGate = Completer<void>();
    final pending = relay.connect();
    await pumpEventQueue();
    await relay.disconnect();
    socket.connectGate!.complete();
    await pending;

    expect(relay.isConnected, false);
    expect(socket.channel, isNull);
    await relay.connect();
    expect(socket.connections, 2);
    expect(relay.isConnected, true);
  });

  test('a new reconnect waits for an in-progress disconnect to finish', () async {
    await relay.connect();
    crypto.calls = 0;
    socket.closeGate = Completer<void>();
    final disconnect = relay.disconnect();
    await pumpEventQueue();
    final reconnect = relay.connect();
    await pumpEventQueue();

    expect(crypto.calls, 0);
    socket.closeGate!.complete();
    await Future.wait([disconnect, reconnect]);
    expect(relay.isConnected, true);
    expect(crypto.calls, 1);
    expect(errors, isEmpty);
  });

  test('connection timeout retries the connection once without overlapping callers', () async {
    socket.connectGate = Completer<void>();
    socket.failure = TimeoutException('test connection timeout');
    final pending = [relay.connect(), relay.connect(), relay.connect()];
    await pumpEventQueue();
    socket.connectGate!.complete();
    await Future.wait(pending);
    await pumpEventQueue();

    expect(errors, ['Connection to relay timeout']);
    expect(socket.connections, 2);
    expect(relay.isConnected, true);
    expect(socket.requests, isEmpty);
  });

  test('disconnect on timeout stops the SDK connection retry', () async {
    socket.failure = TimeoutException('test connection timeout');
    relay.onRelayClientError.subscribe((_) => unawaited(relay.disconnect()));
    await relay.connect();
    await pumpEventQueue();

    expect(socket.connections, 1);
    expect(relay.isConnected, false);
  });

  test('a failed connection releases ownership for an explicit later retry', () async {
    socket.failure = StateError('test socket failure');
    await Future.wait([relay.connect(), relay.connect()]);
    expect(errors, hasLength(1));
    expect(socket.connections, 1);
    expect(relay.isConnected, false);

    await relay.connect();
    expect(socket.connections, 2);
    expect(relay.isConnected, true);
  });

  test('SDK socket-close recovery and foreground reconnect share one attempt', () async {
    await relay.connect();
    socket.connections = 0;
    socket.connectGate = Completer<void>();
    await socket.serverClose(1001);
    await pumpEventQueue();
    final foreground = relay.connect();
    await pumpEventQueue();
    socket.connectGate!.complete();
    await foreground;

    expect(socket.connections, 1);
    expect(relay.isConnected, true);
    expect(errors, isEmpty);
  });

  test('disconnecting a pending core never changes another core connection', () async {
    final otherSocket = _Socket();
    final otherCore = ReownCore(projectId: 'test', memoryStore: true, webSocketHandler: otherSocket)
      ..crypto = _Crypto();
    addTearDown(otherCore.relayClient.disconnect);
    await otherCore.storage.init();
    await otherCore.relayClient.init();

    crypto.gate = Completer<void>();
    final pending = relay.connect();
    await pumpEventQueue();
    await relay.disconnect();
    crypto.gate!.complete();
    await pending;

    expect(relay.isConnected, false);
    expect(otherCore.relayClient.isConnected, true);
    expect(otherSocket.connections, 1);
  });
}

class _Crypto implements ICrypto {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<String> signJWT(String aud) async {
    calls++;
    await gate?.future;
    return 'test-jwt';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Socket implements IWebSocketHandler {
  int connections = 0;
  Completer<void>? connectGate;
  Completer<void>? closeGate;
  Object? failure;
  StreamController<String>? _incoming, _outgoing;
  final requests = <Map<String, dynamic>>[];

  @override
  String? url;
  @override
  int? closeCode;
  @override
  String? get closeReason => null;
  @override
  StreamChannel<String>? channel;

  @override
  Future<void> setup({required String url}) async {
    this.url = url;
    await close();
    closeCode = null;
  }

  @override
  Future<void> connect() async {
    connections++;
    await connectGate?.future;
    if (failure case final error?) {
      failure = null;
      throw error;
    }
    _incoming = StreamController<String>.broadcast();
    _outgoing = StreamController<String>();
    _outgoing!.stream.listen((message) {
      final request = jsonDecode(message) as Map<String, dynamic>;
      requests.add(request);
      // WalletConnect relay RPC specifies 19 decimal digits. Generic JSON-RPC
      // counters pass local codecs but violate this service contract.
      if ((request['method'] as String).startsWith('irn_') &&
          (request['id'] is! String ||
              !RegExp(r'^[1-9][0-9]{18}$').hasMatch(request['id'] as String))) {
        _incoming!.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': request['id'],
            'error': {'code': -32500, 'message': 'Invalid request ID'},
          }),
        );
      }
    });
    channel = StreamChannel(_incoming!.stream, _outgoing!.sink);
  }

  void reply(Object? id, Object result) {
    // The live relay echoes our 19-digit string request IDs as JSON integers.
    final wireId = id is String && RegExp(r'^[1-9][0-9]{18}$').hasMatch(id) ? int.parse(id) : id;
    _incoming!.add(jsonEncode({'jsonrpc': '2.0', 'id': wireId, 'result': result}));
  }

  Future<void> serverClose(int code) async {
    closeCode = code;
    await _incoming!.close();
  }

  @override
  Future<void> close() async {
    await closeGate?.future;
    await _incoming?.close();
    await _outgoing?.close();
    _incoming = null;
    _outgoing = null;
    channel = null;
  }
}

extension on Completer<void> {
  void completeIfPending() {
    if (!isCompleted) complete();
  }
}
