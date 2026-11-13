import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_revaluation.dart';
import '../../support/wallet_connection.dart';

/// Production signed submission/recovery; only context reads, wallet signatures
/// and HTTP responses are synthetic. No platform or wallet requests are sent.
class _Orders extends TestLiveOrderRepository {
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

  @override
  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) => signed.recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
}

class _Journal extends MemoryOrderRecoveryJournal {
  Future<void> Function()? afterPrepare;
  @override
  Future<void> prepare(OrderRecoveryRecord record) async {
    await super.prepare(record);
    await afterPrepare?.call();
  }
}

void main() {
  late MainOrderLiveFixture f;
  late _Orders orders;
  late AsterAccountService service;
  late _Journal journal;
  late Completer<void> prompting, gate;
  late List<http.Request> requests;
  late List<String> signatures;
  bool queryUnavailable = false, postTimeout = false;
  String? returnedPeg;
  setUp(() async {
    queryUnavailable = postTimeout = false;
    returnedPeg = null;
    orders = _Orders()..context = capacityContext();
    f = MainOrderLiveFixture(orderRepository: orders);
    prompting = Completer<void>();
    gate = Completer<void>();
    requests = [];
    signatures = [];
    journal = _Journal();
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path == '/fapi/v3/time') {
          return http.Response(jsonEncode({'serverTime': f.now.millisecondsSinceEpoch}), 200);
        }
        expect(r.url.path, '/fapi/v3/order');
        expect(r.followRedirects, false);
        if (r.method == 'POST') {
          if (postTimeout) throw TimeoutException('Synthetic unknown write');
          return http.Response('{"orderId":12345}', 200);
        }
        if (queryUnavailable) return http.Response('{}', 503);
        final payload = liveQueryPayload(orders.lastIntent!)..['price'] = '100.5';
        if (returnedPeg != null) payload['pegPriceType'] = returnedPeg;
        return http.Response(jsonEncode(payload), 200);
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
    await f.open();
    f.allocation.manual();
  });
  tearDown(() async {
    await f.close();
    service.close();
    await journal.close();
  });
  Iterable<http.Request> posts() => requests.where((r) => r.method == 'POST');

  for (final peg in LiveOrderPeg.values) {
    for (final buy in [true, false]) {
      test(
        'signed BBO $peg side=$buy keeps wire zero and frozen size across book movement',
        () async {
          final review = (await f.allocation.prepare(
            liveDraft(price: '', peg: peg, buy: buy, quantity: '2'),
            isFormCurrent: () => true,
          ))!;
          final submit = f.allocation.submit(review);
          await prompting.future;
          f.prices(bid: '100', ask: '102');
          await f.flush();
          expect(f.allocation.matches(review, submitting: true), true);
          gate.complete();
          await submit;
          final wire = Uri.splitQueryString(posts().single.body);
          expect(wire['price'], '0');
          expect(wire['pegPriceType'], peg.wire);
          expect(wire['quantity'], '2');
          expect(wire['side'], buy ? 'BUY' : 'SELL');
          expect(wire['newClientOrderId'], review.intent.clientOrderId);
          expect(Uri.splitQueryString(signatures.first)['price'], '0');
          expect(signatures.length, 2);
          expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
          expect(journal.snapshot.records, isEmpty);
        },
      );
      test('signed BBO $peg side=$buy rejects newly insufficient capacity without POST', () async {
        final review = (await f.allocation.prepare(
          liveDraft(price: '', peg: peg, buy: buy, quantity: '10'),
          isFormCurrent: () => true,
        ))!;
        final submit = f.allocation.submit(review);
        await prompting.future;
        // Current Mark stays100: movement in the selected BBO alone is enough
        // to invalidate the previously affordable frozen10 units.
        if (buy) {
          f.prices(bid: '199', ask: '201');
        } else {
          f.prices(bid: '49', ask: '51');
        }
        await f.flush();
        expect(f.allocation.matches(review, submitting: true), false);
        gate.complete();
        await submit;
        expect(posts(), isEmpty);
        expect(journal.snapshot.records, isEmpty);
        expect(f.container.read(liveOrderProvider).failure!.key, 'liveOrderContextExpired');
      });
    }
  }
  for (final reason in ['bookMissing', 'bookExpired', 'accountExpired']) {
    test('BBO signing $reason never sends the old quote as a fixed order', () async {
      final review = (await f.allocation.prepare(
        liveDraft(price: '', peg: LiveOrderPeg.queue, quantity: '2'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      if (reason == 'bookMissing') {
        f.quotes['BTCUSDT']!.emit(revaluationReference(bid: '0'));
      } else {
        f.now = f.now.add(Duration(seconds: reason == 'bookExpired' ? 10 : 30));
        if (reason == 'accountExpired') f.prices();
      }
      await f.flush();
      gate.complete();
      await submit;
      expect(posts(), isEmpty);
      expect(journal.snapshot.records, isEmpty);
    });
  }
  // Order records are best-effort diagnostics: journal I/O never delays
  // dispatch (docs/implementation.md, 2026-11-11 "Make order records
  // observational and nonblocking"). A later book change cannot resend.
  test('BBO dispatch is not delayed by recovery journal I/O and is sent once', () async {
    final persisted = Completer<void>(), release = Completer<void>();
    journal.afterPrepare = () async {
      persisted.complete();
      await release.future;
    };
    final review = (await f.allocation.prepare(
      liveDraft(price: '', peg: LiveOrderPeg.queue, quantity: '10'),
      isFormCurrent: () => true,
    ))!;
    final submit = f.allocation.submit(review);
    await prompting.future;
    gate.complete();
    await persisted.future;
    expect(journal.snapshot.records.length, 1);
    await f.flush();
    expect(posts().length, 1);
    f.prices(bid: '200', ask: '201');
    await f.flush();
    release.complete();
    await submit;
    expect(posts().length, 1);
    expect(journal.snapshot.records, isEmpty);
  });
  test(
    'BBO quantity is not resized if a changed quote exceeds capacity before confirmation',
    () async {
      final review = (await f.allocation.prepare(
        liveDraft(price: '', peg: LiveOrderPeg.counterparty, quantity: '10.000'),
        isFormCurrent: () => true,
      ))!;
      f.prices(bid: '199', ask: '201');
      await f.flush();
      await f.allocation.submit(review);
      expect(review.intent.draft.quantity, '10.000');
      expect(signatures, isEmpty);
      expect(posts(), isEmpty);
    },
  );
  test('changing BBO form terms during wallet signing prevents POST', () async {
    var formCurrent = true;
    final review = (await f.allocation.prepare(
      liveDraft(price: '', peg: LiveOrderPeg.counterparty, quantity: '2'),
      isFormCurrent: () => formCurrent,
    ))!;
    final submit = f.allocation.submit(review);
    await prompting.future;
    formCurrent = false;
    gate.complete();
    await submit;
    expect(posts(), isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  test(
    'conditional BBO preserves trigger, peg and zero price after fresh capacity review',
    () async {
      final review = (await f.allocation.prepare(
        liveDraft(
          price: '',
          peg: LiveOrderPeg.counterparty,
          quantity: '2',
          trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '120'),
        ),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      gate.complete();
      await submit;
      final wire = Uri.splitQueryString(posts().single.body);
      expect(wire['stopPrice'], '120');
      expect(wire['type'], 'STOP');
      expect(wire['price'], '0');
      expect(wire['pegPriceType'], 'COUNTERPARTY_1');
      expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
    },
  );
  for (final reason in ['queryFailed', 'postTimeout', 'wrongPeg']) {
    test('BBO $reason keeps original journal and recovery only GETs original ID', () async {
      queryUnavailable = reason != 'wrongPeg';
      postTimeout = reason == 'postTimeout';
      if (reason == 'wrongPeg') returnedPeg = 'COUNTERPARTY_1';
      final review = (await f.allocation.prepare(
        liveDraft(price: '', peg: LiveOrderPeg.queue, quantity: '2'),
        isFormCurrent: () => true,
      ))!;
      final submit = f.allocation.submit(review);
      await prompting.future;
      gate.complete();
      await submit;
      expect(posts().length, 1);
      expect(f.container.read(liveOrderProvider).needsRecheck, true);
      expect(journal.snapshot.records.single.query.clientOrderId, review.intent.clientOrderId);
      expect(journal.snapshot.records.single.query.draft.peg, LiveOrderPeg.queue);
      expect(journal.snapshot.records.single.query.draft.price, '');
      queryUnavailable = false;
      returnedPeg = null;
      f.prices(bid: '200', ask: '201');
      await f.flush();
      await f.container.read(liveOrderProvider.notifier).recheck();
      expect(posts().length, 1);
      expect(f.container.read(liveOrderProvider).result!.status, 'NEW');
      expect(journal.snapshot.records, isEmpty);
      final query = requests.lastWhere((r) => r.url.path == '/fapi/v3/order').url.queryParameters;
      expect(query['origClientOrderId'], review.intent.clientOrderId);
    });
  }
  test('BBO rejects capacity drop at the fresh read and retains clicked quantity', () async {
    f.capacities.transform = (context) {
      final payload = capacityAccountPayload();
      (payload['assets'] as List).single['availableBalance'] = '1';
      return withRevaluationFacts(
        assembledCapacity(context: context, payload: payload),
        payload: {
          ...payload,
          'assets': [
            {...capacityAsset(), 'crossWalletBalance': '1'},
          ],
        },
      );
    };
    final draft = liveDraft(price: '', peg: LiveOrderPeg.counterparty, quantity: '2.000');
    expect(await f.allocation.prepare(draft, isFormCurrent: () => true), null);
    expect(f.container.read(liveOrderProvider).intent, null);
    expect(posts(), isEmpty);
    expect(signatures, isEmpty);
    expect(draft.quantity, '2.000');
    expect(f.allocation.state.failure!.key, 'liveCapacityAboveMaximum');
  });
}
