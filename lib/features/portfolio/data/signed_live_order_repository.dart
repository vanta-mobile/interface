import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../domain/account_snapshot.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/position_margin_mode.dart';
import 'aster_account_service.dart';
import 'futures_position_mode_mapper.dart';
import 'live_order_mapper.dart';
import 'position_configuration_rows.dart';
import 'position_leverage_mapper.dart';
import 'position_margin_mode_mapper.dart';
import 'signed_account_request.dart';
import 'futures_asset_mode_mapper.dart';
import 'live_order_funds_mapper.dart';
import '../domain/live_order_funds.dart';
import 'signed_attached_order_repository.dart';
import 'order_recovery_boundary.dart';
import 'signed_order_query_repository.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';

class SignedLiveOrderRepository implements LiveOrderRepository {
  SignedLiveOrderRepository(
    this.service,
    this.sign, {
    required this.nonces,
    this.journal,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  final OrderRecoveryJournal? journal;

  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(serverTime: service.serverTime, send: send, sign: sign, nonces: nonces);

  @override
  Future<LiveOrderContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
    bool includeFunds = true,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validatePositionSymbol(symbol);
      onStep(LiveOrderStep.preparing);
      final rules = mapLiveOrderRules(await service.get('/fapi/v3/exchangeInfo'), symbol);
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final markPayload = await service.get(
        '/fapi/v3/premiumIndex',
        query: Uri(queryParameters: {'symbol': symbol}).query,
      );
      final receivedAt = now();
      final serverMilliseconds = await service.serverTime();
      final mark = mapLiveMarkPrice(markPayload, symbol, serverMilliseconds);
      Decimal? lastPrice;
      try {
        lastPrice = mapLiveLastPrice(
          await service.get(
            '/fapi/v3/ticker/price',
            query: Uri(queryParameters: {'symbol': symbol}).query,
          ),
          symbol,
          serverMilliseconds,
        );
      } catch (_) {
        // Only Last-based triggers are unavailable. Mark and ordinary orders
        // must not silently use another price basis.
      }
      ({Decimal bid, Decimal ask})? book;
      try {
        book = mapLiveCloseBook(
          await service.get(
            '/fapi/v3/ticker/bookTicker',
            query: Uri(queryParameters: {'symbol': symbol}).query,
          ),
          symbol,
        );
      } catch (_) {
        // Missing book suppresses market close PnL and attached-entry previews.
        // Other ordinary orders can still use their documented references.
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      void progress(AccountReadStep step) {
        final age = now().difference(receivedAt);
        if (age.isNegative || age >= const Duration(seconds: 30)) {
          throw const AccountReadFailure('liveOrderContextExpired');
        }
        onStep(switch (step) {
          AccountReadStep.signing => LiveOrderStep.signingContext,
          AccountReadStep.loading => LiveOrderStep.loadingContext,
          _ => LiveOrderStep.preparing,
        });
      }

      final mode = mapFuturesPositionMode(
        await _request(service.positionMode)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
      );
      final rows = positionConfigurationRows(
        await _request(service.positionRisk).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        symbol,
      );
      final sides = rows.map((row) => row['positionSide']).toSet();
      if (mode == FuturesPositionMode.oneWay && !sides.contains('BOTH') ||
          mode == FuturesPositionMode.hedge && sides.contains('BOTH')) {
        throw const FormatException('Conflicting position mode');
      }
      int? leverage;
      PositionMarginMode? margin;
      for (final row in rows) {
        final raw = row['leverage'];
        final parsed = raw is String && RegExp(r'^[1-9]\d{0,3}$').hasMatch(raw)
            ? int.parse(raw)
            : null;
        final rowMargin = switch (row['marginType']) {
          'cross' => PositionMarginMode.cross,
          'isolated' => PositionMarginMode.isolated,
          _ => null,
        };
        if (parsed == null ||
            rowMargin == null ||
            leverage != null && leverage != parsed ||
            margin != null && margin != rowMargin) {
          throw const FormatException('Conflicting symbol configuration');
        }
        leverage = parsed;
        margin = rowMargin;
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final positions = mapLiveOrderPositions(rows, symbol, mode);
      LiveOrderFunds? funds;
      AccountReadFailure? fundsFailure;
      if (includeFunds) {
        try {
          final assetMode = mapFuturesAssetMode(
            await _request(service.assetMode)
                .read(address: address, isCurrent: isCurrent, onStep: progress),
          );
          funds = mapLiveOrderFunds(
            await _request(service.account)
                .read(address: address, isCurrent: isCurrent, onStep: progress),
            address: address,
            symbol: symbol,
            receivedAt: now(),
            assetMode: assetMode,
            marginMode: margin!,
            leverage: leverage!,
            positions: positions,
          );
        } on AccountReadFailure catch (failure) {
          if (!isCurrent()) rethrow;
          fundsFailure = failure;
        } on FormatException {
          fundsFailure = const AccountReadFailure('accountDataInvalid');
        }
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return LiveOrderContext(
        address: address,
        rules: rules,
        mode: mode,
        marginMode: margin!,
        leverage: leverage!,
        markPrice: mark,
        receivedAt: receivedAt,
        positions: positions,
        bid: book?.bid,
        ask: book?.ask,
        funds: funds,
        fundsFailure: fundsFailure,
        lastPrice: lastPrice,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    final context = intent.context;
    if (!RegExp(r'^[.A-Z:/a-z0-9_-]{1,36}$').hasMatch(intent.clientOrderId) ||
        intent.draft.attachment != null && intent.clientOrderId.length > 28) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final invalid = intent.executionContext.validate(intent.draft);
    if (invalid != null) throw AccountReadFailure(invalid);
    if (intent.draft.reducing || intent.draft.attachment != null) {
      await _verifyPositionSnapshot(intent, isCurrent, canSubmit, onStep);
    }
    if (intent.draft.attachment != null) {
      return SignedAttachedOrderRepository(
        service,
        sign,
        nonces,
        now,
        journal: journal,
      ).submit(intent: intent, isCurrent: isCurrent, canSubmit: canSubmit, onStep: onStep);
    }
    var submitted = false;
    try {
      await _request(({required query, required signature}) async {
        // Check again after the wallet prompt, immediately before the POST.
        if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
        await persistOrderBeforePost(journal, intent, now(), canSubmit);
        if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
        submitted = true;
        onStep(LiveOrderStep.submitting);
        return service.newOrder(query: query, signature: signature);
      }).read(
        address: context.address,
        parameters: intent.parameters,
        isCurrent: isCurrent,
        onStep: (step) {
          if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
          if (step != AccountReadStep.loading) {
            onStep(
              step == AccountReadStep.signing ? LiveOrderStep.signing : LiveOrderStep.preparing,
            );
          }
        },
      );
    } on AccountReadFailure catch (failure) {
      // A refused signature cannot have placed an order. After the POST boundary,
      // only query the frozen client ID; never repeat the placement request.
      if (!submitted || !isCurrent()) rethrow;
      final checked = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
      return checked.orderId == null
          ? LiveOrderResult(failure: checked.failure ?? failure)
          : checked;
    }
    return recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
  });

  Future<void> _verifyPositionSnapshot(
    LiveOrderIntent intent,
    bool Function() isCurrent,
    bool Function() canSubmit,
    void Function(LiveOrderStep) onStep,
  ) async {
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    final context = intent.context;
    final changed = intent.draft.attachment != null
        ? 'attachedOrderPositionChanged'
        : 'liveClosePositionChanged';
    final payload = await _request(service.positionRisk).read(
      address: context.address,
      parameters: {'symbol': context.symbol},
      isCurrent: isCurrent,
      onStep: (step) {
        if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
        onStep(
          step == AccountReadStep.signing
              ? LiveOrderStep.signingPosition
              : LiveOrderStep.checkingPosition,
        );
      },
    );
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    try {
      final positions = mapLiveOrderPositions(payload, context.symbol, context.mode);
      final position = positions[intent.positionSide];
      final reviewed = context.reductionPosition(intent.draft);
      final attached = intent.draft.attachment != null;
      final comparedSides = attached ? context.positions.keys : [intent.positionSide];
      if ((!attached && (position == null || reviewed == null)) ||
          comparedSides.any(
            (side) =>
                positions[side]?.quantity != context.positions[side]?.quantity ||
                positions[side]?.entryPrice != context.positions[side]?.entryPrice,
          ) ||
          mapCurrentLeverage(payload, context.symbol) != context.leverage ||
          mapMarginConfiguration(payload, context.symbol).mode != context.marginMode) {
        throw AccountReadFailure(changed);
      }
    } on FormatException {
      throw AccountReadFailure(changed);
    }
  }

  @override
  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    return SignedOrderQueryRepository(
      service,
      sign,
      nonces,
      now,
      journal: journal,
    ).query(OrderQuery.capture(intent), isCurrent: isCurrent, onStep: onStep);
  });
}
