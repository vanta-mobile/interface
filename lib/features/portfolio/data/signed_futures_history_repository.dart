import '../../../core/network/request_scope.dart';
import '../domain/aster_account.dart';
import '../domain/futures_history.dart';
import 'aster_account_service.dart';
import 'signed_account_request.dart';
import 'futures_history_mapper.dart';

class SignedFuturesHistoryRepository implements FuturesHistoryRepository {
  final AccountRequestAuthorization? authorization;
  SignedFuturesHistoryRepository(
    this.service,
    this.sign, {
    this.authorization,
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  @override
  Future<FuturesHistoryPage> read({
    required String address,
    required FuturesHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (!query.validSymbol) throw const AccountReadFailure('futuresHistoryInvalidSymbol');
    if (!query.validIncomeType) throw const AccountReadFailure('futuresHistoryInvalidType');
    if (!query.window.fitsRequest) throw const AccountReadFailure('futuresHistoryInvalidWindow');
    final request = SignedAccountRequest(
      serverTime: service.serverTime,
      send: switch (query.kind) {
        FuturesHistoryKind.orders => service.orderHistory,
        FuturesHistoryKind.trades => service.tradeHistory,
        FuturesHistoryKind.income => service.incomeHistory,
      },
      sign: sign,
      authorization: authorization,
      nonces: nonces,
    );
    final payload = await request.read(
      address: address,
      isCurrent: isCurrent,
      onStep: onStep,
      parameters: {
        if (query.symbol.isNotEmpty) 'symbol': query.symbol,
        if (query.incomeType.isNotEmpty) 'incomeType': query.incomeType,
        'startTime': '${query.window.start}',
        'endTime': '${query.window.end}',
        'limit': '${FuturesHistoryPage.limit}',
      },
    );
    final receivedAt = now();
    Map<String, AsterContractUnits> units = const {};
    if (query.kind != FuturesHistoryKind.income) {
      try {
        units = await service.contractUnits();
      } catch (_) {
        /* Retain signed rows with unknown units. */
      }
    }
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    try {
      return mapFuturesHistory(
        payload,
        address: address,
        query: query,
        receivedAt: receivedAt,
        units: units,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
