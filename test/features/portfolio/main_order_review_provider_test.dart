import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/main_order_review_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/main_order_review_input.dart';

import '../../support/live_order.dart';
import '../../support/main_order_live_pricing.dart';

void main() {
  late MainOrderLiveFixture f;
  setUp(() => f = MainOrderLiveFixture());
  tearDown(() => f.close());

  test('review follows quote units until confirm, then freezes the submitted quantity', () async {
    await f.open();
    f.allocation.manual();
    f.prices(bid: '98', ask: '99');
    await f.flush();
    final draft = liveDraft(market: true, price: '', quantity: '2');
    final original = (await f.allocation.prepare(
      draft,
      isFormCurrent: () => true,
      input: MainOrderReviewInput(
        draft: draft,
        size: const LiveOrderSize(unit: OrderSizeUnit.quote, text: '198'),
      ),
    ))!;
    final provider = mainOrderReviewProvider(original);
    final subscription = f.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    expect(f.container.read(provider).review!.intent.draft.quantity, '2');
    final reads = f.capacities.reads;
    f.prices(bid: '109', ask: '110', mark: '110', last: '110');
    await f.flush();
    final current = f.container.read(provider).review!;
    expect(current.intent.draft.quantity, '1.8');
    expect(current.side.size!.input.toString(), '198');
    expect(current.intent.clientOrderId, original.intent.clientOrderId);
    expect(original.intent.draft.quantity, '2');
    expect(f.capacities.reads, reads);
    f.orders.submitGate = Completer<void>();
    final submitting = f.allocation.submit(current);
    await f.flush();
    f.prices(bid: '99', ask: '100', mark: '100', last: '100');
    await f.flush();
    expect(f.container.read(provider).review, isNull);
    expect(f.orders.lastIntent!.draft.quantity, '1.8');
    f.orders.submitGate!.complete();
    await submitting;
    expect(f.orders.submits, 1);
    expect(f.orders.lastIntent!.draft.quantity, '1.8');
  });

  test('a changed market reports its concrete price filter failure', () async {
    await f.open();
    f.allocation.manual();
    final draft = liveDraft(quantity: '14', price: '100');
    final original = (await f.allocation.prepare(
      draft,
      isFormCurrent: () => true,
      input: MainOrderReviewInput(
        draft: draft,
        size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '14'),
      ),
    ))!;
    final provider = mainOrderReviewProvider(original);
    final subscription = f.container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    f.prices(mark: '95', last: '95');
    await f.flush();
    final current = f.container.read(provider);
    expect(current.review, isNull);
    expect(current.failure!.key, 'liveOrderPercentFilter');
    expect(f.orders.submits, 0);
  });
}
