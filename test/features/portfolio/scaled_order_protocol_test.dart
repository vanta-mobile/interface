import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/scaled_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_order_query_repository.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/scaled_order.dart';
import '../../support/wallet_connection.dart';

/// Order records are best-effort diagnostics written and cleared without
/// blocking the order flow; wait (up to 3s under load) for [done].
Future<void> _settled(
  FileOrderRecoveryJournal journal,
  bool Function(List<OrderRecoveryRecord> records) done,
) async {
  for (var i = 0; i < 300 && !done(journal.snapshot.records.toList()); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  for (final buy in [true, false]) {
    for (final hedge in [false, true]) {
      for (final variant in [
        'base-equal',
        'quote-increasing',
        'quote-decreasing-ratio',
        'random',
      ]) {
        for (final unknownSecond in [false, true]) {
          test(
            'signed Scaled EOA/host journal and GET-only restart: $variant buy=$buy hedge=$hedge unknown=$unknownSecond',
            () async {
              final directory = await Directory.systemTemp.createTemp('vanta-scaled-');
              final journal = FileOrderRecoveryJournal(() async => directory);
              await journal.reload();
              final identity = TestIdentityRepository()..restored = signingIdentity;
              final context = liveContext(
                mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
              );
              late final ScaledOrderIntent intent;
              final messages = <String>[], requests = <http.Request>[];
              final orders = <String, Map<String, dynamic>>{};
              var queryUnavailable = unknownSecond;
              final service = AsterAccountService(
                client: MockClient((request) async {
                  requests.add(request);
                  expect(request.url.host, 'fapi.asterdex.com');
                  expect(request.followRedirects, false);
                  final params = request.method == 'POST'
                      ? Uri.splitQueryString(request.body)
                      : request.url.queryParameters;
                  final path = request.url.path;
                  Object? payload;
                  if (path.endsWith('/time')) {
                    payload = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
                  } else if (path.endsWith('/exchangeInfo')) {
                    payload = liveExchangePayload();
                  } else if (path.endsWith('/premiumIndex')) {
                    payload = {
                      'symbol': 'BTCUSDT',
                      'markPrice': '80000',
                      'time': liveOrderClock.millisecondsSinceEpoch,
                    };
                  } else if (path.endsWith('/ticker/price')) {
                    payload = {
                      'symbol': 'BTCUSDT',
                      'price': '80000',
                      'time': liveOrderClock.millisecondsSinceEpoch,
                    };
                  } else if (path.endsWith('/ticker/bookTicker')) {
                    payload = {
                      'symbol': 'BTCUSDT',
                      'bidPrice': '79999',
                      'askPrice': '80001',
                      'bidQty': '1',
                      'askQty': '1',
                    };
                  } else if (path.endsWith('/positionSide/dual')) {
                    payload = {'dualSidePosition': hedge};
                  } else if (path.endsWith('/positionRisk')) {
                    payload = livePositionPayload(context);
                  } else if (path.endsWith('/multiAssetsMargin')) {
                    payload = {'multiAssetsMargin': false};
                  } else if (path == AsterAccountService.accountPath) {
                    payload = {
                      ...accountPayload(),
                      'availableBalance': '1000',
                      'canTrade': true,
                      'positions': <Object>[],
                    };
                  } else if (path.endsWith('/order') && request.method == 'POST') {
                    final id = params['newClientOrderId']!;
                    expect(messages.contains(request.body.split('&signature=').first), true);
                    // Order records are best-effort diagnostics written without
                    // blocking the POST, so the file is not asserted here.
                    expect(params['quantity'], intent.plan.orders[orders.length].quantity);
                    expect(params['price'], intent.plan.orders[orders.length].price);
                    expect(params.containsKey('distribution'), false);
                    expect(params.containsKey('orderCount'), false);
                    expect(params['type'], 'LIMIT');
                    expect(params['timeInForce'], 'GTC');
                    expect(params['side'], buy ? 'BUY' : 'SELL');
                    expect(params['positionSide'], hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH');
                    expect(params['reduceOnly'], null);
                    expect(params['closePosition'], null);
                    expect(params['user'], accountAddress);
                    expect(params['signer'], accountAddress);
                    expect(params['signature'], TestWalletConnection.signature);
                    orders[id] = {
                      'symbol': 'BTCUSDT',
                      'clientOrderId': id,
                      'orderId': orders.length + 100,
                      'side': params['side'],
                      'positionSide': params['positionSide'],
                      'type': 'LIMIT',
                      'origType': 'LIMIT',
                      'origQty': params['quantity'],
                      'executedQty': '0',
                      'price': params['price'],
                      'timeInForce': 'GTC',
                      'status': 'NEW',
                      'reduceOnly': false,
                      'closePosition': false,
                    };
                    if (unknownSecond && orders.length == 2) {
                      throw TimeoutException('after fixture acceptance');
                    }
                    payload = {'orderId': 99999}; // deliberately untrusted acknowledgement
                  } else if (path.endsWith('/order') && request.method == 'GET') {
                    final id = params['origClientOrderId'];
                    if (queryUnavailable && id == orders.keys.last && orders.length == 2) {
                      return http.Response('{"code":-2013,"msg":"fixture"}', 400);
                    }
                    payload = orders[id];
                  } else {
                    fail('unexpected request path $path');
                  }
                  if (params.containsKey('nonce')) {
                    expect(params['user'], accountAddress);
                    expect(params['signer'], accountAddress);
                  }
                  return http.Response(jsonEncode(payload), 200);
                }),
              );
              Future<String> sign({
                required String expectedAddress,
                required Map<String, Object?> typedData,
              }) async {
                expect(expectedAddress, accountAddress);
                expect((typedData['domain'] as Map)['chainId'], 1666);
                final message = (typedData['message'] as Map)['msg'] as String;
                expect(message, contains('user=$accountAddress&signer=$accountAddress'));
                messages.add(message);
                return TestWalletConnection.signature;
              }

              final repository = SignedLiveOrderRepository(
                service,
                sign,
                nonces: AsterReadNonces(),
                now: () => liveOrderClock,
                journal: journal,
              );
              final container = ProviderContainer(
                overrides: [
                  identityRepositoryProvider.overrideWithValue(identity),
                  liveOrderRepositoryProvider.overrideWithValue(repository),
                  orderRecoveryJournalProvider.overrideWithValue(journal),
                  liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
                ],
              );
              try {
                container.read(authProvider);
                container.read(scaledOrderProvider);
                await Future<void>.delayed(Duration.zero);
                await container.read(liveOrderProvider.notifier).load('BTCUSDT');
                expect(container.read(liveOrderProvider).failure, null);
                expect(container.read(liveOrderProvider).context?.fundsFailure?.key, null);
                final controller = container.read(scaledOrderProvider.notifier);
                intent = controller.prepare(
                  'BTCUSDT',
                  scaledDraft(
                    buy: buy,
                    unit: variant.startsWith('quote') ? ScaledSizeUnit.quote : ScaledSizeUnit.base,
                    quantity: variant.startsWith('quote')
                        ? '1000'
                        : variant == 'random'
                        ? '0.03'
                        : '0.008',
                    distribution: switch (variant) {
                      'quote-increasing' => ScaledDistribution.increasing,
                      'quote-decreasing-ratio' => ScaledDistribution.decreasing,
                      'random' => ScaledDistribution.random,
                      _ => ScaledDistribution.equal,
                    },
                    constant: variant == 'quote-decreasing-ratio'
                        ? ScaledConstant.ratio
                        : ScaledConstant.difference,
                    seed: variant == 'random' ? 42 : null,
                  ),
                )!;
                await controller.submit(intent);
                final state = container.read(scaledOrderProvider);
                expect(orders.keys, intent.clientIds.take(unknownSecond ? 2 : 3));
                expect(
                  messages.where((m) => m.contains('newClientOrderId=')).length,
                  unknownSecond ? 2 : 3,
                );
                expect(
                  orders.values.map((o) => o['price']),
                  unknownSecond ? ['79000', '80000'] : ['79000', '80000', '81000'],
                );
                expect(state.needsRecheck, unknownSecond);
                if (unknownSecond) {
                  await _settled(
                    journal,
                    (records) =>
                        records.length == 1 &&
                        records.single.query.clientOrderId == intent.clientIds[1],
                  );
                  expect(journal.snapshot.records.single.query.clientOrderId, intent.clientIds[1]);
                  expect(state.items[2].submitted, false);
                  // A settled unknown scaled order releases its activity lease.
                  expect(container.read(symbolSettingsActivityProvider).unresolved, false);
                  container.dispose();
                  // A reconstructed native journal knows only the sent, unresolved child.
                  final restarted = FileOrderRecoveryJournal(() async => directory);
                  await restarted.reload();
                  try {
                    final record = restarted.snapshot.records.single;
                    expect(record.query.clientOrderId, intent.clientIds[1]);
                    final postsBefore = requests.where((r) => r.method == 'POST').length;
                    queryUnavailable = false;
                    final query = SignedOrderQueryRepository(
                      service,
                      sign,
                      AsterReadNonces(),
                      () => liveOrderClock,
                      journal: restarted,
                    );
                    final result = await query.query(
                      record.query,
                      isCurrent: () => true,
                      onStep: (_) {},
                    );
                    expect(result.orderId, '101');
                    expect(result.needsRecheck, false);
                    await _settled(restarted, (records) => records.isEmpty);
                    expect(restarted.snapshot.records, isEmpty);
                    expect(requests.where((r) => r.method == 'POST').length, postsBefore);
                    expect(orders.containsKey(intent.clientIds.last), false);
                  } finally {
                    await restarted.close();
                  }
                } else {
                  expect(state.items.every((i) => i.result?.orderId != '99999'), true);
                  expect(journal.snapshot.records, isEmpty);
                  expect(messages.length, 22); // 4 initial + 3 × (4 context + POST + GET)
                }
                expect(identity.wallets, 0);
              } finally {
                container.dispose();
                service.close();
                await identity.dispose();
                await journal.close();
                await directory.delete(recursive: true);
              }
            },
          );
        }
      }
    }
  }
}
