import 'package:decimal/decimal.dart';

import '../../../core/network/request_scope.dart';
import '../../authorization/data/builder_authorization_repository.dart';
import '../../authorization/domain/builder_authorization.dart';
import '../domain/account_snapshot.dart';
import '../domain/builder_order_fee.dart';
import '../domain/live_order.dart';

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

/// Checks live builder authorization before signing placement.
/// All reads inherit the caller's cancellation scope.
class BuilderOrderPreflight {
  BuilderOrderPreflight(this.builder);
  final AsterBuilderAuthorizationRepository builder;

  Future<BuilderOrderQuote> read({
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
    final fee = const BuilderCommissionRates().feeFor(intent.draft);
    if (fee > grant.maxFeeRate!) throw const AccountReadFailure('builderAuthorizationRequired');
    return BuilderOrderQuote(fee, grant.maxFeeRate!);
  });
}
