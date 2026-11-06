import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../domain/account_snapshot.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/live_order.dart';
import '../domain/main_order_capacity.dart';
import '../domain/main_order_account_facts.dart';
import '../domain/aster_open_orders.dart';
import '../domain/main_order_pending_exposure.dart';
import 'asset_index_repository.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'capacity_account_mapper.dart';
import 'futures_asset_mode_mapper.dart';
import 'futures_position_mode_mapper.dart';
import 'main_order_capacity_mapper.dart';
import 'main_order_risk_mapper.dart';
import 'openable_notional_mapper.dart';
import 'position_leverage_mapper.dart';
import 'signed_account_request.dart';

class SignedMainOrderCapacityRepository implements MainOrderCapacityRepository {
  SignedMainOrderCapacityRepository(
    this.service,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;

  @override
  Future<MainOrderCapacitySnapshot> read({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    void check() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final age = now().difference(context.receivedAt);
      if (age.isNegative || age >= const Duration(seconds: 30)) {
        throw const AccountReadFailure('liveOrderContextExpired');
      }
    }

    Future<Object?> read(
      Future<Object?> Function({required String query, required String signature}) send, {
      Map<String, String> parameters = const {},
    }) =>
        SignedAccountRequest(
          serverTime: () {
            check();
            return service.serverTime();
          },
          send: ({required query, required signature}) {
            check();
            return send(query: query, signature: signature);
          },
          sign: sign,
          nonces: nonces,
        ).read(
          address: context.address,
          parameters: parameters,
          isCurrent: () {
            check();
            return true;
          },
          onStep: (s) {
            check();
            onStep(s);
          },
        );
    try {
      check();
      if (context.funds == null || context.fundsFailure != null) {
        throw const AccountReadFailure('liveOrderReadFunds');
      }
      if (context.funds!.account.address.toLowerCase() != context.address.toLowerCase()) {
        throw const AccountReadFailure('authWalletChanged');
      }
      if (context.funds!.account.receivedAt.isBefore(context.receivedAt) ||
          context.funds!.account.receivedAt.isAfter(now())) {
        throw const AccountReadFailure('liveCapacityChanged');
      }
      validateLeverageSymbol(context.symbol);
      final units = await service.contractUnits();
      check();
      final assetMode = mapFuturesAssetMode(await read(service.assetMode));
      if (assetMode != context.funds!.assetMode) {
        throw const AccountReadFailure('liveCapacityChanged');
      }
      final positionMode = mapFuturesPositionMode(await read(service.positionMode));
      if (positionMode != context.mode) throw const AccountReadFailure('liveCapacityChanged');
      final account = mapCapacityAccount(
        await read(service.account),
        address: context.address,
        receivedAt: now(),
        units: units,
      );
      final positions = validateCapacityAccountContext(
        context: context,
        account: account,
        assetMode: assetMode,
        positionMode: positionMode,
        now: now(),
      );
      final orders = mapAsterOpenOrders(
        await read(service.openOrders),
        address: context.address,
        receivedAt: now(),
        units: units,
      );
      final selectedOrders = AsterOpenOrders(
        address: orders.address,
        receivedAt: orders.receivedAt,
        orders: orders.orders.where((o) => o.symbol == context.symbol),
        units: orders.units,
      );
      mainOrderPendingExposure(context: context, positions: positions, orders: selectedOrders);
      final riskPayload = await read(service.leverageBrackets);
      final requiredRiskSymbols = {
        context.symbol,
        for (final p in account.positions)
          if (!p.isolated && p.quantity != Decimal.zero) p.symbol,
      };
      final riskTiers = mapMainOrderRiskTiers(riskPayload, requiredRiskSymbols);
      final brackets = mapLeverageBrackets(
        (riskPayload as List).singleWhere((r) => (r as Map)['symbol'] == context.symbol),
        context.symbol,
      );
      final indices = assetMode == FuturesAssetMode.multi
          ? mapAssetIndices(await service.assetIndices(), receivedAt: now())
          : null;
      check();
      final contractCap = mapSymbolOpenableNotional(
        await service.remainingOpenableNotionalValue(
          symbol: context.symbol,
          leverage: context.leverage,
        ),
        symbol: context.symbol,
        leverage: context.leverage,
        receivedAt: now(),
      );
      check();
      final feePayload = await read(service.commissionRate, parameters: {'symbol': context.symbol});
      if (feePayload is! Map<String, dynamic> || feePayload['symbol'] != context.symbol) {
        throw const FormatException();
      }
      final fee = parseOrderDecimal(
        feePayload['takerCommissionRate'] is String
            ? feePayload['takerCommissionRate'] as String
            : '',
      );
      if (fee == null || fee < Decimal.zero || fee >= Decimal.one) {
        throw const FormatException();
      }
      check();
      return assembleMainOrderCapacity(
        context: context,
        account: account,
        assetMode: assetMode,
        positionMode: positionMode,
        orders: selectedOrders,
        brackets: brackets,
        contractCap: contractCap,
        indices: indices,
        now: now(),
        marketFacts: MainOrderAccountFacts(orders: orders, riskTiers: riskTiers, takerFee: fee),
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    } on ArgumentError {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
