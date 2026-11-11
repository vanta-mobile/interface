import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_details.dart';
import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/subaccount_wallet_store.dart';
import '../domain/generated_subaccount.dart';
import '../domain/subaccount_management.dart';
import 'subaccount_management_provider.dart';

final subaccountWalletStoreProvider = Provider<SubaccountWalletStore>(
  (_) => DeviceSubaccountWalletStore(),
);

/// Directory polling cadence while a dispatched creation is undecided.
final subaccountCreationPollProvider = Provider<Duration>((_) => const Duration(seconds: 4));

final generatedWalletsProvider = FutureProvider<List<GeneratedSubaccount>>(
  (ref) => ref.watch(subaccountWalletStoreProvider).list(),
);

class GeneratedAccountState {
  const GeneratedAccountState({
    this.busy = false,
    this.wallet,
    this.accepted = false,
    this.failure,
    this.details,
  });
  final bool busy, accepted;
  final GeneratedSubaccount? wallet;
  final String? failure;
  final ApiErrorDetails? details;
}

final generatedAccountProvider =
    NotifierProvider.autoDispose<GeneratedAccountController, GeneratedAccountState>(
      GeneratedAccountController.new,
    );

class GeneratedAccountController extends Notifier<GeneratedAccountState> {
  int _revision = 0;
  bool _working = false;
  @override
  GeneratedAccountState build() {
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
          _revision++;
          state = const GeneratedAccountState();
        }
      },
    );
    ref.onDispose(() => _revision++);
    return const GeneratedAccountState();
  }

  Future<void> create(String name) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity == null) return;
    if (!canCreateSubaccount(identity)) {
      state = const GeneratedAccountState(failure: 'subaccountCreateExternalOnly');
      return;
    }
    if (identity.walletAddress == null || !identity.signingAvailable) {
      state = const GeneratedAccountState(failure: 'authWalletReconnect');
      return;
    }
    if (name.trim().isEmpty ||
        name.trim().length > 64 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      state = const GeneratedAccountState(failure: 'subaccountInputInvalid');
      return;
    }
    final revision = ++_revision;
    bool current() => ref.mounted && revision == _revision;
    _working = true;
    state = const GeneratedAccountState(busy: true);
    GeneratedSubaccount? wallet;
    final store = ref.read(subaccountWalletStoreProvider);
    // Only an accepted or dispatched create can have registered the child.
    // Any other exit leaves the generated key unused; it is never offered for backup.
    var keep = false;
    try {
      final operations = ref.read(walletOperationStorageProvider);
      if (!operations.ready || operations.failed) {
        throw const AccountReadFailure('walletOperationStorage');
      }
      if (operations.records.any(
        (r) => !r.acknowledged && r.address.toLowerCase() == identity.walletAddress!.toLowerCase(),
      )) {
        throw const AccountReadFailure('walletOperationPending');
      }
      // Persist before obtaining signatures or dispatching a financial write.
      wallet = await store.generate(owner: identity.walletAddress!, name: name.trim());
      ref.invalidate(generatedWalletsProvider);
      if (!current()) return;
      state = GeneratedAccountState(busy: true, wallet: wallet);
      final repo = ref.read(subaccountManagementRepositoryProvider);
      final review = await repo.prepare(
        identity: identity,
        kind: WalletOperationKind.createSubaccount,
        terms: {'child': wallet.address, 'name': wallet.name},
        isCurrent: current,
      );
      if (!current()) return;
      final signature = await store.sign(wallet.address, review.childTypedData);
      if (!current()) return;
      try {
        await repo.submit(review, childSignature: signature, isCurrent: current);
      } on AccountReadFailure catch (e) {
        if (e.key != 'walletOperationUnknown') rethrow;
        // Dispatched without a decided outcome: the key may already own an
        // account, so it is kept while the server state is checked.
        keep = true;
        await _settle(repo, review, current);
      }
      keep = true;
      if (current()) state = GeneratedAccountState(wallet: wallet, accepted: true);
    } catch (e) {
      // Only an outcome that stays unknown keeps the key; it is offered for
      // backup once a later directory read confirms the child. The review page
      // never hands over to backup without a confirmed creation.
      keep = e is AccountReadFailure && e.key == 'walletOperationUnknown';
      if (current()) {
        state = GeneratedAccountState(
          failure: e is AccountReadFailure ? e.key : 'subaccountCreationFailed',
          details: errorDetailsOf(e),
        );
      }
    } finally {
      _working = false;
      if (wallet != null && !keep) {
        try {
          await store.discard(wallet.address);
        } catch (_) {
          // A leftover unbacked key stays listed; it never replaces the reported failure.
        }
        if (ref.mounted) ref.invalidate(generatedWalletsProvider);
      }
    }
  }

  /// Keeps the review busy and polls the signed directory until the dispatched
  /// creation is confirmed, proven absent, or the settle window is exhausted.
  Future<void> _settle(
    SubaccountManagementRepository repo,
    SubaccountManagementReview review,
    bool Function() current,
  ) async {
    final interval = ref.read(subaccountCreationPollProvider);
    while (true) {
      if (!current()) throw const AccountReadFailure('walletOperationUnknown');
      final settled = await repo.settleCreation(review, isCurrent: current);
      if (settled == true) return;
      if (settled == false) throw const AccountReadFailure('subaccountCreationNotCompleted');
      await Future<void>.delayed(interval);
    }
  }

  Future<void> saved(GeneratedSubaccount wallet) async {
    final revision = _revision;
    await ref.read(subaccountWalletStoreProvider).acknowledgeBackup(wallet.address);
    if (!ref.mounted) return;
    ref.invalidate(generatedWalletsProvider);
    if (revision == _revision) state = const GeneratedAccountState();
  }

  void reset() {
    if (!_working) {
      _revision++;
      state = const GeneratedAccountState();
    }
  }
}
