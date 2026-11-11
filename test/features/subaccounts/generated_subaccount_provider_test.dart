import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/application/generated_subaccount_provider.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_management.dart';

import '../../support/account_operations.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';

class _CreationRepository extends TestSubaccountManagementRepository {
  bool childVerified = false;
  Object? submitFailure;
  @override
  Future<WalletOperationRecord> submit(
    SubaccountManagementReview review, {
    String childSignature = '',
    required bool Function() isCurrent,
  }) async {
    childVerified = verifyAsterWalletSignature(
      review.record.terms['child']!,
      review.childTypedData,
      childSignature,
    );
    final result = await super.submit(review, childSignature: childSignature, isCurrent: isCurrent);
    if (submitFailure != null) throw submitFailure!;
    return result;
  }
}

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late _CreationRepository repo;
  late DeviceSubaccountWalletStore store;
  late Map<String, String> storage;
  Future<void> launch({WalletKind kind = WalletKind.external}) async {
    storage = {};
    store = DeviceSubaccountWalletStore(
      read: (k) async => storage[k],
      write: (k, v) async {
        storage[k] = v;
      },
    );
    identity = TestIdentityRepository()
      ..restored = AuthIdentity(
        id: 'owner',
        walletAddress: accountAddress,
        walletKind: kind,
        signingAvailable: true,
      );
    repo = _CreationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        subaccountWalletStoreProvider.overrideWithValue(store),
        subaccountManagementRepositoryProvider.overrideWithValue(repo),
        subaccountCreationPollProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(identity.dispose);
    container.listen(generatedAccountProvider, (_, _) {});
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'automatic creation proves child ownership without manual address or signature input',
    () async {
      await launch();
      await container.read(generatedAccountProvider.notifier).create(' Momentum ');
      final state = container.read(generatedAccountProvider);
      expect(state.accepted, true);
      expect(state.wallet!.name, 'Momentum');
      expect(repo.childVerified, true);
      expect(repo.sends, 1);
      expect(identity.wallets, 0);
      expect((await store.list()).single.backedUp, false);
      await container.read(generatedAccountProvider.notifier).saved(state.wallet!);
      expect((await store.list()).single.backedUp, true);
    },
  );
  test('Privy cannot generate a wallet or call the creation API', () async {
    await launch(kind: WalletKind.embedded);
    await container.read(generatedAccountProvider.notifier).create('Desk');
    expect(storage, isEmpty);
    expect(repo.prepares, 0);
    expect(container.read(generatedAccountProvider).failure, 'subaccountCreateExternalOnly');
  });
  test('undecided outcome stays busy until the directory confirms the child', () async {
    await launch();
    repo.submitFailure = const AccountReadFailure('walletOperationUnknown');
    repo.settlements.addAll([null, null, true]);
    final task = container.read(generatedAccountProvider.notifier).create('Desk');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(generatedAccountProvider).busy, true);
    expect(container.read(generatedAccountProvider).accepted, false);
    await task;
    final state = container.read(generatedAccountProvider);
    expect(state.accepted, true);
    expect(state.wallet, isNotNull);
    expect(repo.settles, 3);
    expect(repo.sends, 1);
    expect((await store.list()).single.backedUp, false);
  });
  test('provably absent creation reports failure and discards the unused key', () async {
    await launch();
    repo.submitFailure = const AccountReadFailure('walletOperationUnknown');
    repo.settlements.addAll([null, false]);
    await container.read(generatedAccountProvider.notifier).create('Desk');
    final state = container.read(generatedAccountProvider);
    expect(state.wallet, null);
    expect(state.accepted, false);
    expect(state.failure, 'subaccountCreationNotCompleted');
    expect(await store.list(), isEmpty);
    expect(repo.sends, 1);
  });
  test('outcome still unknown after the window keeps the key without opening backup', () async {
    await launch();
    repo.submitFailure = const AccountReadFailure('walletOperationUnknown');
    await container.read(generatedAccountProvider.notifier).create('Desk');
    final state = container.read(generatedAccountProvider);
    expect(state.wallet, null);
    expect(state.failure, 'walletOperationUnknown');
    expect((await store.list()).length, 1);
    expect(repo.prepares, 1);
    expect(repo.sends, 1);
  });
  test('duplicate tap and account change cannot dispatch a late child creation', () async {
    await launch();
    repo.gate = Completer<void>();
    final controller = container.read(generatedAccountProvider.notifier);
    final task = controller.create('Desk');
    await Future<void>.delayed(Duration.zero);
    await controller.create('Other');
    expect((await store.list()).length, 1);
    identity.events.add(null);
    repo.gate!.complete();
    await task;
    expect(repo.latestCurrent!(), false);
    expect(repo.sends, 0);
    expect(container.read(generatedAccountProvider).wallet, null);
    expect(await store.list(), isEmpty);
  });
  test('wallet failure before dispatch keeps the review and discards the unused key', () async {
    await launch();
    repo.failure = const AccountReadFailure(
      'authWalletUnavailable',
      details: ApiErrorDetails(message: 'Provided chainId must match the active chainId'),
    );
    await container.read(generatedAccountProvider.notifier).create('Desk');
    final state = container.read(generatedAccountProvider);
    expect(state.wallet, null);
    expect(state.accepted, false);
    expect(state.failure, 'authWalletUnavailable');
    expect(state.details?.message, 'Provided chainId must match the active chainId');
    expect(repo.sends, 0);
    expect(await store.list(), isEmpty);
  });
  test('invalid names do not generate keys or request signatures', () async {
    await launch();
    await container.read(generatedAccountProvider.notifier).create('');
    expect(storage, isEmpty);
    expect(repo.prepares, 0);
  });
}
