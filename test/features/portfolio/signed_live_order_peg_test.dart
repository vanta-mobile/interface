import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_order_query_repository.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';

import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final close in [false, true]) {
    for (final hedge in [false, true]) {
      for (final peg in LiveOrderPeg.values) {
        test(
          'signed BBO close=$close hedge=$hedge $peg persists before one POST and independently queries',
          () async {
            final i = close
                ? liveCloseIntent(market: false, short: hedge, hedge: hedge, peg: peg)
                : liveIntent(hedge: hedge, peg: peg);
            final journal = MemoryOrderRecoveryJournal();
            addTearDown(journal.close);
            final requests = <http.Request>[], messages = <String>[];
            final service = AsterAccountService(
              client: MockClient((r) async {
                requests.add(r);
                Object payload;
                if (r.url.path.endsWith('/time')) {
                  payload = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
                } else if (r.url.path.endsWith('/positionRisk')) {
                  payload = livePositionPayload(i.context);
                } else if (r.method == 'POST') {
                  expect(journal.snapshot.records.single.query.draft.peg, peg);
                  expect(journal.snapshot.records.single.query.clientOrderId, i.clientOrderId);
                  expect(journal.snapshot.records.single.query.draft.price, '');
                  payload = {'orderId': 12345};
                } else {
                  expect(r.url.queryParameters['origClientOrderId'], i.clientOrderId);
                  expect(r.url.queryParameters.containsKey('pegPriceType'), false);
                  payload = liveQueryPayload(i);
                }
                return http.Response(jsonEncode(payload), 200);
              }),
            );
            addTearDown(service.close);
            final repository = SignedLiveOrderRepository(
              service,
              ({required expectedAddress, required typedData}) async {
                expect(expectedAddress, i.context.address);
                expect((typedData['domain'] as Map)['chainId'], 1666);
                messages.add((typedData['message'] as Map)['msg'] as String);
                return TestWalletConnection.signature;
              },
              nonces: AsterReadNonces(),
              now: () => liveOrderClock,
              journal: journal,
            );
            final result = await repository.submit(
              intent: i,
              isCurrent: () => true,
              canSubmit: () => true,
              onStep: (_) {},
            );
            expect(result.orderId, '12345');
            final post = requests.singleWhere((r) => r.method == 'POST');
            final form = Uri.splitQueryString(post.body);
            expect(form['price'], '0');
            expect(form['pegPriceType'], peg.wire);
            expect(form['quantity'], close ? '0.005' : '0.001');
            expect(form['type'], 'LIMIT');
            expect(form['timeInForce'], 'GTC');
            expect(form['user'], i.context.address);
            expect(form['signer'], i.context.address);
            expect(
              form['positionSide'],
              close && hedge
                  ? 'SHORT'
                  : hedge
                  ? 'LONG'
                  : 'BOTH',
            );
            expect(form['reduceOnly'], close && !hedge ? 'true' : null);
            expect(form.containsKey('closePosition'), false);
            expect(form.containsKey('pegOffset'), false);
            expect(
              post.body,
              '${messages[close ? 1 : 0]}&signature=${TestWalletConnection.signature}',
            );
            expect(messages.length, close ? 3 : 2);
            expect(requests.last.method, 'GET');
            expect(journal.snapshot.records, isEmpty);
          },
        );
      }
    }
  }
  test('unknown BBO persists on host restart; conflicting query keeps it; correct GET-only recovery clears it', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-ordinary-bbo-');
    addTearDown(() => dir.delete(recursive: true));
    final i = liveIntent(peg: LiveOrderPeg.queue);
    final requests = <http.Request>[];
    var available = false, correctPeg = false;
    final service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/time')) {
          return http.Response(
            jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
            200,
          );
        }
        if (!available) return http.Response('{}', 503);
        return http.Response(
          jsonEncode({
            ...liveQueryPayload(i),
            'pegPriceType': correctPeg ? 'QUEUE_1' : 'COUNTERPARTY_1',
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final original = FileOrderRecoveryJournal(() async => dir);
    await original.reload();
    final repository = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      nonces: AsterReadNonces(),
      journal: original,
      now: () => liveOrderClock,
    );
    final unknown = await repository.submit(
      intent: i,
      isCurrent: () => true,
      canSubmit: () => true,
      onStep: (_) {},
    );
    expect(unknown.needsRecheck, true);
    expect(original.snapshot.records.single.query.draft.peg, LiveOrderPeg.queue);
    await original.close();
    final rebuilt = FileOrderRecoveryJournal(() async => dir);
    addTearDown(rebuilt.close);
    await rebuilt.reload();
    final frozen = rebuilt.snapshot.records.single.query;
    expect(frozen.draft.peg, LiveOrderPeg.queue);
    expect(frozen.clientOrderId, i.clientOrderId);
    final reads = SignedOrderQueryRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      AsterReadNonces(),
      () => liveOrderClock,
      journal: rebuilt,
    );
    final postCount = requests.where((r) => r.method == 'POST').length;
    available = true;
    expect((await reads.query(frozen, isCurrent: () => true, onStep: (_) {})).needsRecheck, true);
    expect(rebuilt.snapshot.records, isNotEmpty);
    correctPeg = true;
    expect((await reads.query(frozen, isCurrent: () => true, onStep: (_) {})).orderId, '12345');
    expect(rebuilt.snapshot.records, isEmpty);
    expect(requests.where((r) => r.method == 'POST').length, postCount);
    expect(postCount, 1);
  });
  for (final issue in ['reject', 'scope', 'position']) {
    test('$issue before BBO dispatch never writes or posts', () async {
      final i = liveCloseIntent(market: false, peg: LiveOrderPeg.queue);
      final journal = MemoryOrderRecoveryJournal();
      addTearDown(journal.close);
      var current = true, posts = 0;
      final service = AsterAccountService(
        client: MockClient((r) async {
          if (r.method == 'POST') posts++;
          final positions = livePositionPayload(i.context);
          if (issue == 'position') positions.single['positionAmt'] = '0.02';
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/time')
                  ? {'serverTime': liveOrderClock.millisecondsSinceEpoch}
                  : positions,
            ),
            200,
          );
        }),
      );
      addTearDown(service.close);
      var signatures = 0;
      final repository = SignedLiveOrderRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          signatures++;
          if (signatures == 2) {
            if (issue == 'reject') throw const AuthFailure('authWalletRejected');
            if (issue == 'scope') current = false;
          }
          return TestWalletConnection.signature;
        },
        nonces: AsterReadNonces(),
        journal: journal,
        now: () => liveOrderClock,
      );
      await expectLater(
        repository.submit(
          intent: i,
          isCurrent: () => current,
          canSubmit: () => current,
          onStep: (_) {},
        ),
        throwsA(anything),
      );
      expect(posts, 0);
      expect(journal.snapshot.records, isEmpty);
    });
  }
}
