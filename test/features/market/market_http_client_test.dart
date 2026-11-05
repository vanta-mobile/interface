import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/features/market/data/market_http_client.dart';

void main() {
  test('chart HTTP survives a reading pause longer than Dart default idle timeout', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ports = <String, List<int>>{};
    final subscription = server.listen((request) async {
      ports.putIfAbsent(request.uri.path, () => []).add(request.connectionInfo!.remotePort);
      request.response.write('ok');
      await request.response.close();
    });
    final market = createMarketHttpClient();
    final defaults = http.Client();
    addTearDown(() async {
      market.close();
      defaults.close();
      await server.close(force: true);
      await subscription.cancel();
    });
    final base = 'http://${server.address.address}:${server.port}';
    Future<void> requestBoth() async {
      final responses = await Future.wait([
        market.get(Uri.parse('$base/market')),
        defaults.get(Uri.parse('$base/default')),
      ]);
      expect(responses.map((r) => r.body), ['ok', 'ok']);
    }

    await requestBoth();
    await Future<void>.delayed(const Duration(seconds: 16));
    await requestBoth();
    expect(
      ports['/default']!.toSet(),
      hasLength(2),
      reason: 'Control confirms the idle boundary was crossed',
    );
    expect(
      ports['/market']!.toSet(),
      hasLength(1),
      reason: 'A chart selection should reuse its healthy connection',
    );
  });
}
