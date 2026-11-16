import 'package:decimal/decimal.dart';

import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';
import '../../authorization/data/builder_authorization_repository.dart';
import '../../authorization/domain/builder_authorization.dart';
import '../domain/account_snapshot.dart';
import '../domain/builder_order_fee.dart';
import '../domain/live_order.dart';
import 'aster_account_service.dart';
import 'signed_account_request.dart';

BuilderCommissionRates mapBuilderCommissionRates(Object? payload, String symbol) {
  if (payload is! Map<String, dynamic> || payload['symbol'] != symbol) {
    throw const FormatException();
  }
  Decimal rate(String key) {
    final raw = payload[key];
    final value = raw is String ? parseOrderDecimal(raw) : null;
    if (value == null || value < Decimal.zero || value >= Decimal.one) {
      throw const FormatException();
    }
    return value;
  }

  return BuilderCommissionRates(
    maker: rate('makerCommissionRate'),
    taker: rate('takerCommissionRate'),
  );
}

class BuilderOrderQuote {
  BuilderOrderQuote(this.feeRate, this.maxFeeRate, {this.lifetime = const Duration(seconds: 9)})
    : _clock = Stopwatch()..start();
  final Decimal feeRate, maxFeeRate;
  final Stopwatch _clock;
  final Duration lifetime;
  Map<String, String> get parameters => {
    'builder': VantaBuilder.address,
    'feeRate': feeRate.toString(),
  };
  void checkFresh() {
    if (_clock.elapsed >= lifetime) {
      throw const AccountReadFailure('builderFeeQuoteExpired');
    }
  }
}

/// Read both live authorization and account/symbol commission rates before
/// signing placement. All reads inherit the caller's cancellation scope.
class BuilderOrderPreflight {
  BuilderOrderPreflight(this.builder);
  final AsterBuilderAuthorizationRepository builder;

  Future<BuilderOrderQuote> read({
    required AsterAccountService service,
    required AccountRequestSigner sign,
    required AsterReadNonces nonces,
    required AccountRequestAuthorization? authorization,
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
  }) => RequestScope.run(() => isCurrent() && canSubmit(), () async {
    void check() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    }

    check();
    final grant = await builder.check(
      address: intent.context.address,
      isCurrent: () => isCurrent() && canSubmit(),
    );
    check();
    if (!grant.sufficient) throw const AccountReadFailure('builderAuthorizationRequired');
    final payload =
        await SignedAccountRequest(
          serverTime: service.serverTime,
          send: service.commissionRate,
          sign: sign,
          authorization: authorization,
          nonces: nonces,
        ).read(
          address: intent.context.address,
          parameters: {'symbol': intent.context.symbol},
          isCurrent: () => isCurrent() && canSubmit(),
          onStep: (_) {},
        );
    check();
    try {
      final rates = mapBuilderCommissionRates(payload, intent.context.symbol);
      final fee = rates.feeFor(intent.draft);
      if (fee > grant.maxFeeRate!) throw const AccountReadFailure('builderAuthorizationRequired');
      return BuilderOrderQuote(fee, grant.maxFeeRate!);
    } on FormatException {
      throw const AccountReadFailure(
        'accountDataInvalid',
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: '/fapi/v3/commissionRate',
        ),
      );
    }
  });
}
