import 'package:vanta/core/errors/api_error_details.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_preview_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_revaluation.dart';

void main() {
  late MainOrderLiveFixture f;
  setUp(() => f = MainOrderLiveFixture());
  tearDown(() => f.close());
  Matcher fails(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'failure', key));

  test(
    'account renewal retains related subscriptions and can finish without replaying feed snapshots',
    () async {
      (f.payload['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
      await f.open();
      final scopes = List.of(f.markScopes);
      final quoteScopes = List.of(f.quoteScopes);
      f.now = f.now.add(const Duration(seconds: 3));
      f.orders.context = capacityContext(time: f.now);
      f.orders.readGate = Completer<void>();
      f.capacities.gate = Completer<void>();
      final renewal = f.container
          .read(mainOrderRefreshProvider.notifier)
          .refresh('BTCUSDT', reconnectPrices: false, background: true);
      await f.flush();
      expect(f.marks.listeners, 1);
      expect(f.quotes['BTCUSDT']!.listeners, 1);
      expect(f.quotes['ETHUSDT']!.listeners, 1);
      expect(f.markScopes, scopes);
      f.orders.readGate!.complete();
      await f.flush();
      expect(f.markScopes, scopes);
      expect(f.quoteScopes, quoteScopes);
      expect(f.quotes['ETHUSDT']!.listeners, 1);
      f.capacities.gate!.complete();
      expect(await renewal, isTrue);
      expect(f.markScopes, scopes);
      expect(f.quoteScopes, quoteScopes);
      expect(f.container.read(mainOrderRefreshProvider).failure, isNull);
    },
  );

  test(
    'failed account renewal keeps its typed server reason across an already stale anchor',
    () async {
      await f.open();
      f.container.read(liveOrderProvider.notifier).markStale();
      await f.flush();
      const failure = AccountReadFailure(
        'accountNetwork',
        code: -1001,
        details: ApiErrorDetails(message: 'Account service unavailable', status: 503),
      );
      f.orders.readFailure = failure;
      await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
      await f.flush();
      expect(
        () => f.container.read(mainOrderPricingProvider).priceContext(f.orders.context),
        throwsA(same(failure)),
      );
    },
  );
  test(
    'no account means no public subscriptions; selected pricing precedes explicit capacity',
    () async {
      final c = f.container;
      final sub = c.listen(mainOrderPricingProvider, (_, _) {});
      await f.flush();
      expect(f.markScopes, isEmpty);
      expect(f.quoteScopes, isEmpty);
      expect(f.capacities.reads, 0);
      await c.read(liveOrderProvider.notifier).load('BTCUSDT');
      await f.flush();
      final priced = c.read(mainOrderPricingProvider).priceContext(f.orders.context);
      expect(priced.markPrice, d('100'));
      expect(priced.lastPrice, d('100'));
      expect(f.markScopes, ['BTCUSDT']);
      expect(f.quoteScopes, [(symbol: 'BTCUSDT', book: true)]);
      expect(f.capacities.reads, 0);
      sub.close();
    },
  );
  test(
    'full scope includes nonzero related cross Last and isolated Mark, not zero configs',
    () async {
      (f.payload['positions'] as List).addAll(<Map<String, dynamic>>[
        capacityPosition(symbol: 'ETHUSDT', quantity: '1'),
        capacityPosition(symbol: 'SOLUSDT', quantity: '0'),
      ]);
      await f.open();
      expect(f.markScopes.last, 'BTCUSDT,ETHUSDT');
      expect(f.quoteScopes.toSet(), {
        (symbol: 'BTCUSDT', book: true),
        (symbol: 'ETHUSDT', book: false),
      });
      expect(f.valuation.availableMargin, d('140').toRational());
      f.prices(eth: '80');
      await f.flush();
      expect(f.valuation.availableMargin, d('122').toRational());
      expect(f.capacities.reads, 1);
    },
  );
  test(
    'cross exposure/percentage sides recompute from changing Last and Mark without signing',
    () async {
      final p = capacityAccountPayload();
      // Both signed context and fresh account share exactly one long position.
      (p['positions'] as List).single.addAll(capacityPosition(quantity: '1'));
      f.orders.context = capacityContext(payload: p);
      (f.payload['positions'] as List).single.addAll(capacityPosition(quantity: '1'));
      await f.open();
      final input = (
        context: f.orders.context,
        draft: liveDraft(price: '100'),
        unit: OrderSizeUnit.base,
        input: '',
        percent: 50,
      );
      final sub = f.container.listen(mainOrderCapacityPreviewProvider(input), (_, _) {});
      final before = f.container.read(mainOrderCapacityPreviewProvider(input))!;
      f.prices(mark: '120', last: '110');
      await f.flush();
      final after = f.container.read(mainOrderCapacityPreviewProvider(input))!;
      expect(f.valuation.availableMargin, d('148').toRational());
      expect(after.buy.capacity!.maximum, isNot(before.buy.capacity!.maximum));
      expect(after.buy.quantity, after.buy.capacity!.quantityAt(50));
      expect(after.sell.quantity, after.sell.capacity!.quantityAt(50));
      expect(f.capacities.reads, 1);
      sub.close();
    },
  );
  test(
    'manual market quote conversion follows each live book side before any capacity read',
    () async {
      await f.open(capacity: false);
      final input = (
        context: f.orders.context,
        draft: liveDraft(market: true, price: ''),
        unit: OrderSizeUnit.quote,
        input: '198',
        percent: null,
      );
      final sub = f.container.listen(mainOrderCapacityPreviewProvider(input), (_, _) {});
      f.prices(bid: '98', ask: '99');
      await f.flush();
      final v = f.container.read(mainOrderCapacityPreviewProvider(input))!;
      expect(v.buy.quantity, d('2'));
      expect(v.sell.quantity, d('2.02'));
      expect(v.buy.capacity, isNull);
      expect(f.capacities.reads, 0);
      sub.close();
    },
  );
  test('input quote timestamps advance independently of the original signed lease', () async {
    await f.open();
    final anchor = f.orders.context;
    f.now = f.now.add(const Duration(seconds: 3));
    f.prices();
    await f.flush();
    final priced = f.container.read(mainOrderPricingProvider).priceContext(anchor);
    final market = liveDraft(market: true, price: '');
    final size = const LiveOrderSize(
      unit: OrderSizeUnit.quote,
      text: '202',
    ).resolve(priced, market);
    expect(size.referenceAt, f.now);
    expect(priced.receivedAt, anchor.receivedAt);
    expect(priced.sameAccountAnchor(anchor), true);
    expect(orderSizeReferenceAt(priced, OrderSizeReference.mark), f.now);
    expect(orderSizeReferenceAt(priced, OrderSizeReference.last), f.now);
    final input = (
      context: anchor,
      draft: market,
      unit: OrderSizeUnit.quote,
      input: '',
      percent: 20,
    );
    final sub = f.container.listen(mainOrderCapacityPreviewProvider(input), (_, _) {});
    expect(f.container.read(mainOrderCapacityPreviewProvider(input))!.buy.size!.referenceAt, f.now);
    f.now = anchor.receivedAt.add(const Duration(seconds: 30));
    f.prices();
    await f.flush();
    expect(
      () => f.container.read(mainOrderPricingProvider).priceContext(anchor),
      fails('liveOrderContextExpired'),
    );
    sub.close();
  });
  for (final field in ['address', 'leverage', 'lease', 'positions']) {
    test('public repricing cannot substitute signed $field facts', () async {
      await f.open();
      final anchor = f.orders.context;
      final changed = LiveOrderContext(
        address: field == 'address' ? '0x0000000000000000000000000000000000000001' : anchor.address,
        rules: anchor.rules,
        mode: anchor.mode,
        marginMode: anchor.marginMode,
        leverage: field == 'leverage' ? anchor.leverage + 1 : anchor.leverage,
        markPrice: anchor.markPrice,
        receivedAt: field == 'lease'
            ? anchor.receivedAt.add(const Duration(seconds: 1))
            : anchor.receivedAt,
        positions: field == 'positions' ? {} : anchor.positions,
        bid: anchor.bid,
        ask: anchor.ask,
        lastPrice: anchor.lastPrice,
        funds: anchor.funds,
        fundsFailure: anchor.fundsFailure,
      );
      final draft = liveDraft(quantity: '1', price: '100');
      expect(
        f.container
            .read(liveOrderProvider.notifier)
            .prepare('BTCUSDT', draft, pricingContext: changed),
        isNull,
      );
      final intent = LiveOrderIntent(
        context: anchor,
        draft: draft,
        clientOrderId: 'frozen',
        revision: 0,
        pricingContext: changed,
      );
      expect(() => intent.executionContext, fails('liveCapacityChanged'));
      expect(f.orders.submits, 0);
    });
  }
  test(
    'live market book invalidates frozen protection without moving approved exit prices',
    () async {
      await f.open();
      f.allocation.manual();
      final review = (await f.allocation.prepare(
        liveDraft(
          market: true,
          price: '',
          quantity: '1',
          attachment: const LiveOrderAttachment(
            takeProfit: AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '110'),
          ),
        ),
        isFormCurrent: () => true,
      ))!;
      expect(f.allocation.matches(review), true);
      f.prices(bid: '110', ask: '111', mark: '100', last: '100');
      await f.flush();
      expect(f.allocation.matches(review), false);
      expect(review.intent.draft.attachment!.takeProfit!.price, '110');
      await f.allocation.submit(review);
      expect(f.orders.submits, 0);
    },
  );
  for (final change in ['mark', 'offline', 'pause', 'expired']) {
    test('frozen review becomes invalid for $change before submit', () async {
      // 1400 notional fits wallet150 at price100, then ceases to fit.
      await f.open();
      f.allocation.manual();
      final r = (await f.allocation.prepare(
        liveDraft(quantity: '14', price: '100'),
        isFormCurrent: () => true,
      ))!;
      expect(f.allocation.matches(r), true);
      switch (change) {
        case 'mark':
          f.prices(mark: '80', last: '80');
        case 'offline':
          f.marks.emit(MarkPrices());
        case 'pause':
          f.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
        case 'expired':
          f.now = f.now.add(const Duration(seconds: 30));
      }
      await f.flush();
      expect(f.allocation.matches(r), false);
      await f.allocation.submit(r);
      expect(f.orders.submits, 0);
    });
  }
  test(
    'wallet-return guard revalues frozen quantity and never enlarges it when balance grows',
    () async {
      await f.open();
      f.allocation.selectPercent(20);
      final r = (await f.allocation.prepare(
        liveDraft(quantity: '2', price: '100'),
        isFormCurrent: () => true,
      ))!;
      f.orders.submitGate = Completer<void>();
      final submitting = f.allocation.submit(r);
      await f.flush();
      // Flat position with Mark=120 has cheaper buy opening loss; the captured
      // two units must remain two even if the current maximum changes.
      f.prices(mark: '120', last: '120');
      await f.flush();
      expect(f.allocation.matches(r, submitting: true), true);
      f.orders.submitGate!.complete();
      await submitting;
      expect(f.orders.lastIntent!.draft.quantity, '2');
      expect(f.orders.lastIntent!.context, same(f.orders.context));
      expect(f.orders.lastIntent!.pricingContext, isNotNull);
    },
  );
  test('wallet-return guard rejects price-caused overcapacity without a submit event', () async {
    await f.open();
    f.allocation.manual();
    final r = (await f.allocation.prepare(
      liveDraft(quantity: '14', price: '100'),
      isFormCurrent: () => true,
    ))!;
    f.orders.submitGate = Completer<void>();
    final submitting = f.allocation.submit(r);
    await f.flush();
    f.prices(mark: '80', last: '80');
    await f.flush();
    expect(f.allocation.matches(r, submitting: true), false);
    f.orders.submitGate!.complete();
    await submitting;
    expect(f.container.read(liveOrderProvider).failure!.key, 'liveOrderContextExpired');
    expect(f.container.read(mainOrderAllocationProvider).percent, isNull);
  });
  test('current Last invalidates a Last-based trigger despite unchanged account anchor', () async {
    await f.open();
    f.allocation.manual();
    final r = (await f.allocation.prepare(
      liveDraft(
        quantity: '1',
        price: '110',
        trigger: const LiveOrderTrigger(
          kind: LiveOrderTriggerKind.stop,
          price: '110',
          basis: LiveOrderTriggerBasis.last,
        ),
      ),
      isFormCurrent: () => true,
    ))!;
    f.prices(last: '111');
    await f.flush();
    expect(f.allocation.matches(r), false);
    expect(r.intent.context.lastPrice, isNull);
    expect(r.intent.executionContext.lastPrice, d('100'));
  });
  for (final cancel in [false, true]) {
    test('fresh account waits for added related quote scope; cancel=$cancel', () async {
      await f.open(capacity: false);
      (f.payload['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
      f.quotes['ETHUSDT'] = PricingFeed(OrderReferencePrices(symbol: 'ETHUSDT', checkedAt: f.now));
      final pending = f.allocation.prepare(
        liveDraft(quantity: '1', price: '100'),
        isFormCurrent: () => true,
      );
      await f.flush();
      expect(f.container.read(mainOrderAllocationProvider).preparing, true);
      expect(f.capacities.reads, 1);
      if (cancel) f.allocation.stop();
      f.prices();
      final review = await pending;
      await f.flush();
      expect(review == null, cancel);
      expect(f.container.read(mainOrderAllocationProvider).preparing, false);
      expect(f.container.read(mainOrderAllocationProvider).review == null, cancel);
      expect(f.capacities.reads, 1);
    });
  }
  for (final issue in ['offline', 'failed', 'expired']) {
    test('related-price wait stops promptly for $issue', () async {
      await f.open(capacity: false);
      (f.payload['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
      f.quotes['ETHUSDT'] = PricingFeed(OrderReferencePrices(symbol: 'ETHUSDT', checkedAt: f.now));
      final pending = f.allocation.prepare(
        liveDraft(quantity: '1', price: '100'),
        isFormCurrent: () => true,
      );
      await f.flush();
      expect(f.container.read(mainOrderAllocationProvider).preparing, true);
      if (issue == 'expired') f.now = f.now.add(const Duration(seconds: 30));
      f.quotes['ETHUSDT']!.emit(
        OrderReferencePrices(
          symbol: 'ETHUSDT',
          checkedAt: f.now,
          connection: issue == 'offline'
              ? OrderPriceConnection.offline
              : OrderPriceConnection.connecting,
          tradeFailed: issue == 'failed',
        ),
      );
      expect(await pending.timeout(const Duration(seconds: 2)), isNull);
      expect(
        f.container.read(mainOrderAllocationProvider).failure!.key,
        issue == 'expired' ? 'liveOrderContextExpired' : 'liveCapacityPriceUnavailable',
      );
      expect(f.capacities.reads, 1);
    });
  }
  test('form edits cancel initial related-price wait without waiting for HTTP', () async {
    await f.open(capacity: false);
    (f.payload['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
    f.quotes['ETHUSDT'] = PricingFeed(OrderReferencePrices(symbol: 'ETHUSDT', checkedAt: f.now));
    var current = true;
    final pending = f.allocation.prepare(
      liveDraft(quantity: '1', price: '100'),
      isFormCurrent: () => current,
    );
    await f.flush();
    expect(f.container.read(mainOrderAllocationProvider).preparing, true);
    current = false;
    expect(await pending.timeout(const Duration(seconds: 2)), isNull);
    expect(f.container.read(mainOrderAllocationProvider).failure!.key, 'liveAllocationChanged');
    f.prices();
    await f.flush();
    expect(f.container.read(mainOrderAllocationProvider).review, isNull);
    expect(f.capacities.reads, 1);
  });
  test(
    'no one-second emission is needed for the final guard to notice ten-second expiry',
    () async {
      await f.open();
      final r = (await f.allocation.prepare(
        liveDraft(quantity: '1', price: '100'),
        isFormCurrent: () => true,
      ))!;
      f.now = f.now.add(const Duration(seconds: 10));
      expect(f.allocation.matches(r), false);
      expect(() => f.valuation, fails('liveCapacityPriceUnavailable'));
    },
  );
  test(
    'expected active order lease keeps public feeds active through wallet backgrounding',
    () async {
      await f.open();
      final activity = f.container.read(symbolSettingsActivityProvider.notifier);
      final lease = activity.acquire(SymbolSetting.order)!;
      f.container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      expect(f.container.read(mainOrderQuotesActiveProvider), true);
      expect(f.valuation.availableMargin, d('150').toRational());
      activity.finish(lease, unresolved: false);
      expect(f.container.read(mainOrderQuotesActiveProvider), false);
      expect(() => f.valuation, fails('liveCapacityPriceUnavailable'));
    },
  );
  test('switching symbol invalidates old public price/context bindings', () async {
    await f.open();
    final data = f.container.read(mainOrderPricingProvider);
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    await f.flush();
    expect(
      () => f.container.read(mainOrderPricingProvider).priceContext(f.orders.context),
      fails('liveCapacityPriceUnavailable'),
    );
    // A prior immutable observation does not acquire the new selected symbol.
    expect(data.priceContext(f.orders.context).symbol, 'BTCUSDT');
  });
}
