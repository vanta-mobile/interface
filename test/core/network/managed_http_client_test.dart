import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/network/managed_http_client.dart';
import 'package:vanta/core/network/request_scope.dart';

class _Transport extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final responses = <Completer<http.StreamedResponse>>[];
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    unawaited(request.finalize().drain<void>());
    final response = Completer<http.StreamedResponse>();
    responses.add(response);
    return response.future;
  }

  @override
  void close() => closes++;
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('successful completion never signals request abortion', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport);
    addTearDown(client.close);
    var aborted = false;
    final result = client.get(Uri.https('example.com'));
    await _turn();
    (transport.requests.single as http.Abortable).abortTrigger!.then((_) => aborted = true);
    transport.responses.single.complete(http.StreamedResponse(Stream.value([1, 2]), 200));
    expect((await result).bodyBytes, [1, 2]);
    await _turn();
    client.close();
    await _turn();
    expect(aborted, isFalse);
  });

  test('invalid scope prevents any request reaching the transport', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport);
    addTearDown(client.close);
    await expectLater(
      RequestScope.run(() => false, () => client.get(Uri.https('example.com'))),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(transport.requests, isEmpty);
  });

  test('scope cancellation aborts before headers and rejects late responses', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport);
    addTearDown(client.close);
    var current = true, aborted = false, discarded = false;
    final request = RequestScope.run(() => current, () => client.get(Uri.https('example.com')));
    final failure = expectLater(request, throwsA(isA<http.RequestAbortedException>()));
    await _turn();
    (transport.requests.single as http.Abortable).abortTrigger!.then((_) => aborted = true);
    current = false;
    await failure;
    await (transport.requests.single as http.Abortable).abortTrigger;
    await _turn();
    expect(aborted, isTrue);
    final body = StreamController<List<int>>(onCancel: () => discarded = true);
    transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
    await _turn();
    expect(discarded, isTrue);
    await body.close();
  });

  test('scope cancellation interrupts an already streaming response body', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport);
    addTearDown(client.close);
    var current = true, cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final request = RequestScope.run(() => current, () => client.get(Uri.https('example.com')));
    final failure = expectLater(request, throwsA(isA<http.RequestAbortedException>()));
    await _turn();
    transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
    body.add(utf8.encode('partial'));
    await _turn();
    current = false;
    await failure;
    expect(cancelled, isTrue);
    await body.close();
  });

  for (final headersReceived in [false, true]) {
    test('timeout aborts ${headersReceived ? 'body' : 'header'} wait', () async {
      final transport = _Transport();
      final client = ManagedHttpClient(transport, timeout: const Duration(milliseconds: 50));
      addTearDown(client.close);
      final request = client.get(Uri.https('example.com'));
      final failure = expectLater(request, throwsA(isA<TimeoutException>()));
      await _turn();
      final body = StreamController<List<int>>();
      if (headersReceived) {
        transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
      }
      await failure;
      expect((transport.requests.single as http.Abortable).abortTrigger, completes);
      if (!headersReceived) {
        transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
      }
      await _turn();
      await body.close();
    });
  }

  test('explicit abort trigger remains effective through the wrapper', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport);
    addTearDown(client.close);
    final abort = Completer<void>();
    final result = client.send(
      http.AbortableRequest('GET', Uri.https('example.com'), abortTrigger: abort.future),
    );
    final failure = expectLater(result, throwsA(isA<http.RequestAbortedException>()));
    await _turn();
    abort.complete();
    await failure;
  });

  test('closing a borrowed client aborts only its requests without closing parent', () async {
    final transport = _Transport();
    final a = ManagedHttpClient(transport, ownsClient: false);
    final b = ManagedHttpClient(transport, ownsClient: false);
    addTearDown(b.close);
    final first = a.get(Uri.https('example.com', '/a'));
    final failure = expectLater(first, throwsA(isA<http.RequestAbortedException>()));
    final second = b.get(Uri.https('example.com', '/b'));
    await _turn();
    a.close();
    await failure;
    transport.responses[1].complete(http.StreamedResponse(Stream.value(utf8.encode('ok')), 200));
    expect((await second).body, 'ok');
    expect(transport.closes, 0);
    await expectLater(a.get(Uri.https('example.com')), throwsA(isA<http.ClientException>()));
  });

  test('response size limit aborts while reading, before buffering entire body', () async {
    final transport = _Transport();
    final client = ManagedHttpClient(transport, maxResponseBytes: 3);
    addTearDown(client.close);
    final result = client.get(Uri.https('example.com'));
    final failure = expectLater(result, throwsA(isA<http.ClientException>()));
    await _turn();
    transport.responses.single.complete(http.StreamedResponse(Stream.value([1, 2, 3, 4]), 200));
    await failure;
  });

  test('real native transport aborts a stalled local HTTP request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<HttpRequest>();
    final listener = server.listen(received.complete);
    final client = ManagedHttpClient(http.Client(), timeout: const Duration(seconds: 2));
    addTearDown(() async {
      client.close();
      await listener.cancel();
      await server.close(force: true);
    });
    var current = true;
    final result = RequestScope.run(
      () => current,
      () => client.get(Uri.parse('http://127.0.0.1:${server.port}/stall')),
    );
    final failure = expectLater(result, throwsA(isA<http.RequestAbortedException>()));
    final incoming = await received.future;
    current = false;
    await failure;
    // The native http client also received the abort signal; no server response
    // was required to release the operation.
    unawaited(incoming.response.close().catchError((Object _) {}));
  });
}
