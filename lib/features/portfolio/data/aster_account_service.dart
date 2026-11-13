import '../domain/aster_account.dart';
import 'aster_account_mapper.dart';
import 'aster_read_service.dart';
import 'position_configuration_rows.dart';

class AsterAccountService extends AsterReadService {
  AsterAccountService({super.client, super.timeout, super.decodeResponse})
    : super(origin: Uri.https('fapi.asterdex.com'), timePath: '/fapi/v3/time');
  static const accountPath = '/fapi/v3/accountWithJoinMargin';
  static const openOrdersPath = '/fapi/v3/openOrders';

  Future<Object?> subaccountList({required String query, required String signature}) =>
      signedGet('/fapi/v3/getSubAccountList', query: query, signature: signature);

  Future<Object?> assetIndices() => get('/fapi/v1/assetIndex');

  /// Public symbol-level open-interest cap. No wallet address or signature.
  Future<Object?> remainingOpenableNotionalValue({required String symbol, required int leverage}) {
    validatePositionSymbol(symbol);
    if (leverage <= 0) throw const FormatException('Invalid leverage');
    return get(
      '/fapi/v3/remainingOpenableNotionalValue',
      query: Uri(queryParameters: {'symbol': symbol, 'leverage': '$leverage'}).query,
    );
  }

  /// Read-only funding POST; uses the V3 microsecond query signature.
  Future<Object?> withdrawInfo({required String query, required String signature}) =>
      signedPostQuery('/fapi/v3/aster/user-withdraw-info', query: query, signature: signature);

  /// Read-only POST, covering both markets; no documented pagination filters.
  Future<Object?> transferHistory({required String query, required String signature}) =>
      signedPostQuery(
        '/fapi/v3/aster/deposit-withdraw-history',
        query: query,
        signature: signature,
      );

  Future<Object?> account({required String query, required String signature}) =>
      signedGet(accountPath, query: query, signature: signature);

  Future<Object?> positionRisk({required String query, required String signature}) =>
      signedGet('/fapi/v3/positionRisk', query: query, signature: signature);

  Future<Object?> leverageBrackets({required String query, required String signature}) =>
      signedGet('/fapi/v3/leverageBrackets', query: query, signature: signature);

  Future<Object?> positionMargin({required String query, required String signature}) =>
      signedPost('/fapi/v3/positionMargin', query: query, signature: signature);

  Future<Object?> marginHistory({required String query, required String signature}) =>
      signedGet('/fapi/v3/positionMargin/history', query: query, signature: signature);

  Future<Object?> changeLeverage({required String query, required String signature}) =>
      signedPost('/fapi/v3/leverage', query: query, signature: signature);

  Future<Object?> changeMarginMode({required String query, required String signature}) =>
      signedPost('/fapi/v3/marginType', query: query, signature: signature);

  Future<Object?> positionMode({required String query, required String signature}) =>
      signedGet('/fapi/v3/positionSide/dual', query: query, signature: signature);

  Future<Object?> changePositionMode({required String query, required String signature}) =>
      signedPost('/fapi/v3/positionSide/dual', query: query, signature: signature);

  Future<Object?> assetMode({required String query, required String signature}) =>
      signedGet('/fapi/v3/multiAssetsMargin', query: query, signature: signature);

  Future<Object?> changeAssetMode({required String query, required String signature}) =>
      signedPost('/fapi/v3/multiAssetsMargin', query: query, signature: signature);

  Future<Object?> assetExchange({required String query, required String signature}) => signedPost(
    '/fapi/v3/assetExchange',
    query: query,
    signature: signature,
    allowEmptyResponse: true,
  );

  /// POST also extends an existing active key, as specified by USER_STREAM.
  Future<Object?> userStream({required String query, required String signature}) =>
      signedPost('/fapi/v3/listenKey', query: query, signature: signature);

  /// Omitting symbol requests all of the current account's open futures
  /// orders. The UI applies its current-symbol filter to this snapshot.
  Future<Object?> openOrders({required String query, required String signature}) =>
      signedGet(openOrdersPath, query: query, signature: signature);

  Future<Object?> cancelOrder({required String query, required String signature}) =>
      signedDelete('/fapi/v3/order', query: query, signature: signature);

  /// LIMIT orders only; price and quantity are both required by Aster.
  Future<Object?> modifyOrder({required String query, required String signature}) =>
      signedPut('/fapi/v3/order', query: query, signature: signature);

  Future<Object?> queryOrder({required String query, required String signature}) =>
      signedGet('/fapi/v3/order', query: query, signature: signature);

  Future<Object?> orderHistory({required String query, required String signature}) =>
      signedGet('/fapi/v3/allOrders', query: query, signature: signature);

  Future<Object?> tradeHistory({required String query, required String signature}) =>
      signedGet('/fapi/v3/userTrades', query: query, signature: signature);

  Future<Object?> incomeHistory({required String query, required String signature}) =>
      signedGet('/fapi/v3/income', query: query, signature: signature);

  Future<Object?> commissionRate({required String query, required String signature}) =>
      signedGet('/fapi/v3/commissionRate', query: query, signature: signature);

  Future<Object?> newOrder({required String query, required String signature}) =>
      signedPost('/fapi/v3/order', query: query, signature: signature);

  Future<Object?> placeStrategyOrder({required String query, required String signature}) =>
      signedPost('/fapi/v3/placeStrategyOrder', query: query, signature: signature);

  Future<Object?> strategyOpenOrder({required String query, required String signature}) =>
      signedGet('/fapi/v3/strategyOpenOrder', query: query, signature: signature);

  Future<Object?> strategyHistoryOrder({required String query, required String signature}) =>
      signedGet('/fapi/v3/strategyHistoryOrder', query: query, signature: signature);

  Future<Object?> cancelAllOrders({required String query, required String signature}) =>
      signedDelete('/fapi/v3/allOpenOrders', query: query, signature: signature);

  Future<Map<String, AsterContractUnits>> contractUnits() async =>
      mapAsterContractUnits(await get('/fapi/v3/exchangeInfo'));
}
