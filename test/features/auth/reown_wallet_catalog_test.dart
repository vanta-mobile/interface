import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/modal/services/explorer_service/wallet_catalog_request.dart';

void main() {
  for (final sendHeaders in [false, true]) {
    test(
      'catalog timeout aborts ${sendHeaders ? 'the response body' : 'before headers'}',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final client = http.Client();
        addTearDown(client.close);
        final started = Completer<void>();
        final disconnected = Completer<void>();
        server.listen((request) async {
          if (request.uri.path == '/healthy') {
            request.response.write('ready');
            await request.response.close();
            return;
          }
          // Observe the peer closing the response on cancellation.
          final socket = await request.response.detachSocket(writeHeaders: false);
          socket.listen(
            (_) {},
            onDone: () {
              if (!disconnected.isCompleted) disconnected.complete();
              socket.destroy();
            },
          );
          if (sendHeaders) {
            socket.write('HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\npartial');
            await socket.flush();
          }
          started.complete();
        });
        final pending = expectLater(
          fetchWalletCatalog(
            client: client,
            uri: Uri.parse('http://127.0.0.1:${server.port}/stalled'),
            headers: const {},
            timeout: const Duration(milliseconds: 300),
          ),
          throwsA(isA<TimeoutException>()),
        );
        await started.future;
        final concurrent = await fetchWalletCatalog(
          client: client,
          uri: Uri.parse('http://127.0.0.1:${server.port}/healthy'),
          headers: const {},
        );
        expect(concurrent.body, 'ready');
        await pending;
        await disconnected.future.timeout(const Duration(seconds: 2));
        final next = await fetchWalletCatalog(
          client: client,
          uri: Uri.parse('http://127.0.0.1:${server.port}/healthy'),
          headers: const {},
        );
        expect(next.body, 'ready');
      },
    );
  }
}
