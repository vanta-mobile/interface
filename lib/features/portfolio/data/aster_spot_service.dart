import 'aster_read_service.dart';

class AsterSpotService extends AsterReadService {
  AsterSpotService({super.client, super.timeout})
    : super(origin: Uri.https('sapi.asterdex.com'), timePath: '/api/v3/time');
  static const accountPath = '/api/v3/account';

  Future<Object?> account({required String query, required String signature}) =>
      signedGet(accountPath, query: query, signature: signature);

  /// One explicit complete Spot baseline; no Perp symbol is imposed.
  Future<Object?> openOrders({required String query, required String signature}) =>
      signedGet('/api/v3/openOrders', query: query, signature: signature);

  Future<Object?> orderHistory({required String query, required String signature}) =>
      signedGet('/api/v3/allOrders', query: query, signature: signature);

  Future<Object?> tradeHistory({required String query, required String signature}) =>
      signedGet('/api/v3/userTrades', query: query, signature: signature);

  Future<Object?> transactionHistory({required String query, required String signature}) =>
      signedGet('/api/v3/transactionHistory', query: query, signature: signature);

  /// POST starts or explicitly renews the authenticated account's lease.
  Future<Object?> userStream({required String query, required String signature}) =>
      signedPost('/api/v3/listenKey', query: query, signature: signature);

  Future<Object?> exchangeInfo() => get('/api/v3/exchangeInfo');
}
