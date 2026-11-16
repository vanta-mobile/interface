// ignore_for_file: depend_on_referenced_packages, implementation_imports
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_core/relay_client/json_rpc_2/src/client.dart';
import 'package:reown_core/relay_client/json_rpc_2/src/exception.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  late Client client;
  late StreamChannelController<String> channel;
  late List<Map<String, dynamic>> requests;
  setUp(() {
    channel = StreamChannelController<String>();
    client = Client(channel.local);
    requests = [];
    channel.foreign.stream.listen((message) {
      requests.add(jsonDecode(message) as Map<String, dynamic>);
    });
    unawaited(client.listen());
  });
  tearDown(() async => client.close());

  void reply(Object? id, {Object? result, Map<String, Object?>? error}) {
    channel.foreign.sink.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        if (error == null) 'result': result else 'error': error,
      }),
    );
  }

  for (final method in ['irn_subscribe', 'irn_publish', 'wc_proposeSession']) {
    test('$method resolves a string request ID echoed as a native integer', () async {
      const id = '1794812345678000123';
      final pending = client.sendRequest(method, <String, Object?>{}, id);
      await pumpEventQueue();
      expect(requests.single['id'], id);
      reply(int.parse(id), result: true);
      expect(await pending.timeout(const Duration(seconds: 1)), true);
      expect(requests, hasLength(1));
    });
  }

  test('integer response errors retain the actual code/message and never resend', () async {
    const id = '1794812345678000123';
    final pending = expectLater(
      client
          .sendRequest('wc_proposeSession', <String, Object?>{}, id)
          .timeout(const Duration(seconds: 1)),
      throwsA(
        isA<RpcException>()
            .having((e) => e.code, 'code', -32500)
            .having((e) => e.message, 'message', 'Invalid request ID'),
      ),
    );
    reply(int.parse(id), error: {'code': -32500, 'message': 'Invalid request ID'});
    await pending;
    expect(requests, hasLength(1));
  });

  test('adjacent 19-digit IDs stay distinct without floating point conversion', () async {
    const firstId = '1794812345678000123', secondId = '1794812345678000124';
    final first = client.sendRequest('irn_publish', <String, Object?>{}, firstId);
    final second = client.sendRequest('irn_publish', <String, Object?>{}, secondId);
    reply(int.parse(secondId), result: 'second');
    reply(int.parse(firstId), result: 'first');
    expect(await Future.wait([first, second]).timeout(const Duration(seconds: 1)), [
      'first',
      'second',
    ]);
  });

  test('exact ID types win when both integer and decimal string keys exist', () async {
    final number = client.sendRequest('fixture', <String, Object?>{}, 42);
    final string = client.sendRequest('fixture', <String, Object?>{}, '42');
    reply(42, result: 'integer');
    reply('42', result: 'string');
    expect(await Future.wait([number, string]), ['integer', 'string']);
  });

  test('string echoes and legacy integer requests remain compatible', () async {
    const id = '1794812345678000123';
    final string = client.sendRequest('fixture', <String, Object?>{}, id);
    final legacy = client.sendRequest('fixture', <String, Object?>{}, 42);
    reply(id, result: 'exact');
    reply('42', result: 'legacy');
    expect(await Future.wait([string, legacy]), ['exact', 'legacy']);
  });

  test('rounded doubles and unrelated IDs cannot settle the current request', () async {
    const id = '1794812345678000123';
    var completed = false;
    final pending = client.sendRequest('irn_publish', <String, Object?>{}, id).then((value) {
      completed = true;
      return value;
    });
    reply(int.parse(id).toDouble(), result: 'wrong');
    reply(null, result: 'wrong');
    reply('invalid', result: 'wrong');
    reply(int.parse(id) - 1, result: 'wrong');
    await pumpEventQueue();
    expect(completed, false);
    reply(int.parse(id), result: 'correct');
    expect(await pending.timeout(const Duration(seconds: 1)), 'correct');
  });
}
