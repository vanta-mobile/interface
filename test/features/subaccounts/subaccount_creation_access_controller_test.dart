import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_management.dart';

import '../../support/account_operations.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';

const _child = '0x3333333333333333333333333333333333333333';
const _creation = {'child': _child, 'name': 'Desk A'};

AuthIdentity _identity(WalletKind kind, {bool signable = true}) => AuthIdentity(
  id: signingIdentity.id,
  email: 'linked@example.com',
  walletAddress: accountAddress,
  walletKind: kind,
  signingAvailable: signable,
);

void main() {
  late ProviderContainer container;
  late TestIdentityRepository auth;
  late TestSubaccountManagementRepository repo;
  late SubaccountManagementController controller;
  Future<void> start(WidgetTester t, AuthIdentity identity, {bool unexpectedCreate = false}) async {
    auth = TestIdentityRepository()..restored = identity;
    repo = unexpectedCreate ? _UnexpectedCreateRepository() : TestSubaccountManagementRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(auth),
        subaccountManagementRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    container.read(authProvider);
    await t.pump();
    controller = container.read(subaccountManagementProvider.notifier);
  }

  for (final signable in [false, true]) {
    testWidgets('Privy signable=$signable cannot dispatch creation preparation', (t) async {
      await start(t, _identity(WalletKind.embedded, signable: signable));
      await controller.prepare(WalletOperationKind.createSubaccount, _creation);
      final state = container.read(subaccountManagementProvider);
      expect(state.failure, 'subaccountCreateExternalOnly');
      expect(state.review, null);
      expect(repo.prepares, 0);
      expect(repo.sends, 0);
      expect(auth.wallets, 0);
    });
  }

  for (final kind in [
    WalletOperationKind.freezeSubaccount,
    WalletOperationKind.unfreezeSubaccount,
    WalletOperationKind.subaccountTransfer,
  ]) {
    testWidgets('Privy can still explicitly prepare and confirm $kind', (t) async {
      await start(t, _identity(WalletKind.embedded));
      final terms = kind == WalletOperationKind.subaccountTransfer
          ? {
              'from': accountAddress,
              'to': _child,
              'asset': 'USDT',
              'amount': '1',
              'direction': 'FUTURE_SPOT',
            }
          : {'child': _child};
      await controller.prepare(kind, terms);
      final review = container.read(subaccountManagementProvider).review!;
      expect(review.identity.walletKind, WalletKind.embedded);
      expect(review.record.kind, kind);
      expect(repo.prepares, 1);
      expect(repo.sends, 0);
      await controller.confirm(review);
      expect(repo.sends, 1);
      expect(container.read(subaccountManagementProvider).result!.acknowledged, true);
      expect(auth.wallets, 0);
    });
  }

  testWidgets('EOA with email can create while a disconnected EOA requires reconnect', (t) async {
    await start(t, _identity(WalletKind.external));
    await controller.prepare(WalletOperationKind.createSubaccount, _creation);
    final review = container.read(subaccountManagementProvider).review!;
    await controller.confirm(review, childSignature: 'fixture');
    expect(repo.sends, 1);
    auth.events.add(_identity(WalletKind.external, signable: false));
    await t.pump();
    await controller.prepare(WalletOperationKind.createSubaccount, _creation);
    expect(container.read(subaccountManagementProvider).failure, 'authWalletReconnect');
    expect(repo.prepares, 1);
    expect(auth.wallets, 0);
  });

  testWidgets('confirm independently rejects an unexpected embedded creation review', (t) async {
    await start(t, _identity(WalletKind.embedded), unexpectedCreate: true);
    await controller.prepare(WalletOperationKind.freezeSubaccount, {'child': _child});
    final review = container.read(subaccountManagementProvider).review!;
    expect(review.record.kind, WalletOperationKind.createSubaccount);
    await controller.confirm(review, childSignature: 'fixture');
    expect(container.read(subaccountManagementProvider).failure, 'subaccountCreateExternalOnly');
    expect(repo.sends, 0);
  });

  for (final change in ['kind', 'signing', 'logout', 'stop']) {
    for (final stage in ['prepare', 'confirm']) {
      testWidgets('$change during $stage invalidates callbacks and ignores late result', (t) async {
        await start(t, _identity(WalletKind.external));
        SubaccountManagementReview? review;
        if (stage == 'confirm') {
          await controller.prepare(WalletOperationKind.createSubaccount, _creation);
          review = container.read(subaccountManagementProvider).review!;
        }
        final gate = Completer<void>();
        repo.gate = gate;
        final pending = stage == 'prepare'
            ? controller.prepare(WalletOperationKind.createSubaccount, _creation)
            : controller.confirm(review!, childSignature: 'fixture');
        await t.pump();
        final capturedCurrent = repo.latestCurrent!;
        expect(capturedCurrent(), true);
        switch (change) {
          case 'kind':
            auth.events.add(_identity(WalletKind.embedded));
          case 'signing':
            auth.events.add(_identity(WalletKind.external, signable: false));
          case 'logout':
            auth.events.add(null);
          case 'stop':
            controller.stop();
        }
        await t.pump();
        expect(capturedCurrent(), false);
        // Returning to the same id/address/kind cannot resurrect this generation.
        if (change == 'logout') {
          auth.restored = _identity(WalletKind.external);
          await container.read(authProvider.notifier).bootstrap();
        } else {
          auth.events.add(_identity(WalletKind.external));
        }
        await t.pump();
        expect(capturedCurrent(), false);
        gate.complete();
        await pending;
        final state = container.read(subaccountManagementProvider);
        expect(state.review, null);
        expect(state.result, null);
        expect(state.failure, null);
        if (review != null) await controller.confirm(review, childSignature: 'fixture');
        expect(repo.prepares, 1);
        expect(repo.sends, stage == 'confirm' ? 1 : 0);
        // A new explicit review is required after a return to EOA.
        repo.gate = null;
        await controller.prepare(WalletOperationKind.createSubaccount, _creation);
        expect(container.read(subaccountManagementProvider).review, isNotNull);
        expect(repo.prepares, 2);
      });
    }
  }

  testWidgets('same-address Privy switch discards an already prepared EOA review', (t) async {
    await start(t, _identity(WalletKind.external));
    await controller.prepare(WalletOperationKind.createSubaccount, _creation);
    final review = container.read(subaccountManagementProvider).review!;
    auth.events.add(_identity(WalletKind.embedded));
    await t.pump();
    await controller.confirm(review, childSignature: 'fixture');
    expect(repo.sends, 0);
    expect(container.read(subaccountManagementProvider).review, null);
    await controller.prepare(WalletOperationKind.createSubaccount, _creation);
    expect(container.read(subaccountManagementProvider).failure, 'subaccountCreateExternalOnly');
    expect(repo.prepares, 1);
  });
}

class _UnexpectedCreateRepository extends TestSubaccountManagementRepository {
  @override
  Future<SubaccountManagementReview> prepare({
    required AuthIdentity identity,
    required WalletOperationKind kind,
    required Map<String, String> terms,
    required bool Function() isCurrent,
  }) => super.prepare(
    identity: identity,
    kind: WalletOperationKind.createSubaccount,
    terms: _creation,
    isCurrent: isCurrent,
  );
}
