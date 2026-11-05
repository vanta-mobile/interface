import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/batch_close_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_position_risk_repository.dart';

import '../../support/aster_account.dart';
import '../../support/batch_close.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final hedge in [false, true]) {
    for (final timeout in [false, true]) {
      test('signed close-all protocol: hedge=$hedge timeout=$timeout', () async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final rows = batchRiskRows(hedge: hedge);
        final requests = <http.Request>[], messages = <String>[];
        final orders = <String, Map<String, dynamic>>{};
        var unknown = timeout;
        final exchange = liveExchangePayload();
        final btc = (exchange['symbols'] as List).single as Map<String, dynamic>;
        exchange['symbols'] = <Map<String, dynamic>>[
          btc,
          {...btc, 'symbol': 'ETHUSDT', 'baseAsset': 'ETH'},
        ];
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
              payload = exchange;
            } else if (path.endsWith('/premiumIndex')) {
              payload = {
                'symbol': params['symbol'],
                'markPrice': '80000',
                'time': liveOrderClock.millisecondsSinceEpoch,
              };
            } else if (path.endsWith('/ticker/price')) {
              payload = {
                'symbol': params['symbol'],
                'price': '80000',
                'time': liveOrderClock.millisecondsSinceEpoch,
              };
            } else if (path.endsWith('/ticker/bookTicker')) {
              payload = {
                'symbol': params['symbol'],
                'bidPrice': '79999',
                'askPrice': '80001',
                'bidQty': '1',
                'askQty': '1',
              };
            } else if (path.endsWith('/positionSide/dual')) {
              payload = {'dualSidePosition': hedge};
            } else if (path.endsWith('/positionRisk')) {
              payload = rows
                  .where((r) => params['symbol'] == null || r['symbol'] == params['symbol'])
                  .toList();
            } else if (path.endsWith('/order') && request.method == 'POST') {
              final row = rows.singleWhere(
                (r) =>
                    r['symbol'] == params['symbol'] && r['positionSide'] == params['positionSide'],
              );
              expect(params['quantity'], '${row['positionAmt']}'.replaceFirst('-', ''));
              expect(params['type'], 'MARKET');
              expect(params['reduceOnly'], hedge ? null : 'true');
              expect(params['closePosition'], null);
              expect(params['price'], null);
              expect(params['timeInForce'], null);
              orders[params['newClientOrderId']!] = {
                'symbol': params['symbol'],
                'clientOrderId': params['newClientOrderId'],
                'orderId': orders.length + 100,
                'side': params['side'],
                'positionSide': params['positionSide'],
                'type': 'MARKET',
                'origQty': params['quantity'],
                'executedQty': params['quantity'],
                'status': 'FILLED',
                'price': '0',
                'reduceOnly': !hedge,
                'closePosition': false,
              };
              row['positionAmt'] = '0';
              row['entryPrice'] = '0';
              if (timeout) throw TimeoutException('simulated after acceptance');
              payload = {'orderId': 99999, 'status': 'NEW'};
            } else if (path.endsWith('/order') && request.method == 'GET') {
              if (unknown) {
                return http.Response(jsonEncode({'code': -2013, 'msg': 'not found'}), 400);
              }
              payload = orders[params['origClientOrderId']];
            } else {
              fail('Unexpected request ${request.method} $path');
            }
            return http.Response(jsonEncode(payload), 200);
          }),
        );
        final nonces = AsterReadNonces();
        Future<String> sign({
          required String expectedAddress,
          required Map<String, dynamic> typedData,
        }) async {
          expect(expectedAddress, accountAddress);
          expect((typedData['domain'] as Map)['chainId'], 1666);
          messages.add((typedData['message'] as Map)['msg'] as String);
          return TestWalletConnection.signature;
        }

        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
            liveOrderRepositoryProvider.overrideWithValue(
              SignedLiveOrderRepository(service, sign, nonces: nonces, now: () => liveOrderClock),
            ),
            positionRiskRepositoryProvider.overrideWithValue(
              SignedPositionRiskRepository(
                service,
                sign,
                nonces: nonces,
                now: () => liveOrderClock,
              ),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          service.close();
          await identity.dispose();
        });
        container.read(authProvider);
        await Future<void>.delayed(Duration.zero);
        await container.read(positionRiskProvider.notifier).refresh();
        final controller = container.read(batchCloseProvider.notifier);
        final intent = controller.prepare()!;
        await controller.submit(intent);
        var state = container.read(batchCloseProvider);
        if (timeout) {
          expect(state.needsRecheck, true);
          expect(orders.length, 1);
          expect(state.items.values.skip(1).every((i) => !i.submitted), true);
          final readsBefore = requests.where((r) => r.url.path.endsWith('/positionRisk')).length;
          unknown = false;
          await controller.recheck();
          state = container.read(batchCloseProvider);
          expect(state.needsRecheck, false);
          expect(requests.where((r) => r.url.path.endsWith('/positionRisk')).length, readsBefore);
          expect(requests.where((r) => r.method == 'POST').length, 1);
          expect(orders.keys.single, intent.targets.first.clientOrderId);
        } else {
          expect(orders.length, hedge ? 3 : 2);
          expect(state.items.values.every((i) => i.result?.status == 'FILLED'), true);
          expect(
            container.read(positionRiskProvider).account!.positions.where((p) => !p.balanceOnly),
            isEmpty,
          );
          expect(container.read(positionRiskProvider).stale, false);
          expect(messages.length, hedge ? 17 : 12);
          expect(requests.where((r) => r.url.path.endsWith('/order')).map((r) => r.method), [
            for (var i = 0; i < orders.length; i++) ...['POST', 'GET'],
          ]);
        }
        final signed = requests
            .where((r) => r.url.queryParameters.containsKey('signature') || r.method == 'POST')
            .toList();
        expect(signed.length, messages.length);
        final usedNonces = <String>{};
        for (var index = 0; index < signed.length; index++) {
          final request = signed[index];
          final encoded = request.method == 'POST' ? request.body : request.url.query;
          expect(encoded.split('&signature=').first, messages[index]);
          final params = Uri.splitQueryString(encoded);
          expect(params['user'], accountAddress);
          expect(params['signer'], accountAddress);
          expect(usedNonces.add(params['nonce']!), true);
        }
        expect(identity.wallets, 0);
      });
    }
  }
}
