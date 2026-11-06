import '../../../core/network/request_scope.dart';
import '../domain/aster_account.dart';
import '../domain/strategy_execution.dart';
import '../domain/order_recovery.dart';
import 'order_recovery_codec.dart';
import 'aster_account_service.dart';
import 'attached_order_mapper.dart';
import 'signed_account_request.dart';
import 'strategy_execution_mapper.dart';

/// Explicit read-only action. Does not complete journals, replay strategies or
/// infer ordinary-order executions from strategy statuses / planned quantities.
class SignedStrategyExecutionRepository implements StrategyExecutionRepository {
  SignedStrategyExecutionRepository(this.service, this.sign, this.nonces, this.now);
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;

  @override
  Future<StrategyExecutionSnapshot> read(
    StrategyExecutionQuery query, {
    required bool Function() isCurrent,
    required void Function(AccountReadStep step, int? sequence) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (query.order.draft.attachment == null ||
        !RegExp(r'^[1-9]\d{0,30}$').hasMatch(query.strategyId)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    // Validate the complete frozen query before asking the wallet to sign.
    try {
      decodeRecoveryRecord(
        encodeRecoveryRecord(OrderRecoveryRecord(query: query.order, createdAt: now())),
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
    Future<Object?> read(
      Future<Object?> Function({required String query, required String signature}) send,
      Map<String, String> parameters,
      int? sequence,
    ) =>
        SignedAccountRequest(
          serverTime: service.serverTime,
          send: send,
          sign: sign,
          nonces: nonces,
        ).read(
          address: query.order.address,
          isCurrent: isCurrent,
          parameters: parameters,
          onStep: (step) => onStep(step, sequence),
        );
    try {
      final params = {
        'clientStrategyId': query.order.clientOrderId,
        'strategyType': query.order.draft.attachment!.strategyType,
      };
      Object? payload;
      try {
        payload = await read(service.strategyOpenOrder, params, null);
      } on AccountReadFailure catch (failure) {
        if (failure.code != -2013 || !isCurrent()) rethrow;
        payload = await read(service.strategyHistoryOrder, params, null);
      }
      final strategyAt = now();
      final strategy = mapRecoveredStrategyQuery(payload, query.order, strategyAt).strategy!;
      if (strategy.strategyId != query.strategyId) {
        throw const FormatException('Different strategy ID');
      }
      final legs = <StrategyExecutionLeg>[];
      var stopped = false;
      for (final leg in strategy.legs) {
        if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
        if (leg.orderId == null || stopped) {
          legs.add(
            StrategyExecutionLeg(
              strategyLeg: leg,
              failure: stopped && leg.orderId != null
                  ? const AccountReadFailure('strategyExecutionSkipped')
                  : null,
            ),
          );
          continue;
        }
        try {
          final result = await read(service.queryOrder, {
            'symbol': query.order.symbol,
            'orderId': leg.orderId!,
          }, leg.sequence);
          legs.add(
            StrategyExecutionLeg(
              strategyLeg: leg,
              execution: mapStrategyLegExecution(
                result,
                query: query,
                sequence: leg.sequence,
                orderId: leg.orderId!,
                checkedAt: now(),
              ),
            ),
          );
        } catch (error) {
          if (!isCurrent()) rethrow;
          legs.add(
            StrategyExecutionLeg(
              strategyLeg: leg,
              failure: error is AccountReadFailure
                  ? error
                  : const AccountReadFailure('accountDataInvalid'),
            ),
          );
          stopped = true; // A refusal/failure must not lead to more wallet prompts.
        }
      }
      AsterContractUnits? units;
      try {
        units = (await service.contractUnits())[query.order.symbol];
      } catch (_) {
        /* Show unknown units. */
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return StrategyExecutionSnapshot(
        query: query,
        strategy: strategy,
        strategyCheckedAt: strategyAt,
        receivedAt: now(),
        legs: legs,
        units: units,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
