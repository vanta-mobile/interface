import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  late List<http.Request> requests;
  late List<String> messages;
  Completer<void>? publicReadGate;
  late AsterAccountService service;
  late SignedLiveOrderRepository repository;
  late LiveOrderIntent intent;
  late Map<String, dynamic> queryPayload;
  late bool current, canSend, postTimeout, hedge;
  late int refusedSignature;
  List<Map<String, dynamic>>? closePositions;
  bool badBook = false;
  Object? fundsPayload, assetModePayload, lastTickerPayload;
  late DateTime clock;
  void Function()? afterSign;
  setUp(() {
    requests = [];
    messages = [];
    intent = liveIntent();
    queryPayload = liveQueryPayload(intent);
    current = canSend = true;
    postTimeout = hedge = false;
    refusedSignature = 0;
    afterSign = null;
    publicReadGate = null;
    closePositions = null;
    badBook = false;
    fundsPayload = assetModePayload = lastTickerPayload = null;
    clock = liveOrderClock;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        if (publicReadGate != null &&
            const {
              '/fapi/v3/time',
              '/fapi/v3/exchangeInfo',
              '/fapi/v3/premiumIndex',
              '/fapi/v3/ticker/price',
              '/fapi/v3/ticker/bookTicker',
            }.contains(request.url.path)) {
          await publicReadGate!.future;
        }
        expect(request.followRedirects, false);
        expect(request.url.host, 'fapi.asterdex.com');
        final path = request.url.path;
        Object? data;
        if (path.endsWith('/time')) {
          data = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
        } else if (path.endsWith('/exchangeInfo')) {
          data = liveExchangePayload();
        } else if (path.endsWith('/premiumIndex')) {
          data = {
            'symbol': 'BTCUSDT',
            'markPrice': '80000',
            'time': liveOrderClock.millisecondsSinceEpoch,
          };
        } else if (path.endsWith('/ticker/bookTicker')) {
          if (badBook) return http.Response('{}', 200);
          data = {
            'symbol': 'BTCUSDT',
            'bidPrice': '79999',
            'askPrice': '80001',
            'bidQty': '1',
            'askQty': '1',
          };
        } else if (path.endsWith('/ticker/price')) {
          data =
              lastTickerPayload ??
              {
                'symbol': 'BTCUSDT',
                'price': '80001',
                'time': liveOrderClock.millisecondsSinceEpoch,
              };
        } else if (path.endsWith('/positionSide/dual')) {
          data = {'dualSidePosition': false};
        } else if (path.endsWith('/multiAssetsMargin')) {
          data = assetModePayload ?? {'multiAssetsMargin': false};
        } else if (path.endsWith('/accountWithJoinMargin')) {
          data =
              fundsPayload ??
              {
                ...accountPayload(),
                'canTrade': true,
                'positions': [
                  for (final row in closePositions ?? livePositionPayload(liveContext()))
                    {...row, 'isolated': row['marginType'] == 'isolated'},
                ],
              };
        } else if (path.endsWith('/positionRisk')) {
          data =
              closePositions ??
              [
                {
                  'symbol': 'BTCUSDT',
                  'positionSide': hedge ? 'LONG' : 'BOTH',
                  'leverage': '10',
                  'positionAmt': '0',
                  'entryPrice': '0',
                  'marginType': 'cross',
                },
                if (hedge)
                  {
                    'symbol': 'BTCUSDT',
                    'positionSide': 'SHORT',
                    'leverage': '10',
                    'positionAmt': '0',
                    'entryPrice': '0',
                    'marginType': 'cross',
                  },
              ];
        } else {
          expect(path, '/fapi/v3/order');
          if (request.method == 'POST') {
            if (postTimeout) throw TimeoutException('simulated');
            data = {'orderId': 999, 'status': 'FILLED'};
          } else {
            expect(request.method, 'GET');
            data = queryPayload;
          }
        }
        return http.Response(jsonEncode(data), 200);
      }),
    );
    repository = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (messages.length == refusedSignature) throw const AuthFailure('authWalletRejected');
        afterSign?.call();
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => clock,
    );
  });
  tearDown(() => service.close());

  Future<LiveOrderResult> submit() => repository.submit(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSend,
    onStep: (_) {},
  );
  Future<LiveOrderResult> recheck() =>
      repository.recheck(intent: intent, isCurrent: () => current, onStep: (_) {});

  for (final market in [false, true]) {
    for (final buy in [false, true]) {
      test('quote amount signs only frozen base quantity: market=$market buy=$buy', () async {
        final data = liveContext(bid: '79999', ask: '80001');
        final entry = liveDraft(market: market, buy: buy, price: market ? '' : '80000');
        final size = const LiveOrderSize(
          unit: OrderSizeUnit.quote,
          text: '160',
        ).resolve(data, entry);
        final expected = market && buy ? '0.001' : '0.002';
        expect(size.quantity, expected);
        intent = LiveOrderIntent(
          context: data,
          draft: entry.withQuantity(size.quantity),
          clientOrderId: 'vanta-quote-frozen-123',
          revision: 0,
        );
        queryPayload = liveQueryPayload(intent);
        expect((await submit()).status, 'NEW');
        final post = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
        expect(post['quantity'], expected);
        expect(post['quantityUnit'], null);
        expect(post['quoteOrderQty'], null);
        expect(post['user'], accountAddress);
        expect(post['signer'], accountAddress);
        expect(post['side'], buy ? 'BUY' : 'SELL');
        expect(
          messages.first,
          requests.singleWhere((r) => r.method == 'POST').body.split('&signature=').first,
        );
      });
    }
  }
  test(
    'quote-sized timeout rechecks original ID and quantity without conversion or POST',
    () async {
      final data = liveContext(ask: '80000');
      final entry = liveDraft(market: true, price: '');
      final size = const LiveOrderSize(unit: OrderSizeUnit.quote, text: '80').resolve(data, entry);
      intent = LiveOrderIntent(
        context: data,
        draft: entry.withQuantity(size.quantity),
        clientOrderId: 'vanta-quote-timeout-123',
        revision: 0,
      );
      queryPayload = liveQueryPayload(intent);
      postTimeout = true;
      queryPayload = {...queryPayload, 'origQty': '0.002'};
      final result = await submit();
      expect(result.needsRecheck, true);
      queryPayload = liveQueryPayload(intent);
      final before = requests.length;
      expect((await recheck()).status, 'NEW');
      final recovery = requests.skip(before).toList();
      expect(recovery.where((r) => r.method == 'POST'), isEmpty);
      expect(recovery.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
      expect(intent.draft.quantity, '0.001');
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );
  test('POST exact form bytes then signed GET; ACK cannot prove a fill', () async {
    final result = await submit();
    expect(result.status, 'NEW');
    expect(result.orderId, '12345');
    final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
    expect(orders.map((r) => r.method), ['POST', 'GET']);
    expect(orders.first.url.query, isEmpty);
    expect(orders.first.body.split('&signature=').first, messages.first);
    final post = Uri.splitQueryString(orders.first.body);
    expect(post, containsPair('user', accountAddress));
    expect(post, containsPair('signer', accountAddress));
    expect(post, containsPair('price', '80000'));
    expect(post, containsPair('timeInForce', 'GTC'));
    expect(post, containsPair('newClientOrderId', intent.clientOrderId));
    expect(post, containsPair('signature', TestWalletConnection.signature));
    final get = orders.last.url.queryParameters;
    expect(get['origClientOrderId'], intent.clientOrderId);
    expect(get['newClientOrderId'], null);
    expect(post['nonce'], isNot(get['nonce']));
    expect(orders.last.url.query.split('&signature=').first, messages.last);
  });
  test('market hedge entry has correct side and excludes forbidden fields', () async {
    intent = liveIntent(market: true, buy: false, hedge: true);
    queryPayload = liveQueryPayload(intent, status: 'FILLED');
    expect((await submit()).status, 'FILLED');
    final post = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
    expect(post['side'], 'SELL');
    expect(post['positionSide'], 'SHORT');
    for (final key in ['price', 'timeInForce', 'stopPrice', 'reduceOnly']) {
      expect(post.containsKey(key), false, reason: key);
    }
  });
  for (final policy in [
    LiveOrderTimeInForce.ioc,
    LiveOrderTimeInForce.postOnly,
    LiveOrderTimeInForce.hidden,
  ]) {
    test(
      '${policy.wire}: exact signed POST and independent query verify selected policy',
      () async {
        intent = liveIntent(timeInForce: policy);
        queryPayload = liveQueryPayload(intent, status: 'EXPIRED');
        final result = await submit();
        expect(result.status, 'EXPIRED');
        final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
        expect(orders.map((r) => r.method), ['POST', 'GET']);
        final post = Uri.splitQueryString(orders.first.body);
        expect(post['timeInForce'], policy.wire);
        expect(post['price'], '80000');
        expect(post['user'], accountAddress);
        expect(post['signer'], accountAddress);
        expect(orders.first.body.split('&signature=').first, messages.first);
        expect(orders.last.url.query.split('&signature=').first, messages.last);
        expect(messages.length, 2);
      },
    );

    test(
      '${policy.wire}: mismatched query keeps original ID and policy for GET-only recovery',
      () async {
        intent = liveIntent(timeInForce: policy);
        queryPayload = {...liveQueryPayload(intent), 'timeInForce': 'GTC'};
        expect((await submit()).needsRecheck, true);
        queryPayload = liveQueryPayload(intent, status: 'FILLED');
        expect((await recheck()).status, 'FILLED');
        final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
        expect(orders.map((r) => r.method), ['POST', 'GET', 'GET']);
        expect(orders.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
        expect(Uri.splitQueryString(orders.first.body)['timeInForce'], policy.wire);
      },
    );
  }

  for (final hedgeClose in [false, true]) {
    test(
      'Hidden close preserves original position and checks it before submission: hedge=$hedgeClose',
      () async {
        intent = liveCloseIntent(
          market: false,
          hedge: hedgeClose,
          timeInForce: LiveOrderTimeInForce.hidden,
        );
        closePositions = livePositionPayload(intent.context);
        queryPayload = liveQueryPayload(intent);
        expect((await submit()).status, 'NEW');
        final post = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
        expect(post['timeInForce'], 'HIDDEN');
        expect(post['side'], 'SELL');
        expect(post['positionSide'], hedgeClose ? 'LONG' : 'BOTH');
        expect(post['reduceOnly'], hedgeClose ? null : 'true');
        expect(messages.length, 3);
        expect(requests.where((r) => r.url.path.endsWith('/positionRisk')).length, 1);
      },
    );
  }

  test('unsupported policy is rejected before any signature or HTTP request', () async {
    intent = LiveOrderIntent(
      context: liveContext(policies: {LiveOrderTimeInForce.gtc}),
      draft: liveDraft(timeInForce: LiveOrderTimeInForce.ioc),
      clientOrderId: 'vanta-unsupported-policy',
      revision: 0,
    );
    await expectLater(
      submit(),
      throwsA(
        isA<AccountReadFailure>().having((f) => f.key, 'key', 'liveOrderTimeInForceUnavailable'),
      ),
    );
    expect(requests, isEmpty);
    expect(messages, isEmpty);
  });

  for (final kind in LiveOrderTriggerKind.values) {
    for (final market in [false, true]) {
      test('conditional signed protocol and triggered query: $kind market=$market', () async {
        final trigger = LiveOrderTrigger(
          kind: kind,
          price: kind == LiveOrderTriggerKind.stop ? '81000' : '79000',
          basis: LiveOrderTriggerBasis.mark,
          protect: true,
        );
        intent = liveIntent(
          market: market,
          trigger: trigger,
          timeInForce: LiveOrderTimeInForce.ioc,
        );
        queryPayload = {
          ...liveQueryPayload(intent, status: 'FILLED'),
          'type': market ? 'MARKET' : 'LIMIT',
        };
        final result = await submit();
        expect(result.status, 'FILLED');
        final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
        expect(orders.map((r) => r.method), ['POST', 'GET']);
        final params = Uri.splitQueryString(orders.first.body);
        expect(params['type'], trigger.orderType(market: market));
        expect(params['stopPrice'], trigger.price);
        expect(params['workingType'], 'MARK_PRICE');
        expect(params['priceProtect'], 'TRUE');
        expect(params['price'], market ? null : '80000');
        expect(params['timeInForce'], market ? null : 'IOC');
        expect(params.containsKey('closePosition'), false);
        expect(params['user'], accountAddress);
        expect(params['signer'], accountAddress);
        expect(orders.first.body.split('&signature=').first, messages.first);
        expect(orders.last.url.query.split('&signature=').first, messages.last);
        expect(messages.length, 2);
      });
    }
  }

  for (final hedgeClose in [false, true]) {
    test('position stop first rechecks original position: hedge=$hedgeClose', () async {
      intent = liveCloseIntent(
        hedge: hedgeClose,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
      );
      closePositions = livePositionPayload(intent.context);
      queryPayload = liveQueryPayload(intent);
      expect((await submit()).status, 'NEW');
      final params = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
      expect(params['type'], 'STOP_MARKET');
      expect(params['side'], 'SELL');
      expect(params['positionSide'], hedgeClose ? 'LONG' : 'BOTH');
      expect(params['reduceOnly'], hedgeClose ? null : 'true');
      expect(messages.length, 3);
      expect(requests.where((r) => r.url.path.endsWith('/positionRisk')).length, 1);
    });
  }

  for (final short in [false, true]) {
    for (final hedgeClose in [false, true]) {
      test(
        'entire close signs position, exact POST and independent query: $short $hedgeClose',
        () async {
          intent = liveCloseIntent(
            short: short,
            hedge: hedgeClose,
            entireClose: true,
            trigger: LiveOrderTrigger(
              kind: LiveOrderTriggerKind.stop,
              price: short ? '81000' : '78000',
            ),
          );
          closePositions = livePositionPayload(intent.context);
          queryPayload = liveQueryPayload(intent, status: 'FILLED', executed: '0.02');
          expect((await submit()).status, 'FILLED');
          final signed = requests
              .where((r) => r.url.path.endsWith('/positionRisk') || r.url.path.endsWith('/order'))
              .toList();
          expect(signed.map((r) => r.method), ['GET', 'POST', 'GET']);
          expect(messages.length, 3);
          final params = Uri.splitQueryString(signed[1].body);
          expect(params['user'], accountAddress);
          expect(params['signer'], accountAddress);
          expect(params['closePosition'], 'true');
          expect(params['side'], short ? 'BUY' : 'SELL');
          expect(params['positionSide'], intent.positionSide);
          for (final key in ['quantity', 'reduceOnly', 'price', 'timeInForce']) {
            expect(params.containsKey(key), false);
          }
          expect(signed[1].body.split('&signature=').first, messages[1]);
          expect(signed.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
        },
      );
    }
  }
  test(
    'entire close snapshot change blocks POST even though trigger-time size may change later',
    () async {
      intent = liveCloseIntent(
        entireClose: true,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
      );
      closePositions = livePositionPayload(intent.context)..single['positionAmt'] = '0.02';
      await expectLater(
        submit(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveClosePositionChanged')),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  test(
    'entire close timeout and scope mismatch retain original ID and recover with GET only',
    () async {
      intent = liveCloseIntent(
        entireClose: true,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
      );
      closePositions = livePositionPayload(intent.context);
      postTimeout = true;
      queryPayload = {...liveQueryPayload(intent), 'closePosition': false};
      expect((await submit()).needsRecheck, true);
      queryPayload = liveQueryPayload(intent, status: 'FILLED', executed: '0.02');
      expect((await recheck()).status, 'FILLED');
      expect(requests.where((r) => r.url.path.endsWith('/order')).map((r) => r.method), [
        'POST',
        'GET',
        'GET',
      ]);
      expect(requests.where((r) => r.url.path.endsWith('/positionRisk')).length, 1);
      expect(messages.length, 4);
    },
  );

  test(
    'conditional timeout plus wrong trigger stays query-only until original terms match',
    () async {
      intent = liveIntent(
        market: true,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
      );
      postTimeout = true;
      queryPayload = {...liveQueryPayload(intent), 'stopPrice': '81001'};
      expect((await submit()).needsRecheck, true);
      queryPayload = liveQueryPayload(intent);
      expect((await recheck()).status, 'NEW');
      final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
      expect(orders.map((r) => r.method), ['POST', 'GET', 'GET']);
      expect(orders.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
      expect(Uri.splitQueryString(orders.first.body)['stopPrice'], '81000');
    },
  );

  test('refused or expired conditional signature cannot POST', () async {
    intent = liveIntent(
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
    );
    refusedSignature = 1;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    refusedSignature = 0;
    afterSign = () => canSend = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('preflight Last ticker is public and optional; no basis substitution on failure', () async {
    final data = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(data.lastPrice.toString(), '80001');
    final ticker = requests.singleWhere((r) => r.url.path.endsWith('/ticker/price'));
    expect(ticker.url.queryParameters, {'symbol': 'BTCUSDT'});
    expect(messages.length, 4);
    lastTickerPayload = {'symbol': 'ETHUSDT', 'price': '80001', 'time': 1};
    final partial = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(partial.lastPrice, null);
    expect(partial.validate(liveDraft()), null);
    expect(
      partial.validate(
        liveDraft(
          trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
        ),
      ),
      'liveOrderTriggerReferenceUnavailable',
    );
    expect(
      partial.validate(
        liveDraft(
          trigger: const LiveOrderTrigger(
            kind: LiveOrderTriggerKind.stop,
            price: '81000',
            basis: LiveOrderTriggerBasis.mark,
          ),
        ),
      ),
      null,
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('refused placement signature makes no POST', () async {
    refusedSignature = 1;
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletRejected')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('late approval after expiration or wallet change cannot POST', () async {
    afterSign = () => canSend = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    canSend = true;
    afterSign = () => current = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('POST timeout queries frozen ID and never retries the POST', () async {
    postTimeout = true;
    expect((await submit()).orderId, '12345');
    await recheck();
    expect(requests.where((r) => r.method == 'POST').length, 1);
    expect(
      requests
          .where((r) => r.url.queryParameters['origClientOrderId'] == intent.clientOrderId)
          .length,
      2,
    );
  });
  test('refused verification remains unknown; recheck signs GET only', () async {
    refusedSignature = 2;
    expect((await submit()).needsRecheck, true);
    refusedSignature = 0;
    expect((await recheck()).needsRecheck, false);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('a query for a different order does not resolve placement', () async {
    queryPayload['clientOrderId'] = 'other';
    final result = await submit();
    expect(result.needsRecheck, true);
    expect(result.failure?.key, 'accountDataInvalid');
    expect(result.failure?.reasonKey, 'orderResponseIdentityMismatch');
    expect(result.failure?.details?.endpoint, '/fapi/v3/order');
  });
  test('preflight reads zero-sized configuration without placing an order', () async {
    final context = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(context.leverage, 10);
    expect(context.rules.baseAsset, 'BTC');
    expect(messages.length, 4);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(
      requests
          .singleWhere((r) => r.url.path.endsWith('/positionRisk'))
          .url
          .queryParameters['symbol'],
      'BTCUSDT',
    );
  });
  test('conflicting mode and symbol configuration reject preflight', () async {
    hedge = true;
    await expectLater(
      repository.read(
        address: accountAddress,
        symbol: 'BTCUSDT',
        isCurrent: () => current,
        onStep: (_) {},
      ),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'accountDataInvalid')),
    );
  });

  void close({
    bool short = false,
    bool hedge = false,
    bool reduceOnly = false,
    bool market = true,
  }) {
    intent = liveCloseIntent(short: short, hedge: hedge, reduceOnly: reduceOnly, market: market);
    closePositions = livePositionPayload(intent.context);
    queryPayload = liveQueryPayload(intent, status: 'FILLED');
  }

  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      test(
        'close rechecks position, POSTs once, then queries: short=$short hedge=$hedge',
        () async {
          close(short: short, hedge: hedge);
          final result = await submit();
          expect(result.status, 'FILLED');
          expect(result.checkedAt, liveOrderClock);
          expect(messages.length, 3);
          final signed = requests
              .where((r) => r.url.path.endsWith('/positionRisk') || r.url.path.endsWith('/order'))
              .toList();
          expect(signed.map((r) => r.method), ['GET', 'POST', 'GET']);
          expect(signed.first.url.path, '/fapi/v3/positionRisk');
          expect(signed.first.url.queryParameters['symbol'], 'BTCUSDT');
          final post = Uri.splitQueryString(signed[1].body);
          expect(post['side'], short ? 'BUY' : 'SELL');
          expect(post['positionSide'], intent.positionSide);
          expect(post['quantity'], '0.005');
          expect(post['reduceOnly'], hedge ? null : 'true');
          expect(post['closePosition'], null);
          expect(post['price'], null);
          expect(signed[1].body.split('&signature=').first, messages[1]);
          final nonces = [
            for (final r in signed)
              (r.method == 'POST' ? Uri.splitQueryString(r.body) : r.url.queryParameters)['nonce'],
          ];
          expect(nonces.toSet().length, 3);
        },
      );
    }
  }
  test('limit reduce-only uses rechecked BOTH position and exact limit terms', () async {
    close(short: true, reduceOnly: true, market: false);
    expect((await submit()).status, 'FILLED');
    final post = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
    expect(post['reduceOnly'], 'true');
    expect(post['side'], 'BUY');
    expect(post['positionSide'], 'BOTH');
    expect(post['price'], '80000');
    expect(post['timeInForce'], 'GTC');
  });
  for (final key in ['positionAmt', 'entryPrice', 'positionSide', 'leverage', 'marginType']) {
    test('changed $key after review stops close before POST', () async {
      close();
      closePositions!.single[key] = switch (key) {
        'positionAmt' => '0.009',
        'entryPrice' => '79001',
        'positionSide' => 'LONG',
        'leverage' => '20',
        _ => 'isolated',
      };
      await expectLater(
        submit(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveClosePositionChanged')),
      );
      expect(messages.length, 1);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  test('changed opposite hedge configuration also blocks the close', () async {
    close(hedge: true);
    closePositions!.last['leverage'] = '20';
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  for (final signature in [1, 2]) {
    test('refused close signature $signature sends no POST', () async {
      close();
      refusedSignature = signature;
      await expectLater(
        submit(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
    test('late approval on close signature $signature cannot POST', () async {
      close();
      afterSign = () {
        if (messages.length == signature) canSend = false;
      };
      await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  test('close cannot bypass over-quantity validation through repository', () async {
    close();
    intent = LiveOrderIntent(
      context: intent.context,
      draft: liveDraft(buy: false, market: true, closingSide: 'BOTH', quantity: '0.011'),
      clientOrderId: intent.clientOrderId,
      revision: 0,
    );
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveCloseTooLarge')),
    );
    expect(messages, isEmpty);
    expect(requests, isEmpty);
  });
  test('close timeout and refused query remain GET-only on recovery', () async {
    close();
    postTimeout = true;
    refusedSignature = 3;
    expect((await submit()).needsRecheck, true);
    refusedSignature = 0;
    expect((await recheck()).status, 'FILLED');
    expect(requests.where((r) => r.method == 'POST').length, 1);
    expect(requests.where((r) => r.url.path.endsWith('/positionRisk')).length, 1);
    expect(messages.length, 4);
  });
  test('preflight includes close position and book; bad book suppresses estimate only', () async {
    close();
    var context = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(context.positions['BOTH']!.quantity.toString(), '0.01');
    expect(context.estimatedClosePnl(intent.draft).toString(), '4.995');
    badBook = true;
    context = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(context.estimatedClosePnl(intent.draft), null);
    expect(context.validate(intent.draft), null);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  Future<LiveOrderContext> readContext({bool includeFunds = true}) => repository.read(
    address: accountAddress,
    symbol: 'BTCUSDT',
    isCurrent: () => current,
    onStep: (_) {},
    includeFunds: includeFunds,
  );

  test(
    'public bootstrap overlaps requests and each read operation calibrates its own clock once',
    () async {
      publicReadGate = Completer<void>();
      final pending = readContext();
      await Future<void>.delayed(Duration.zero);
      expect(requests.map((r) => r.url.path).toSet(), {
        '/fapi/v3/time',
        '/fapi/v3/exchangeInfo',
        '/fapi/v3/premiumIndex',
        '/fapi/v3/ticker/price',
        '/fapi/v3/ticker/bookTicker',
      });
      expect(messages, isEmpty);
      publicReadGate!.complete();
      await pending;
      expect(requests.where((r) => r.url.path.endsWith('/time')).length, 1);
      publicReadGate = null;
      await readContext();
      expect(requests.where((r) => r.url.path.endsWith('/time')).length, 2);
      final signed = requests.where((r) => r.url.queryParameters.containsKey('signature'));
      expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 8);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test('opening preflight separately signs asset mode and funds with exact query bytes', () async {
    assetModePayload = {'multiAssetsMargin': true};
    fundsPayload = {...accountPayload(), 'positions': <Map<String, dynamic>>[], 'canTrade': true};
    final context = await readContext();
    expect(context.funds!.assetMode.name, 'multi');
    expect(context.funds!.account.availableBalance.toString(), '89.000000000000000001');
    expect(context.funds!.account.receivedAt, liveOrderClock);
    expect(context.validate(liveDraft()), null);
    final signed = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
    expect(signed.map((r) => r.url.path), [
      '/fapi/v3/positionSide/dual',
      '/fapi/v3/positionRisk',
      '/fapi/v3/multiAssetsMargin',
      '/fapi/v3/accountWithJoinMargin',
    ]);
    expect(signed.map((r) => r.method).toSet(), {'GET'});
    expect(requests.where((r) => r.url.path.endsWith('/time')).length, 1);
    expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 4);
    for (var i = 0; i < signed.length; i++) {
      expect(signed[i].url.query.split('&signature=').first, messages[i]);
      expect(signed[i].url.queryParameters['user'], accountAddress);
      expect(signed[i].url.queryParameters['signer'], accountAddress);
    }
    expect(signed.last.url.queryParameters.containsKey('symbol'), false);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  for (final signature in [3, 4]) {
    test(
      'refused funding signature $signature preserves rules but cannot submit opening',
      () async {
        refusedSignature = signature;
        final context = await readContext();
        expect(context.rules.symbol, 'BTCUSDT');
        expect(context.funds, null);
        expect(context.fundsFailure!.key, 'authWalletRejected');
        expect(context.validate(liveDraft()), 'authWalletRejected');
        intent = LiveOrderIntent(
          context: context,
          draft: liveDraft(),
          clientOrderId: intent.clientOrderId,
          revision: 0,
        );
        await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
        expect(messages.length, signature);
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
      },
    );
  }
  test(
    'invalid asset mode does not request funds or pretend a successful opening preflight',
    () async {
      assetModePayload = {'multiAssetsMargin': 'true'};
      final context = await readContext();
      expect(context.funds, null);
      expect(context.fundsFailure!.key, 'accountDataInvalid');
      expect(messages.length, 3);
      expect(requests.where((r) => r.url.path.endsWith('/accountWithJoinMargin')), isEmpty);
    },
  );
  test('funds position mismatch is retained as partial failure without POST', () async {
    fundsPayload = accountPayload();
    final context = await readContext();
    expect(context.funds, null);
    expect(context.fundsFailure!.key, 'liveOrderFundsChanged');
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('closing preflight explicitly skips funds; normal entry cannot use that context', () async {
    final context = await readContext(includeFunds: false);
    expect(messages.length, 2);
    expect(context.funds, null);
    expect(context.validate(liveDraft()), 'liveOrderReadFunds');
    expect(
      requests.where(
        (r) =>
            r.url.path.endsWith('/accountWithJoinMargin') ||
            r.url.path.endsWith('/multiAssetsMargin'),
      ),
      isEmpty,
    );
  });
  test('identity change on funding signature discards entire response', () async {
    afterSign = () {
      if (messages.length == 3) current = false;
    };
    await expectLater(readContext(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.url.path.endsWith('/accountWithJoinMargin')), isEmpty);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  for (final signature in [3, 4]) {
    test(
      'expired funding signature $signature cannot send the read or start another prompt',
      () async {
        afterSign = () {
          if (messages.length == signature) clock = clock.add(const Duration(seconds: 30));
        };
        final context = await readContext();
        expect(context.funds, null);
        expect(context.fundsFailure!.key, 'liveOrderContextExpired');
        expect(context.receivedAt, liveOrderClock);
        expect(messages.length, signature);
        expect(requests.where((r) => r.url.path.endsWith('/accountWithJoinMargin')), isEmpty);
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
      },
    );
  }
}
