import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_review_submission_provider.dart';
import 'package:vanta/features/portfolio/application/order_review_activity_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/main_order_allocation.dart';
import 'package:vanta/features/portfolio/domain/main_order_review_input.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';

void main() {
  late MainOrderLiveFixture f;
  late MainOrderAllocationReview original;
  setUp(() async {
    f = MainOrderLiveFixture();
    await f.open();
    f.allocation.manual();
    final draft = liveDraft(quantity: '0.1', price: '100');
    original = (await f.allocation.prepare(
      draft,
      isFormCurrent: () => true,
      input: MainOrderReviewInput(
        draft: draft,
        size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '0.1'),
      ),
    ))!;
    f.container.read(orderReviewActivityProvider.notifier).begin();
  });
  tearDown(() => f.close());

  Future<bool> renew() => f.container
      .read(mainOrderRefreshProvider.notifier)
      .refresh('BTCUSDT', reconnectPrices: false, background: true);
  Future<void> submit() =>
      f.container.read(mainOrderReviewSubmissionProvider.notifier).submit(original);

  test('waits for an active read, rejects duplicate clicks and submits once', () async {
    f.orders.readGate = Completer<void>();
    final polling = renew();
    await f.flush();
    final pending = submit();
    await f.flush();
    expect(f.container.read(mainOrderReviewSubmissionProvider), isTrue);
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(f.orders.submits, 0);
    f.orders.readGate!.complete();
    expect(await polling, isTrue);
    await pending;
    expect(f.orders.submits, 1);
    expect(f.orders.lastIntent!.clientOrderId, original.intent.clientOrderId);
    expect(f.container.read(mainOrderReviewSubmissionProvider), isFalse);
  });

  test('expired review renews on confirm without requiring another click', () async {
    f.now = f.now.add(const Duration(seconds: 31));
    f.orders.context = capacityContext(time: f.now);
    f.prices();
    await f.flush();
    await submit();
    expect(f.orders.submits, 1);
    expect(f.orders.lastIntent!.context.receivedAt, f.now);
  });

  test('read failure preserves the exact reason and never places an order', () async {
    f.orders.readGate = Completer<void>();
    final polling = renew();
    await f.flush();
    final pending = submit();
    const failure = AccountReadFailure(
      'accountReadFailed',
      code: -2019,
      details: ApiErrorDetails(message: 'Margin is insufficient.', status: 400),
    );
    f.orders.readFailure = failure;
    final expectation = expectLater(pending, throwsA(same(failure)));
    f.orders.readGate!.complete();
    expect(await polling, isFalse);
    await expectation;
    expect(f.orders.submits, 0);
    expect(f.container.read(mainOrderReviewSubmissionProvider), isFalse);
  });

  test('identity exit while waiting cannot submit old confirmation', () async {
    f.orders.readGate = Completer<void>();
    final polling = renew();
    await f.flush();
    final pending = submit();
    final expectation = expectLater(
      pending,
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await f.container.read(authProvider.notifier).logout();
    f.orders.readGate!.complete();
    await polling;
    await expectation;
    expect(f.orders.submits, 0);
    expect(f.container.read(mainOrderReviewSubmissionProvider), isFalse);
  });

  test('disposal while waiting releases the attempt and ignores late account data', () async {
    f.orders.readGate = Completer<void>();
    final polling = renew();
    await f.flush();
    final pending = submit();
    final expectation = expectLater(pending, throwsA(isA<AccountReadFailure>()));
    f.disposeContainer();
    await expectation;
    f.orders.readGate!.complete();
    await polling;
    await f.flush();
    expect(f.orders.submits, 0);
  });
}
