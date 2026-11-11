import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_signing_preparation.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/subaccount_management_repository.dart';
import '../domain/subaccount_management.dart';

final subaccountManagementClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final subaccountManagementRepositoryProvider = Provider<SubaccountManagementRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  final identity = ref.watch(identityRepositoryProvider);
  return AsterSubaccountManagementRepository(
    service,
    identity.signWalletRequest,
    ref.watch(walletOperationJournalProvider),
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
    signingPreparation: identity is WalletSigningPreparation
        ? identity as WalletSigningPreparation
        : null,
    now: ref.watch(subaccountManagementClockProvider),
  );
});
final subaccountManagementProvider =
    NotifierProvider<SubaccountManagementController, SubaccountManagementState>(
      SubaccountManagementController.new,
    );

// The status authorization page owns its request lifetime independently of the
// legacy management route. Disposal cancels applicable preflights/writes.
final accountStatusUpdateProvider =
    NotifierProvider.autoDispose<SubaccountManagementController, SubaccountManagementState>(
      SubaccountManagementController.new,
    );

class SubaccountManagementController extends Notifier<SubaccountManagementState> {
  int _generation = 0;
  bool _working = false;
  @override
  SubaccountManagementState build() {
    ref.watch(subaccountManagementRepositoryProvider);
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
          state = const SubaccountManagementState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const SubaccountManagementState();
  }

  bool _current(AuthIdentity i, int g) {
    if (!ref.mounted || _generation != g) return false;
    final auth = ref.read(authProvider), identity = auth.identity;
    return !auth.busy &&
        identity?.id == i.id &&
        identity?.walletAddress == i.walletAddress &&
        identity?.walletKind == i.walletKind &&
        identity?.signingAvailable == i.signingAvailable;
  }

  String _failure(Object e) => e is AccountReadFailure ? e.key : 'accountReadFailed';
  void stop() {
    _generation++;
    state = const SubaccountManagementState();
  }

  void cancel() {
    if (ref.mounted && !_working) state = const SubaccountManagementState();
  }

  Future<void> prepare(WalletOperationKind kind, Map<String, String> terms) async {
    final auth = ref.read(authProvider), i = auth.identity;
    if (_working || auth.busy || i?.walletAddress == null) return;
    if (kind == WalletOperationKind.createSubaccount && !canCreateSubaccount(i)) {
      state = const SubaccountManagementState(failure: 'subaccountCreateExternalOnly');
      return;
    }
    if (!i!.signingAvailable) {
      state = const SubaccountManagementState(failure: 'authWalletReconnect');
      return;
    }
    final g = ++_generation;
    _working = true;
    state = const SubaccountManagementState(busy: true);
    try {
      final review = await ref
          .read(subaccountManagementRepositoryProvider)
          .prepare(identity: i, kind: kind, terms: terms, isCurrent: () => _current(i, g));
      if (_current(i, g)) state = SubaccountManagementState(review: review);
    } catch (e) {
      if (_current(i, g)) {
        state = SubaccountManagementState(errorDetails: errorDetailsOf(e), failure: _failure(e));
      }
    } finally {
      _working = false;
    }
  }

  Future<void> confirm(SubaccountManagementReview review, {String childSignature = ''}) async {
    if (_working || !identical(state.review, review)) return;
    final g = _generation;
    if (!_current(review.identity, g)) return;
    if (review.record.kind == WalletOperationKind.createSubaccount &&
        !canCreateSubaccount(ref.read(authProvider).identity)) {
      state = const SubaccountManagementState(failure: 'subaccountCreateExternalOnly');
      return;
    }
    _working = true;
    state = SubaccountManagementState(busy: true, review: review);
    try {
      final result = await ref
          .read(subaccountManagementRepositoryProvider)
          .submit(
            review,
            childSignature: childSignature,
            isCurrent: () => _current(review.identity, g),
          );
      if (_current(review.identity, g)) state = SubaccountManagementState(result: result);
    } catch (e) {
      if (_current(review.identity, g)) {
        state = SubaccountManagementState(
          review: review,
          errorDetails: errorDetailsOf(e),
          failure: _failure(e),
        );
      }
    } finally {
      _working = false;
    }
  }
}
