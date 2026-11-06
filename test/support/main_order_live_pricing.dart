import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';

import 'identity_repository.dart';
import 'aster_account.dart';
import 'live_order.dart';
import 'main_order_capacity.dart';
import 'main_order_revaluation.dart';

class PricingFeed<T> {
  PricingFeed(this.value);
  T value;
  int listeners = 0;
  final _events = StreamController<T>.broadcast();
  Stream<T> get stream => Stream.multi((out) {
    listeners++;
    final sub = _events.stream.listen(out.add, onError: out.addError);
    out.add(value);
    out.onCancel = () {
      listeners--;
      return sub.cancel();
    };
  });
  void emit(T next) {
    value = next;
    _events.add(next);
  }

  Future<void> close() => _events.close();
}

/// Uses the production pricing/preview/allocation providers and revaluation.
/// Only the signed account repository and public feed boundaries are replaced.
class MainOrderLiveFixture {
  MainOrderLiveFixture({TestLiveOrderRepository? orderRepository, AccountChangeRepository? changes})
    : orders = orderRepository ?? (TestLiveOrderRepository()..context = capacityContext()) {
    capacities.transform = (context) => withRevaluationFacts(
      assembledCapacity(context: context, payload: payload, receivedAt: now, now: now),
    );
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        marketSyncProvider.overrideWithValue(null),
        if (changes != null) accountChangeRepositoryProvider.overrideWithValue(changes),
        if (changes != null) accountChangeClockProvider.overrideWithValue(() => now),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderCapacityRepositoryProvider.overrideWithValue(capacities),
        liveOrderClockProvider.overrideWithValue(() => now),
        mainOrderMarksProvider.overrideWith((ref, symbols) {
          markScopes.add(symbols);
          return marks.stream;
        }),
        mainOrderQuotesProvider.overrideWith((ref, key) {
          quoteScopes.add(key);
          return quotes
              .putIfAbsent(
                key.symbol,
                () => PricingFeed(revaluationReference(symbol: key.symbol, time: now)),
              )
              .stream;
        }),
      ],
    );
  }
  DateTime now = liveOrderClock;
  final identity = TestIdentityRepository()..restored = signingIdentity;
  final TestLiveOrderRepository orders;
  final capacities = TestCapacityRepository();
  final payload = capacityAccountPayload();
  final marks = PricingFeed(revaluationMarks({'BTCUSDT': '100', 'ETHUSDT': '100'}));
  final quotes = <String, PricingFeed<OrderReferencePrices>>{};
  final markScopes = <String>[];
  final quoteScopes = <MainOrderQuoteKey>[];
  late final ProviderContainer container;
  ProviderSubscription<dynamic>? listener;
  MainOrderAllocationController get allocation =>
      container.read(mainOrderAllocationProvider.notifier);
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> open({bool capacity = true}) async {
    listener = container.listen(mainOrderPricingProvider, (_, _) {});
    container.read(mainOrderAllocationProvider);
    await flush();
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await flush();
    if (capacity) {
      await container.read(mainOrderCapacityProvider.notifier).load('BTCUSDT');
      await flush();
    }
  }

  void prices({
    String mark = '100',
    String last = '100',
    String bid = '99',
    String ask = '101',
    String eth = '100',
  }) {
    marks.emit(revaluationMarks({'BTCUSDT': mark, 'ETHUSDT': eth}, time: now));
    quotes['BTCUSDT']!.emit(revaluationReference(last: last, bid: bid, ask: ask, time: now));
    quotes['ETHUSDT']?.emit(revaluationReference(symbol: 'ETHUSDT', last: eth, time: now));
  }

  MainOrderRevaluation get valuation => container
      .read(mainOrderPricingProvider)
      .revalue(container.read(mainOrderCapacityProvider).snapshot!);
  bool _containerDisposed = false;
  void disposeContainer() {
    if (_containerDisposed) return;
    _containerDisposed = true;
    listener?.close();
    container.dispose();
  }

  Future<void> close() async {
    disposeContainer();
    await marks.close();
    for (final q in quotes.values) {
      await q.close();
    }
    await identity.dispose();
  }
}
