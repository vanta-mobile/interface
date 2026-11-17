import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/open_interest_repository.dart';

void main() {
  test('bounds concurrent reads, hands slots over in order and settles after all', () async {
    final pending = <String, Completer<http.Response>>{};
    var peak = 0;
    final client = MockClient((request) {
      final symbol = request.url.queryParameters['symbol']!;
      expect(request.url.path, '/fapi/v3/openInterest');
      final completer = pending[symbol] = Completer<http.Response>();
      if (pending.values.where((c) => !c.isCompleted).length > peak) {
        peak = pending.values.where((c) => !c.isCompleted).length;
      }
      return completer.future;
    });
    final service = AsterService(client);
    addTearDown(() async {
      client.close();
      await service.dispose();
    });
    final repository = OpenInterestRepository(service, maxConcurrent: 2);
    final reads = {
      for (final s in ['AUSDT', 'BUSDT', 'CUSDT']) s: repository.read(s),
    };
    // Negative or mismatched payloads are malformed, never a zero value.
    final invalid = [
      expectLater(reads['BUSDT'], throwsA(isA<MarketFailure>())),
      expectLater(reads['CUSDT'], throwsA(isA<MarketFailure>())),
    ];
    var settled = false;
    unawaited(repository.settled().then((_) => settled = true));
    await pumpEventQueue();
    expect(pending.keys, ['AUSDT', 'BUSDT']);
    pending['AUSDT']!.complete(http.Response('{"symbol":"AUSDT","openInterest":"12.5"}', 200));
    await pumpEventQueue();
    expect(pending.keys, ['AUSDT', 'BUSDT', 'CUSDT']);
    pending['BUSDT']!.complete(http.Response('{"symbol":"BUSDT","openInterest":"-1"}', 200));
    await pumpEventQueue();
    expect(settled, isFalse);
    pending['CUSDT']!.complete(http.Response('{"symbol":"XUSDT","openInterest":"3"}', 200));
    expect(await reads['AUSDT'], Decimal.parse('12.5'));
    await Future.wait(invalid);
    await pumpEventQueue();
    expect(settled, isTrue);
    expect(peak, 2);
  });

  test('a read cancelled while queued never reaches the network', () async {
    final first = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((_) {
      requests++;
      return first.future;
    });
    final service = AsterService(client);
    addTearDown(() async {
      client.close();
      await service.dispose();
    });
    final repository = OpenInterestRepository(service, maxConcurrent: 1);
    final running = repository.read('AUSDT');
    var current = true;
    final queued = RequestScope.run(() => current, () => repository.read('BUSDT'));
    await pumpEventQueue();
    current = false;
    first.complete(http.Response('{"symbol":"AUSDT","openInterest":"1"}', 200));
    expect(await running, Decimal.one);
    await expectLater(queued, throwsA(isA<http.RequestAbortedException>()));
    expect(requests, 1);
    await repository.settled();
  });
}
