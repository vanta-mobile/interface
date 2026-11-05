import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_order_query_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

class DelayedJournal extends MemoryOrderRecoveryJournal {
  final gate = Completer<void>();
  @override
  Future<void> prepare(OrderRecoveryRecord record) async {
    await super.prepare(record);
    await gate.future;
  }
}

void main() {
  late Directory directory;
  late FileOrderRecoveryJournal journal;
  late AsterAccountService service;
  late LiveOrderIntent intent;
  late List<http.Request> requests;
  late List<String> signatures;
  late bool validQuery, current, canSend, denySignature, postTimeout;
  late Object? queryOverride;
  void Function()? afterSign;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vanta-order-boundary-');
    journal = FileOrderRecoveryJournal(() async => directory);
    await journal.reload();
    intent = liveIntent();
    requests = [];
    signatures = [];
    validQuery = false;
    current = canSend = true;
    denySignature = postTimeout = false;
    queryOverride = null;
    afterSign = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/time')) {
          return http.Response(
            jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
            200,
          );
        }
        if (request.url.path.endsWith('/positionRisk')) {
          return http.Response(jsonEncode(livePositionPayload(intent.context)), 200);
        }
        if (request.method == 'POST') {
          final persisted = decodeRecoveryJournal(
            await File('${directory.path}/pending-futures-orders-v1.json').readAsString(),
          );
          expect(persisted.single.query.clientOrderId, intent.clientOrderId);
          expect(persisted.single.query.address, intent.context.address);
          if (postTimeout) throw TimeoutException('fixture');
          return http.Response('{"failureCode":0}', 200);
        }
        if (!validQuery) return http.Response('{}', 200);
        return http.Response(
          jsonEncode(
            queryOverride ??
                (intent.draft.attachment == null
                    ? liveQueryPayload(intent)
                    : attachedQuery(intent)),
          ),
          200,
        );
      }),
    );
  });
  tearDown(() async {
    service.close();
    await journal.close();
    await directory.delete(recursive: true);
  });
  Future<String> sign({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    expect(expectedAddress, intent.context.address);
    signatures.add((typedData['message'] as Map)['msg'] as String);
    if (denySignature) throw const AuthFailure('authWalletRejected');
    afterSign?.call();
    return TestWalletConnection.signature;
  }

  SignedLiveOrderRepository writer([OrderRecoveryJournal? storage]) => SignedLiveOrderRepository(
    service,
    sign,
    nonces: AsterReadNonces(),
    now: () => liveOrderClock,
    journal: storage ?? journal,
  );
  Future<LiveOrderResult> submit([OrderRecoveryJournal? storage]) => writer(storage)
      .submit(intent: intent, isCurrent: () => current, canSubmit: () => canSend, onStep: (_) {});
  int posts() => requests.where((r) => r.method == 'POST').length;
  for (final kind in ['ordinary', 'close', 'attached', 'attached-bbo']) {
    test('persist before POST; a fresh process recovers $kind with GET only', () async {
      intent = switch (kind) {
        'close' => liveCloseIntent(),
        'attached' => attachedIntent(),
        'attached-bbo' => attachedIntent(peg: AttachedEntryPeg.counterparty20),
        _ => liveIntent(),
      };
      final result = await submit();
      expect(result.needsRecheck, true);
      expect(posts(), 1);
      final restarted = FileOrderRecoveryJournal(() async => directory);
      await restarted.reload();
      final original = restarted.snapshot.records.single;
      expect(original.query.clientOrderId, intent.clientOrderId);
      validQuery = true;
      final before = requests.length;
      final reader = SignedOrderQueryRepository(
        service,
        sign,
        AsterReadNonces(),
        () => liveOrderClock,
        journal: restarted,
      );
      final recovered = await reader.query(
        original.query,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(recovered.needsRecheck, false);
      expect(requests.skip(before).every((r) => r.method == 'GET'), true);
      expect(posts(), 1);
      expect(restarted.snapshot.records, isEmpty);
      final latest = Uri.splitQueryString(signatures.last);
      expect(
        latest[intent.draft.attachment != null ? 'clientStrategyId' : 'origClientOrderId'],
        intent.clientOrderId,
      );
      await restarted.close();
    });
  }
  test('refusing signature creates neither a journal entry nor a POST', () async {
    denySignature = true;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records, isEmpty);
    expect(posts(), 0);
  });
  test('late changed confirmation after signature creates neither record nor POST', () async {
    afterSign = () => canSend = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records, isEmpty);
    expect(posts(), 0);
  });
  test(
    'confirmation expiring during disk write is rechecked and rolled back before POST',
    () async {
      final delayed = DelayedJournal();
      final pending = submit(delayed);
      while (delayed.snapshot.records.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      canSend = false;
      delayed.gate.complete();
      await expectLater(pending, throwsA(isA<AccountReadFailure>()));
      expect(posts(), 0);
      expect(delayed.snapshot.records, isEmpty);
      await delayed.close();
    },
  );
  test('failed persistence prevents POST even after wallet signature', () async {
    await Directory('${directory.path}/pending-futures-orders-v1.json.tmp').create();
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'orderRecoveryStorage')),
    );
    expect(signatures.length, 1);
    expect(posts(), 0);
  });
  test('POST timeout retains original record and cannot be repeated', () async {
    postTimeout = true;
    expect((await submit()).needsRecheck, true);
    expect(posts(), 1);
    expect(journal.snapshot.records.single.query.clientOrderId, intent.clientOrderId);
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'orderRecoveryPending')),
    );
    expect(posts(), 1);
  });
  test('mismatched or missing original query does not delete a durable pending record', () async {
    await submit();
    validQuery = true;
    queryOverride = {...liveQueryPayload(intent), 'origQty': '0.002'};
    final reader = SignedOrderQueryRepository(
      service,
      sign,
      AsterReadNonces(),
      () => liveOrderClock,
      journal: journal,
    );
    final query = journal.snapshot.records.single.query;
    expect((await reader.query(query, isCurrent: () => true, onStep: (_) {})).needsRecheck, true);
    expect(journal.snapshot.records.length, 1);
    validQuery = false;
    expect((await reader.query(query, isCurrent: () => true, onStep: (_) {})).needsRecheck, true);
    expect(journal.snapshot.records.length, 1);
    expect(posts(), 1);
  });
  test('query rejection or wallet change retains original durable record', () async {
    await submit();
    validQuery = true;
    denySignature = true;
    final reader = SignedOrderQueryRepository(
      service,
      sign,
      AsterReadNonces(),
      () => liveOrderClock,
      journal: journal,
    );
    final query = journal.snapshot.records.single.query;
    expect(
      (await reader.query(query, isCurrent: () => current, onStep: (_) {})).needsRecheck,
      true,
    );
    denySignature = false;
    afterSign = () => current = false;
    await expectLater(
      reader.query(query, isCurrent: () => current, onStep: (_) {}),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(journal.snapshot.records.length, 1);
    expect(posts(), 1);
  });
  test(
    'verified response with failed local removal keeps the record and the verified result',
    () async {
      await submit();
      validQuery = true;
      await Directory('${directory.path}/pending-futures-orders-v1.json.tmp').create();
      final reader = SignedOrderQueryRepository(
        service,
        sign,
        AsterReadNonces(),
        () => liveOrderClock,
        journal: journal,
      );
      final result = await reader.query(
        journal.snapshot.records.single.query,
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.orderId, '12345');
      expect(result.needsRecheck, false);
      expect(journal.snapshot.records.length, 1);
      expect(journal.snapshot.failure!.key, 'orderRecoveryStorage');
    },
  );
}
