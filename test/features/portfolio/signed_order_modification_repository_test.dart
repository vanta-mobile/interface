import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_order_cancellation_repository.dart';
import 'package:vanta/features/portfolio/data/signed_order_modification_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_modification.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/wallet_connection.dart';

void main() {
  final order = openOrdersFixture().orders.firstWhere((o) => o.symbol == 'BTCUSDT');
  final request = OrderModification(
    order: order,
    price: Decimal.parse('79000.5'),
    quantity: Decimal.parse('0.5'),
  );
  late List<http.Request> requests;
  late Object? putPayload, queryPayload;
  late int putStatus, queryStatus;
  late bool refuseSignature;
  late AsterAccountService service;
  late SignedOrderModificationRepository repository;

  Map<String, Object?> modified() => openOrder(price: '79000.50', origQty: '0.500')..remove('time');

  setUp(() {
    requests = [];
    putPayload = modified();
    queryPayload = openOrder();
    putStatus = queryStatus = 200;
    refuseSignature = false;
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/time')) {
          return http.Response('{"serverTime":1793620800123}', 200);
        }
        expect(r.url.path, '/fapi/v3/order');
        if (r.method == 'PUT') return http.Response(jsonEncode(putPayload), putStatus);
        expect(r.method, 'GET');
        return http.Response(jsonEncode(queryPayload), queryStatus);
      }),
    );
    Future<String> sign({required expectedAddress, required typedData}) async {
      if (refuseSignature) throw const AuthFailure('authWalletRejected');
      return TestWalletConnection.signature;
    }

    final nonces = AsterReadNonces();
    repository = SignedOrderModificationRepository(
      service,
      sign,
      verifier: SignedOrderCancellationRepository(service, sign, nonces: nonces),
      nonces: nonces,
    );
  });
  tearDown(() => service.close());

  Future<OrderModificationResult> modify() => repository.modify(
    address: accountAddress,
    request: request,
    isCurrent: () => true,
    onStep: (_) {},
  );

  List<String> methods() =>
      requests.where((r) => r.url.path == '/fapi/v3/order').map((r) => r.method).toList();

  test('PUT signs symbol, id, side, absolute quantity and price once', () async {
    final result = await modify();
    expect(result.outcome, OrderModifyOutcome.modified);
    expect(result.order?.price, Decimal.parse('79000.5'));
    expect(result.order?.origQty, Decimal.parse('0.5'));
    expect(result.order?.time, order.time);
    expect(methods(), ['PUT']);
    final query = requests.last.url.queryParameters;
    expect(query['symbol'], 'BTCUSDT');
    expect(query['orderId'], '1917641');
    expect(query['side'], 'BUY');
    expect(query['quantity'], '0.5');
    expect(query['price'], '79000.5');
    expect(query['signature'], TestWalletConnection.signature);
  });

  test('an explicit Aster rejection keeps the order without a query', () async {
    putStatus = 400;
    putPayload = {'code': -4014, 'msg': 'Price not increased by tick size.'};
    final result = await modify();
    expect(result.outcome, OrderModifyOutcome.rejected);
    expect(result.order, order);
    expect(result.failure?.details?.message, 'Price not increased by tick size.');
    expect(methods(), ['PUT']);
  });

  test('an ambiguous failure is verified by one query and never resent', () async {
    putStatus = 503;
    putPayload = {'code': -1007, 'msg': 'Timeout waiting for response from backend server.'};
    queryPayload = openOrder(price: '79000.5', origQty: '0.5');
    var result = await modify();
    expect(result.outcome, OrderModifyOutcome.modified);
    expect(methods(), ['PUT', 'GET']);

    requests.clear();
    queryPayload = openOrder();
    result = await modify();
    expect(result.outcome, OrderModifyOutcome.rejected);
    expect(result.order?.price, order.price);
    expect(result.failure?.code, -1007);
    expect(methods(), ['PUT', 'GET']);

    requests.clear();
    queryPayload = openOrder(status: 'FILLED', executedQty: '0.40');
    result = await modify();
    expect(result.outcome, OrderModifyOutcome.rejected);
    expect(result.closed, true);
    expect(result.order, null);
  });

  test('an unreadable result stays unknown', () async {
    putStatus = 502;
    putPayload = {'msg': 'bad gateway'};
    queryStatus = 503;
    queryPayload = {'msg': 'unavailable'};
    final result = await modify();
    expect(result.outcome, OrderModifyOutcome.unknown);
    expect(result.order, null);
    expect(methods(), ['PUT', 'GET']);
  });

  test('a malformed success response is verified instead of trusted', () async {
    putPayload = openOrder(price: '1', origQty: '0.5');
    queryPayload = openOrder(price: '79000.5', origQty: '0.5');
    final result = await modify();
    expect(result.outcome, OrderModifyOutcome.modified);
    expect(methods(), ['PUT', 'GET']);
  });

  test('a refused signature sends nothing', () async {
    refuseSignature = true;
    await expectLater(modify(), throwsA(isA<AccountReadFailure>()));
    expect(methods(), isEmpty);
  });
}
