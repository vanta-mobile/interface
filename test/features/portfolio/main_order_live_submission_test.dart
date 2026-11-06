import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/trade/application/trading_lifecycle_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/live_order.dart';
import '../../support/account_changes.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/wallet_connection.dart';

class _Repository extends TestLiveOrderRepository {
  late SignedLiveOrderRepository signed;
  @override
  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) {
    lastIntent = intent;
    return signed.submit(
      intent: intent,
      isCurrent: isCurrent,
      canSubmit: canSubmit,
      onStep: onStep,
    );
  }
}

void main() {
  late MainOrderLiveFixture f;
  late _Repository orders;
  late AsterAccountService service;
  late MemoryOrderRecoveryJournal journal;
  late Completer<void> prompting, gate;
  late List<http.Request> requests;
  late List<String> signatures;
  late TestAccountChangeRepository changes;
  setUp(() async {
    orders = _Repository()..context = capacityContext();
    changes = TestAccountChangeRepository()..now = liveOrderClock;
    f = MainOrderLiveFixture(orderRepository: orders, changes: changes);
    prompting = Completer<void>();
    gate = Completer<void>();
    requests = [];
    signatures = [];
    journal = MemoryOrderRecoveryJournal();
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path == '/fapi/v3/time') {
          return http.Response(jsonEncode({'serverTime': f.now.millisecondsSinceEpoch}), 200);
        }
        expect(r.url.path, '/fapi/v3/order');
        expect(r.followRedirects, false);
        return http.Response(
          jsonEncode(
            r.method == 'POST' ? {'orderId': 12345} : liveQueryPayload(orders.lastIntent!),
          ),
          200,
        );
      }),
    );
    orders.signed = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        signatures.add((typedData['message'] as Map)['msg'] as String);
        if (!prompting.isCompleted) prompting.complete();
        await gate.future;
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => f.now,
      journal: journal,
    );
    f.container.read(authProvider);
    await f.flush();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.single.add(const AccountChangeEvent.connected());
    f.container.listen(tradingLifecycleProvider, (_, _) {});
    await f.open();
    f.allocation.manual();
  });
  tearDown(() async {
    await f.close();
    await changes.dispose();
    service.close();
    await journal.close();
  });
  Iterable<http.Request> posts() => requests.where((r) => r.method == 'POST');

  test(
    'wallet pause and resume with private monitoring retains the order and sends exactly once',
    () async {
      final review = (await f.allocation.prepare(
        liveDraft(quantity: '2', price: '100'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      final lifecycle = f.container.read(tradingLifecycleProvider);
      lifecycle.onChanged(AppLifecycleState.inactive);
      lifecycle.onChanged(AppLifecycleState.hidden);
      lifecycle.onChanged(AppLifecycleState.paused);
      lifecycle.onChanged(AppLifecycleState.resumed);
      await f.flush();
      expect(changes.canceled, 0);
      expect(changes.channels.length, 1);
      expect(f.identity.initializations, 1);
      expect(f.container.read(authProvider).busy, false);
      expect(f.container.read(liveOrderProvider).stale, false);
      expect(f.allocation.matches(review, submitting: true), true);
      gate.complete();
      await submit;
      await f.flush();
      expect(posts().length, 1);
      expect(Uri.splitQueryString(posts().single.body)['quantity'], '2');
      expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
      expect(f.identity.initializations, 2);
      expect(changes.authorizations, 1);
      expect(journal.snapshot.records, isEmpty);
    },
  );

  for (final reason in [
    'accountEvent',
    'disconnect',
    'expiry',
    'logout',
    'walletChange',
    'signingLost',
    'accountDeadline',
    'quoteDeadline',
  ]) {
    test('wallet return does not forgive $reason and no signed order is posted', () async {
      final review = (await f.allocation.prepare(
        liveDraft(quantity: '2', price: '100'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      final lifecycle = f.container.read(tradingLifecycleProvider);
      lifecycle.onChanged(AppLifecycleState.paused);
      switch (reason) {
        case 'accountEvent':
          changes.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, f.now));
        case 'disconnect':
          changes.channels.single.addError(StateError('synthetic disconnect'));
        case 'expiry':
          changes.channels.single.add(const AccountChangeEvent.expired());
        case 'logout':
          f.identity.events.add(null);
        case 'walletChange':
          f.identity.events.add(
            const AuthIdentity(
              id: 'other-wallet',
              walletAddress: '0x2222222222222222222222222222222222222222',
              walletKind: WalletKind.external,
              signingAvailable: true,
            ),
          );
        case 'signingLost':
          final original = f.container.read(authProvider).identity!;
          f.identity.events.add(
            AuthIdentity(
              id: original.id,
              walletAddress: original.walletAddress,
              walletKind: original.walletKind,
            ),
          );
        case 'accountDeadline':
          f.now = f.now.add(const Duration(seconds: 30));
          f.prices();
        case 'quoteDeadline':
          f.now = f.now.add(const Duration(seconds: 10));
      }
      lifecycle.onChanged(AppLifecycleState.resumed);
      await f.flush();
      gate.complete();
      await submit;
      expect(posts(), isEmpty);
      expect(journal.snapshot.records, isEmpty);
      expect(changes.authorizations, 1);
    });
  }

  for (final reason in ['overcapacity', 'expiredPrices', 'staleAccount']) {
    test('actual POST and journal creation stop after wallet return for $reason', () async {
      final review = (await f.allocation.prepare(
        liveDraft(quantity: '14', price: '100'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      expect(posts(), isEmpty);
      switch (reason) {
        case 'overcapacity':
          f.prices(mark: '80', last: '80');
          await f.flush();
        case 'expiredPrices':
          f.now = f.now.add(const Duration(seconds: 10));
        case 'staleAccount':
          f.container.read(liveOrderProvider.notifier).markStale();
      }
      gate.complete();
      await submit;
      expect(posts(), isEmpty);
      expect(journal.snapshot.records, isEmpty);
      expect(f.container.read(liveOrderProvider).failure!.key, 'liveOrderContextExpired');
    });
  }
  test(
    'actual signed POST freezes base quantity even when quotes change during the wallet prompt',
    () async {
      final review = (await f.allocation.prepare(
        liveDraft(quantity: '2', price: '100'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      f.prices(mark: '120', last: '120');
      await f.flush();
      gate.complete();
      await submit;
      final query = Uri.splitQueryString(posts().single.body);
      expect(query['quantity'], '2');
      expect(query['newClientOrderId'], review.intent.clientOrderId);
      expect(signatures.length, 2);
      expect(journal.snapshot.records, isEmpty);
      expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
    },
  );
  test('current Last validates conditional order even when original anchor had no Last', () async {
    final review = (await f.allocation.prepare(
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
    expect(review.intent.context.lastPrice, isNull);
    final submit = f.allocation.submit(review);
    await prompting.future;
    gate.complete();
    await submit;
    final query = Uri.splitQueryString(posts().single.body);
    expect(query['workingType'], 'CONTRACT_PRICE');
    expect(query['stopPrice'], '110');
    expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
  });
  test('Last crossing conditional trigger during signature prevents the actual POST', () async {
    final review = (await f.allocation.prepare(
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
    final submit = f.allocation.submit(review);
    await prompting.future;
    f.prices(last: '111');
    await f.flush();
    gate.complete();
    await submit;
    expect(posts(), isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
}
