import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/market/data/mark_prices_repository.dart';
import 'package:vanta/features/market/data/order_reference_prices_repository.dart';

import '../../support/mark_prices.dart';
import '../../support/order_reference_prices.dart';

class ScopedMarks extends TestMarkService {
  final scopes = <RequestScope>[];
  @override
  Future<Object?> request(String path, [Map<String, String>? query]) {
    scopes.add(RequestScope.current!);
    return super.request(path, query);
  }
}

class ScopedReferences extends TestOrderPriceService {
  final scopes = <RequestScope>[];
  @override
  Future<Object?> request(String path, [Map<String, String>? query]) {
    scopes.add(RequestScope.current!);
    return super.request(path, query);
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('marks outlive the refresh that first subscribed, but stop with their owner', () async {
    final service = ScopedMarks();
    final repository = MarkPricesRepository(service, {'BTCUSDT'}, now: () => service.now);
    late StreamSubscription<Object?> sub;
    var caller = true;
    await RequestScope.run(() => caller, () async {
      sub = repository.events.listen((_) {});
      service.controllers.single.add({'connected': true});
      await flush();
    });
    caller = false;
    expect(service.scopes.single.active, isTrue);
    service.snapshots.single.complete([markPayload()]);
    await flush();
    expect(repository.state.fresh, {'BTCUSDT'});
    expect(repository.state.failure, isNull);
    await repository.setActive(false);
    expect(service.scopes.single.active, isFalse);
    await sub.cancel();
    await repository.dispose();
    await service.dispose();
  });

  test('book/trade bootstrap and subsequent reads do not inherit a finished caller', () async {
    final service = ScopedReferences();
    final repository = OrderReferencePricesRepository(service, 'BTCUSDT', now: () => service.now);
    late StreamSubscription<Object?> sub;
    var caller = true;
    await RequestScope.run(() => caller, () async {
      sub = repository.events.listen((_) {});
      service.controllers.single.add({'connected': true});
      await flush();
    });
    caller = false;
    expect(service.scopes.single.active, isTrue);
    service.clocks.single.complete({'serverTime': service.now.millisecondsSinceEpoch});
    await flush();
    expect(service.scopes.length, 3);
    expect(service.scopes.every((scope) => scope.active), isTrue);
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    expect(repository.state.bookFresh, isTrue);
    expect(repository.state.tradeFresh, isTrue);
    expect(repository.state.bookFailure, isNull);
    expect(repository.state.tradeFailure, isNull);
    await repository.setActive(false);
    expect(service.scopes.every((scope) => !scope.active), isTrue);
    await sub.cancel();
    await repository.dispose();
    await service.dispose();
  });
}
