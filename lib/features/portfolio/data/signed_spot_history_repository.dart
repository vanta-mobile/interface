import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/spot_history.dart';
import 'aster_spot_service.dart';
import 'signed_account_request.dart';
import 'spot_history_mapper.dart';

class SignedSpotHistoryRepository implements SpotHistoryRepository {
  final AccountRequestAuthorization? authorization;
  SignedSpotHistoryRepository(
    this.service,
    this.sign, {
    this.authorization,
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterSpotService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  Map<String, SpotSymbolUnits>? _units;

  @override
  Future<SpotHistoryPage> read({
    required String address,
    required SpotHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (!query.validScope) throw const AccountReadFailure('historyInvalidScope');
    if (!query.window.fitsRequest) throw const AccountReadFailure('historyInvalidWindow');
    final request = SignedAccountRequest(
      serverTime: service.serverTime,
      send: switch (query.kind) {
        SpotHistoryKind.orders => service.orderHistory,
        SpotHistoryKind.trades => service.tradeHistory,
        SpotHistoryKind.transactions => service.transactionHistory,
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
        if (query.scope.isNotEmpty)
          query.kind == SpotHistoryKind.transactions ? 'asset' : 'symbol': query.scope,
        'startTime': '${query.window.start}',
        'endTime': '${query.window.end}',
        'limit': '${SpotHistoryPage.limit}',
      },
    );
    if (query.kind != SpotHistoryKind.transactions && _units == null) {
      try {
        _units = mapSpotSymbolUnits(await service.exchangeInfo());
      } catch (_) {
        /* History remains useful with units explicitly unavailable. */
      }
    }
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    try {
      return mapSpotHistory(
        payload,
        address: address,
        query: query,
        receivedAt: now(),
        units: _units ?? const {},
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
