import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/funding_catalog_repository.dart';
import '../data/funding_fee_repository.dart';
import '../data/withdraw_info_mapper.dart';
import '../data/withdrawal_repository.dart';
import '../domain/deposit_wallet.dart';
import '../domain/withdrawal.dart';

final withdrawalClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final withdrawalRepositoryProvider = Provider<WithdrawalRepository>((ref) {
  final futures = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease()),
      spot = AsterSpotService(client: ref.watch(backendHttpPoolProvider).lease()),
      catalog = FundingCatalogService(client: ref.watch(backendHttpPoolProvider).lease()),
      fees = FundingFeeService(client: ref.watch(backendHttpPoolProvider).lease()),
      info = AsterAccountService(
        client: ref.watch(backendHttpPoolProvider).lease(),
        decodeResponse: decodeWithdrawInfoJson,
      );
  ref.onDispose(() {
    futures.close();
    info.close();
    spot.close();
    catalog.close();
    fees.close();
  });
  return AsterWithdrawalRepository(
    futures,
    spot,
    AsterFundingCatalogRepository(catalog),
    AsterFundingFeeRepository(fees),
    ref.watch(identityRepositoryProvider).signWalletRequest,
    ref.watch(walletOperationJournalProvider),
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(withdrawalClockProvider),
    infoService: info,
  );
});
final withdrawalProvider = NotifierProvider<WithdrawalController, WithdrawalState>(
  WithdrawalController.new,
);

class WithdrawalController extends Notifier<WithdrawalState> {
  int _generation = 0;
  bool _working = false;
  @override
  WithdrawalState build() {
    ref.watch(withdrawalRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
          s.busy,
        ),
      ),
      (a, b) {
        if (a != b) {
          _generation++;
          state = const WithdrawalState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const WithdrawalState();
  }

  bool _current(AuthIdentity i, int g) =>
      ref.mounted &&
      g == _generation &&
      ref.read(authProvider).identity?.id == i.id &&
      ref.read(authProvider).identity?.walletAddress == i.walletAddress;
  void stop() {
    _generation++;
    state = const WithdrawalState();
  }

  void cancel() {
    if (ref.mounted && !_working) state = const WithdrawalState();
  }

  Future<void> prepare(DepositWalletQuery query, String amount) async {
    final auth = ref.read(authProvider), i = auth.identity;
    if (_working || auth.busy || i?.walletAddress == null) return;
    final g = ++_generation;
    _working = true;
    state = const WithdrawalState(busy: true);
    try {
      final r = await ref
          .read(withdrawalRepositoryProvider)
          .prepare(identity: i!, query: query, amount: amount, isCurrent: () => _current(i, g));
      if (_current(i, g)) state = WithdrawalState(review: r);
    } catch (e) {
      if (_current(i!, g)) {
        state = WithdrawalState(
          errorDetails: errorDetailsOf(e),
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      _working = false;
    }
  }

  /// Prepares and signs in one wallet step only when the fresh platform fee
  /// equals the fee the user saw; a changed fee stops before any signature.
  Future<void> submit(DepositWalletQuery query, String amount, {required Decimal shownFee}) async {
    await prepare(query, amount);
    final review = state.review;
    if (!ref.mounted || review == null) return;
    if (review.fee.assetFee != shownFee) {
      state = const WithdrawalState(failure: 'withdrawalFeeChanged');
      return;
    }
    await confirm(review);
  }

  Future<void> confirm(WithdrawalReview review) async {
    if (_working || !identical(state.review, review)) return;
    final g = _generation;
    if (!_current(review.identity, g)) return;
    _working = true;
    state = WithdrawalState(busy: true, review: review);
    try {
      final r = await ref
          .read(withdrawalRepositoryProvider)
          .submit(review, isCurrent: () => _current(review.identity, g));
      if (_current(review.identity, g)) state = WithdrawalState(result: r);
    } catch (e) {
      if (_current(review.identity, g)) {
        state = WithdrawalState(
          errorDetails: errorDetailsOf(e),
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      _working = false;
    }
  }
}
