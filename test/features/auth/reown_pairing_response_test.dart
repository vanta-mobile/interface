// Exercise the pinned SDK pairing response handling.
// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_core/crypto/i_crypto.dart';
import 'package:reown_core/pairing/pairing.dart';
import 'package:reown_core/relay_client/i_relay_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReownCore core;
  late _Relay relay;

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
    relay = _Relay();
    core = ReownCore(projectId: 'test', memoryStore: true)
      ..crypto = _Crypto()
      ..relayClient = relay;
    await core.storage.init();
    await core.pairing.init();
  });

  tearDown(() => core.heartbeat.stop());

  void deliver(Map<String, dynamic> response) => relay.onRelayClientMessage.broadcast(
    MessageEvent('pairing-topic', jsonEncode(response), 0, null, TransportType.relay),
  );

  test('a redelivered response after resume settles its request only once', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final pending = core.pairing.sendRequest(
        'pairing-topic',
        MethodConstants.WC_PAIRING_PING,
        {},
      );
      await pumpEventQueue();
      final id = relay.published.single;
      deliver({'id': id, 'jsonrpc': '2.0', 'result': true});
      deliver({'id': id, 'jsonrpc': '2.0', 'result': true});
      expect(await pending, true);
      await pumpEventQueue();
    }, (error, _) => errors.add(error));
    expect(errors, isEmpty);
    expect((core.pairing as Pairing).pendingRequests, isEmpty);
  });

  test('a redelivered error response cannot complete its request again', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final pending = core.pairing.sendRequest(
        'pairing-topic',
        MethodConstants.WC_PAIRING_PING,
        {},
      );
      await pumpEventQueue();
      final id = relay.published.single;
      final error = {'code': 5000, 'message': 'Rejected'};
      deliver({'id': id, 'jsonrpc': '2.0', 'error': error});
      deliver({'id': id, 'jsonrpc': '2.0', 'error': error});
      await expectLater(pending, throwsA(isA<JsonRpcError>()));
      await pumpEventQueue();
    }, (error, _) => errors.add(error));
    expect(errors, isEmpty);
    expect((core.pairing as Pairing).pendingRequests, isEmpty);
  });
}

class _Crypto implements ICrypto {
  @override
  Future<String?> encode(
    String topic,
    Map<String, dynamic> payload, {
    EncodeOptions? options,
  }) async => jsonEncode(payload);

  @override
  Future<String?> decode(String topic, String encoded, {DecodeOptions? options}) async => encoded;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Relay implements IRelayClient {
  final published = <int>[];

  @override
  final onRelayClientConnect = Event<EventArgs>();
  @override
  final onRelayClientMessage = Event<MessageEvent>();
  @override
  final onLinkModeMessage = Event<MessageEvent>();
  @override
  bool get isConnected => false;

  @override
  Future<void> publish({
    required String topic,
    required String message,
    required PublishOptions options,
  }) async => published.add(options.correlationId!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
