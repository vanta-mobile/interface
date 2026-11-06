import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../../../core/domain/wallet_operation.dart';
import '../domain/position_margin_adjustment.dart';
import '../domain/position_risk.dart';
import '../domain/aster_account.dart';
import 'aster_account_service.dart';
import 'aster_account_mapper.dart';
import 'position_configuration_rows.dart';
import 'position_risk_mapper.dart';
import 'position_margin_mapper.dart';
import 'signed_account_request.dart';

class SignedPositionMarginRepository implements PositionMarginRepository {
  SignedPositionMarginRepository(
    this.service,
    this.sign,
    this.journal, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final WalletOperationJournal journal;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  int _recordNonce = 0;
  SignedAccountRequest request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(serverTime: service.serverTime, send: send, sign: sign, nonces: nonces);

  @override
  Future<PositionMarginContext> read({
    required String address,
    required String symbol,
    required String side,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validatePositionSymbol(symbol);
      if (!{'BOTH', 'LONG', 'SHORT'}.contains(side)) throw const FormatException();
      void progress(AccountReadStep s) => onStep(
        s == AccountReadStep.signing ? MarginAdjustmentStep.signing : MarginAdjustmentStep.reading,
      );
      final units = await service.contractUnits();
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final unit = units[symbol];
      if (unit == null || unit.margin != unit.quote) {
        throw const AccountReadFailure('marginAdjustUnsupported');
      }
      final receivedAt = now();
      final account = mapAsterAccount(
        await request(service.account)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
        address: address,
        receivedAt: receivedAt,
        units: units,
      );
      final risks = mapPositionRisk(
        await request(service.positionRisk).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        address: address,
        receivedAt: receivedAt,
        units: units,
      );
      final p = risks.positions
          .where((p) => p.symbol == symbol && p.side == side && !p.balanceOnly)
          .singleOrNull;
      if (p == null) throw const AccountReadFailure('marginAdjustClosed');
      if (!p.isolated) throw const AccountReadFailure('marginAdjustUnsupported');
      final same = account.positions
          .where((p) => p.symbol == symbol && p.side == side)
          .singleOrNull;
      if (same == null ||
          same.isolated != true ||
          same.quantity != p.quantity ||
          same.entryPrice != p.entryPrice ||
          same.isolatedWallet != p.isolatedWallet ||
          same.leverage != p.leverage) {
        throw const AccountReadFailure('marginAdjustChanged');
      }
      final tiers = mapMarginRiskTiers(
        await request(service.leverageBrackets).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        symbol,
      );
      if (p.markPrice == null || p.markPrice! <= Decimal.zero || p.entryPrice <= Decimal.zero) {
        throw const FormatException();
      }
      return PositionMarginContext(
        account: account,
        position: p,
        receivedAt: receivedAt,
        tiers: tiers,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<MarginAdjustmentResult> change({
    required PositionMarginIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginAdjustmentStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final c = intent.context, p = c.position;
    bool freshEnough(PositionMarginContext context) {
      final age = now().difference(context.receivedAt);
      return age >= Duration.zero && age < const Duration(seconds: 30);
    }

    if (!isCurrent() || !canSubmit() || !freshEnough(c)) {
      throw const AccountReadFailure('marginAdjustExpired');
    }
    if (c.amount(intent.amount.toString(), intent.direction) != intent.amount ||
        !RegExp(r'^vm_[a-f0-9]{32}$').hasMatch(intent.reference)) {
      throw const AccountReadFailure('marginAdjustAmount');
    }
    final fresh = await read(
      address: c.account.address,
      symbol: p.symbol,
      side: p.side,
      isCurrent: isCurrent,
      onStep: onStep,
    );
    if (!c.samePosition(fresh)) throw const AccountReadFailure('marginAdjustChanged');
    if (fresh.amount(intent.amount.toString(), intent.direction) != intent.amount) {
      throw const AccountReadFailure('marginAdjustAmount');
    }
    final candidate = now().microsecondsSinceEpoch;
    _recordNonce = candidate > _recordNonce ? candidate : _recordNonce + 1;
    final record = WalletOperationRecord(
      kind: WalletOperationKind.isolatedMargin,
      address: c.account.address,
      nonce: _recordNonce,
      preparedAt: now(),
      terms: {
        'symbol': p.symbol,
        'side': p.side,
        'asset': c.asset,
        'amount': intent.amount.toString(),
        'type': intent.direction == MarginDirection.add ? '1' : '2',
        'clientTranId': intent.reference,
      },
    );
    var sent = false, saved = false;
    AccountReadFailure? rejection;
    try {
      await request(({required query, required signature}) async {
        if (!canSubmit() || !freshEnough(fresh)) {
          throw const AccountReadFailure('marginAdjustExpired');
        }
        try {
          await journal.prepare(record);
          saved = true;
        } catch (_) {
          throw const AccountReadFailure('marginAdjustStorage');
        }
        if (!canSubmit() || !freshEnough(fresh)) {
          throw const AccountReadFailure('marginAdjustExpired');
        }
        onStep(MarginAdjustmentStep.submitting);
        sent = true;
        try {
          return await service.positionMargin(query: query, signature: signature);
        } on AccountReadFailure catch (e) {
          // Only documented explicit rejections prove this request did not run.
          if ({-1021, -1022, -2014, -2015, -4049, -4050, -4051, -4054, -4055}.contains(e.code)) {
            rejection = AccountReadFailure(
              switch (e.code) {
                -4049 => 'marginAdjustUnsupported',
                -4050 || -4051 => 'marginAdjustInsufficient',
                -4054 => 'marginAdjustClosed',
                -4055 => 'marginAdjustAmount',
                _ => e.key,
              },
              code: e.code,
              details: e.details,
            );
            try {
              await journal.report(record.key, 'rejected:${e.code}');
            } catch (_) {
              throw const AccountReadFailure('marginAdjustStorage');
            }
          }
          rethrow;
        }
      }).read(
        address: record.address,
        parameters: {
          'symbol': p.symbol,
          'positionSide': p.side,
          'amount': record.terms['amount']!,
          'type': record.terms['type']!,
          'clientTranId': intent.reference,
        },
        isCurrent: isCurrent,
        onStep: (s) => onStep(
          s == AccountReadStep.signing
              ? MarginAdjustmentStep.signing
              : MarginAdjustmentStep.reading,
        ),
      );
    } catch (e) {
      if (!sent) {
        if (saved) {
          try {
            await journal.removeNotSent(record.key);
          } catch (_) {}
        }
        rethrow;
      }
      // Even a late response belongs to the original wallet. Its public intent
      // stays durable and can only be resolved by exact history evidence.
      if (!isCurrent()) {
        return MarginAdjustmentResult(
          record: record,
          failure: const AccountReadFailure('marginAdjustUnknown'),
        );
      }
    }
    if (rejection != null &&
        journal.snapshot.records.any((r) => r.key == record.key && r.acknowledged) &&
        !journal.snapshot.failed) {
      PositionMarginContext? refreshed;
      if (isCurrent()) {
        try {
          refreshed = await read(
            address: record.address,
            symbol: p.symbol,
            side: p.side,
            isCurrent: isCurrent,
            onStep: onStep,
          );
        } catch (_) {} // Keep the concrete rejection and the original input.
      }
      return MarginAdjustmentResult(
        record: record.reported('rejected:${rejection!.code}'),
        failure: rejection,
        context: refreshed,
        checkedAt: now(),
      );
    }
    return check(record: record, isCurrent: isCurrent, onStep: onStep);
  });

  @override
  Future<MarginAdjustmentResult> check({
    required WalletOperationRecord record,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    DateTime? matched;
    PositionRisk? position;
    PositionMarginContext? context;
    AsterAccount? actualAccount;
    PositionRiskSnapshot? actualPositions;
    AccountReadFailure? failure;
    try {
      if (record.kind != WalletOperationKind.isolatedMargin) throw const FormatException();
      final stored = journal.snapshot.records.where((r) => r.key == record.key).singleOrNull;
      if (stored == null ||
          stored.terms.length != record.terms.length ||
          stored.terms.entries.any((e) => record.terms[e.key] != e.value) ||
          stored.reference?.startsWith('rejected:') == true) {
        throw const FormatException();
      }
      final terms = record.terms;
      final history = await request(service.marginHistory).read(
        address: record.address,
        parameters: {
          'symbol': terms['symbol']!,
          'type': terms['type']!,
          'startTime': '${record.preparedAt.millisecondsSinceEpoch - 30000}',
          'endTime':
              '${now().millisecondsSinceEpoch < record.preparedAt.millisecondsSinceEpoch ? record.preparedAt.millisecondsSinceEpoch : now().millisecondsSinceEpoch}',
          'limit': '500',
        },
        isCurrent: isCurrent,
        onStep: (_) => onStep(MarginAdjustmentStep.checking),
      );
      matched = matchMarginHistory(history, record, now());
      if (matched != null) {
        try {
          await journal.report(record.key, terms['clientTranId']);
        } catch (_) {
          throw const AccountReadFailure('marginAdjustStorage');
        }
      }
      final units = await service.contractUnits();
      final receipt = now();
      final risks = mapPositionRisk(
        await request(service.positionRisk).read(
          address: record.address,
          isCurrent: isCurrent,
          onStep: (_) => onStep(MarginAdjustmentStep.checking),
        ),
        address: record.address,
        receivedAt: receipt,
        units: units,
      );
      actualPositions = risks;
      position = risks.positions
          .where((p) => p.symbol == terms['symbol'] && p.side == terms['side'])
          .singleOrNull;
      // Read both the actual remaining position and account balances; neither
      // is used to guess whether an unmatched adjustment happened.
      final account = mapAsterAccount(
        await request(service.account).read(
          address: record.address,
          isCurrent: isCurrent,
          onStep: (_) => onStep(MarginAdjustmentStep.checking),
        ),
        address: record.address,
        receivedAt: now(),
        units: units,
      );
      actualAccount = account;
      if (position != null &&
          !position.balanceOnly &&
          position.isolated &&
          position.units != null) {
        final tiers = mapMarginRiskTiers(
          await request(service.leverageBrackets).read(
            address: record.address,
            parameters: {'symbol': terms['symbol']!},
            isCurrent: isCurrent,
            onStep: (_) => onStep(MarginAdjustmentStep.checking),
          ),
          terms['symbol']!,
        );
        final same = account.positions
            .where((p) => p.symbol == position!.symbol && p.side == position.side)
            .singleOrNull;
        if (same != null &&
            same.quantity == position.quantity &&
            same.entryPrice == position.entryPrice &&
            same.isolated == true &&
            same.isolatedWallet == position.isolatedWallet &&
            same.leverage == position.leverage) {
          context = PositionMarginContext(
            account: account,
            position: position,
            receivedAt: receipt,
            tiers: tiers,
          );
        }
      }
    } catch (e) {
      failure = e is AccountReadFailure ? e : const AccountReadFailure('accountDataInvalid');
    }
    return MarginAdjustmentResult(
      record: record,
      verified:
          matched != null &&
          journal.snapshot.records.any((r) => r.key == record.key && r.acknowledged) &&
          !journal.snapshot.failed,
      position: position,
      context: context,
      account: actualAccount,
      positions: actualPositions,
      checkedAt: now(),
      failure:
          failure ?? (matched == null ? const AccountReadFailure('marginAdjustUnknown') : null),
    );
  });
}
