import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/wallet_connection.dart';

/// Use fixture preflight facts but the actual signing, POST, journal and query
/// implementation. Every HTTP exchange is intercepted by MockClient.
class _SignedSubmissionRepository extends TestLiveOrderRepository {
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
  void Function(OrderRecoveryRecord)? afterPrepare;

  @override
  Future<void> prepare(OrderRecoveryRecord record) async {
    await super.prepare(record);
    afterPrepare?.call(record);
  }
}

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late _SignedSubmissionRepository orders;
  late AsterAccountService service;
  late _Journal journal;
  late List<http.Request> requests;
  late List<String> signedQueries;
  late Completer<void> prompting;
  Completer<void>? signatureGate;
  late DateTime now;
  var formCurrent = true, unknown = false;

  setUp(() async {
    now = liveOrderClock;
    formCurrent = true;
    unknown = false;
    signatureGate = null;
    prompting = Completer<void>();
    requests = [];
    signedQueries = [];
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = _SignedSubmissionRepository()..context = capacityContext();
    journal = _Journal();
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/fapi/v3/time') {
          return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
        }
        expect(request.url.path, '/fapi/v3/order');
        expect(request.followRedirects, false);
        if (unknown) return http.Response('{}', 504);
        return http.Response(
          jsonEncode(
            request.method == 'POST' ? {'orderId': 12345} : liveQueryPayload(orders.lastIntent!),
          ),
          200,
        );
      }),
    );
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderPricingProvider.overrideWith(fixtureBoundedPricing),
        mainOrderCapacityRepositoryProvider.overrideWithValue(TestCapacityRepository()),
        liveOrderClockProvider.overrideWithValue(() => now),
        orderRecoveryJournalProvider.overrideWithValue(journal),
      ],
    );
    orders.signed = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        signedQueries.add((typedData['message'] as Map)['msg'] as String);
        if (!prompting.isCompleted) prompting.complete();
        await signatureGate?.future;
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => now,
      journal: container.read(orderRecoveryJournalProvider),
    );
    container.read(mainOrderAllocationProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await container.read(mainOrderCapacityProvider.notifier).load('BTCUSDT');
    container.read(mainOrderAllocationProvider.notifier).selectPercent(20);
  });

  tearDown(() async {
    container.dispose();
    service.close();
    await journal.close();
    await identity.dispose();
  });

  MainOrderAllocationController allocation() =>
      container.read(mainOrderAllocationProvider.notifier);
  Iterable<http.Request> posts() => requests.where((r) => r.method == 'POST');

  for (final manual in [false, true]) {
    for (final change in ['form', 'expiry', 'stale', 'capacity']) {
      test(
        '${manual ? 'manual' : 'percentage'} actual signed POST is blocked after wallet return when $change changes',
        () async {
          if (manual) allocation().manual();
          final review = (await allocation().prepare(
            liveDraft(quantity: '2', price: '100'),
            isFormCurrent: () => formCurrent,
          ))!;
          signatureGate = Completer<void>();
          final submitting = allocation().submit(review);
          await prompting.future;
          expect(posts(), isEmpty);
          switch (change) {
            case 'form':
              formCurrent = false;
            case 'expiry':
              now = now.add(const Duration(seconds: 30));
            case 'stale':
              container.read(liveOrderProvider.notifier).markStale();
            case 'capacity':
              container.invalidate(mainOrderCapacityProvider);
          }
          signatureGate!.complete();
          await submitting;
          expect(posts(), isEmpty);
          expect(container.read(orderRecoveryJournalProvider).snapshot.records, isEmpty);
          expect(container.read(liveOrderProvider).failure!.key, 'liveOrderContextExpired');
          expect(container.read(mainOrderAllocationProvider).percent, manual ? null : 20);
        },
      );
    }

    for (final mode
        in manual
            ? LiveOrderEntryMode.values.where((mode) => mode.inline)
            : [LiveOrderEntryMode.limit]) {
      for (final buy in [true, false]) {
        test(
          '${manual ? 'manual' : 'percentage'} $mode actual signed $buy placement keeps frozen quantity, signer and original query ID',
          () async {
            if (manual) allocation().manual();
            final review = (await allocation().prepare(
              liveDraft(
                buy: buy,
                quantity: '2',
                price: mode.marketExecution ? '' : '100',
                market: mode.marketExecution,
                timeInForce: mode.defaultPolicy,
                trigger: mode.conditional
                    ? LiveOrderTrigger(
                        kind: LiveOrderTriggerKind.stop,
                        price: buy ? '110' : '90',
                        basis: LiveOrderTriggerBasis.mark,
                      )
                    : null,
                trailing: mode == LiveOrderEntryMode.trailing
                    ? const LiveOrderTrailing(callbackRate: '1', basis: LiveOrderTriggerBasis.mark)
                    : null,
              ),
              isFormCurrent: () => formCurrent,
            ))!;
            await allocation().submit(review);
            final sent = Uri.splitQueryString(posts().single.body);
            expect(sent['quantity'], '2');
            expect(sent['side'], buy ? 'BUY' : 'SELL');
            expect(sent['type'], review.intent.draft.orderType);
            if (mode == LiveOrderEntryMode.postOnly) expect(sent['timeInForce'], 'GTX');
            if (mode.conditional) {
              expect(sent['stopPrice'], buy ? '110' : '90');
              expect(sent['workingType'], 'MARK_PRICE');
            }
            if (mode == LiveOrderEntryMode.trailing) {
              expect(sent['callbackRate'], '1');
              expect(sent['workingType'], 'MARK_PRICE');
            }
            expect(sent['user'], accountAddress);
            expect(sent['signer'], accountAddress);
            expect(sent['newClientOrderId'], review.intent.clientOrderId);
            final query = requests.singleWhere(
              (r) => r.method == 'GET' && r.url.path == '/fapi/v3/order',
            );
            expect(query.url.queryParameters['origClientOrderId'], review.intent.clientOrderId);
            expect(signedQueries.first, posts().single.body.split('&signature=').first);
            expect(container.read(orderRecoveryJournalProvider).snapshot.records, isEmpty);
            expect(container.read(mainOrderAllocationProvider).percent, manual ? null : 0);
          },
        );
      }
    }
  }
  for (final change in ['storage', 'other-order']) {
    test('diagnostic $change does not block POST', () async {
      final review = (await allocation().prepare(
        liveDraft(quantity: '2', price: '100'),
        isFormCurrent: () => formCurrent,
      ))!;
      journal.afterPrepare = (own) {
        switch (change) {
          case 'storage':
            journal.publish(
              OrderRecoverySnapshot(
                records: [own],
                failure: const AccountReadFailure('orderRecoveryStorage'),
              ),
            );
          case 'other-order':
            final other = LiveOrderIntent(
              context: review.intent.context,
              draft: review.intent.draft,
              clientOrderId: 'vanta-other-request',
              revision: 0,
            );
            journal.publish(
              OrderRecoverySnapshot(
                records: [
                  own,
                  OrderRecoveryRecord(query: OrderQuery.capture(other), createdAt: now),
                ],
              ),
            );
        }
      };
      await allocation().submit(review);
      expect(posts().length, 1);
      expect(container.read(liveOrderProvider).needsRecheck, isFalse);
      expect(container.read(symbolSettingsActivityProvider).owner, isNull);
    });
  }

  for (final manual in [false, true]) {
    test(
      '${manual ? 'manual' : 'percentage'} actual unknown POST is journaled and recovery only queries its original ID',
      () async {
        if (manual) allocation().manual();
        final review = (await allocation().prepare(
          liveDraft(quantity: '2', price: '100'),
          isFormCurrent: () => formCurrent,
        ))!;
        unknown = true;
        await allocation().submit(review);
        expect(posts().length, 1);
        expect(container.read(liveOrderProvider).needsRecheck, true);
        expect(container.read(mainOrderAllocationProvider).percent, manual ? null : 20);
        expect(
          container.read(orderRecoveryJournalProvider).snapshot.records.single.query.clientOrderId,
          review.intent.clientOrderId,
        );
        unknown = false;
        await container.read(liveOrderProvider.notifier).recheck();
        expect(posts().length, 1);
        expect(container.read(liveOrderProvider).result!.orderId, '12345');
        expect(container.read(orderRecoveryJournalProvider).snapshot.records, isEmpty);
        expect(container.read(mainOrderAllocationProvider).percent, manual ? null : 0);
        for (final query in requests.where(
          (r) => r.method == 'GET' && r.url.path == '/fapi/v3/order',
        )) {
          expect(query.url.queryParameters['origClientOrderId'], review.intent.clientOrderId);
        }
      },
    );
  }
}
