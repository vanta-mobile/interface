import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/portfolio/domain/aster_signature.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/identity_repository.dart';
import '../../support/account_switch_authorization.dart';
import '../../support/wallet_connection.dart';
import '../../support/aster_account.dart';

void main() {
  test(
    'generated child switches and signs through the real repository without Privy login',
    () async {
      final preferences = MemoryWalletPreferences();
      final repository = PrivyIdentityRepository(
        const PrivyConfiguration(appId: '', clientId: ''),
        preferences: preferences,
        create: (_) => throw TestFailure('Local EOA switch must not initialize Privy'),
      );
      final storage = <String, String>{};
      final store = DeviceSubaccountWalletStore(
        read: (key) async => storage[key],
        write: (key, value) async {
          storage[key] = value;
        },
      );
      final main = await store.generate(owner: accountAddress, name: 'Main');
      await store.acknowledgeBackup(main.address);
      final original = store.connection(main);
      await repository.loginWithWallet(original);
      final wallet = await store.generate(owner: original.address, name: 'Desk');
      await store.acknowledgeBackup(wallet.address);
      final connection = store.connection(wallet);
      final container = ProviderContainer(
        overrides: [identityRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
        await original.release();
      });
      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(authProvider.notifier).switchWithConnection(connection);
      final identity = container.read(authProvider).identity!;
      expect(identity.walletAddress, wallet.address);
      expect(identity.id, 'eip155:${wallet.address.toLowerCase()}');
      expect(identity.signingAvailable, true);
      final data = asterReadTypedData('user=${wallet.address}&nonce=1');
      final signature = await repository.signWalletRequest(
        expectedAddress: wallet.address,
        typedData: data,
      );
      expect(verifyAsterWalletSignature(wallet.address, data, signature), true);
      final restored = PrivyIdentityRepository(
        const PrivyConfiguration(appId: '', clientId: ''),
        preferences: preferences,
      );
      addTearDown(restored.dispose);
      expect((await restored.initialize())?.id, identity.id);
      expect((await restored.initialize())?.signingAvailable, false);
    },
  );

  for (final variant in ['success', 'wrong-address', 'cancelled']) {
    testWidgets(
      'explicit account switch $variant verifies selected new identity and never creates wallet',
      (t) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final child = TestWalletConnection(address: '0x3333333333333333333333333333333333333333');
        final connector = TestWalletConnector(child);
        if (variant == 'cancelled') {
          identity.externalFailure = const AuthFailure('authWalletCancelled');
        }
        final c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountSwitchAuthorizationProvider.overrideWithValue(TestAccountSwitchAuthorization()),
            walletSwitchConnectorFactoryProvider.overrideWithValue(() => connector),
          ],
        );
        addTearDown(c.dispose);
        addTearDown(child.dispose);
        addTearDown(identity.dispose);
        c.read(authProvider);
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => c
                    .read(authProvider.notifier)
                    .switchToWallet(
                      context,
                      variant == 'wrong-address'
                          ? '0x4444444444444444444444444444444444444444'
                          : child.address,
                    ),
                child: const Text('switch'),
              ),
            ),
          ),
        );
        await t.pump();
        expect(c.read(authProvider).identity?.walletAddress, accountAddress);
        await t.tap(find.text('switch'));
        await t.pumpAndSettle();
        if (variant == 'success') {
          expect(c.read(authProvider).identity?.walletAddress, child.address);
          expect(identity.externalLogins, 1);
        } else {
          expect(c.read(authProvider).identity?.walletAddress, accountAddress);
        }
        expect(identity.wallets, 0);
        expect(identity.logouts, 0);
      },
    );
  }
  for (final rejected in [false, true]) {
    test(
      'generated local connection switches only after target connection rejected=$rejected',
      () async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final storage = <String, String>{};
        final store = DeviceSubaccountWalletStore(
          read: (k) async => storage[k],
          write: (k, v) async {
            storage[k] = v;
          },
        );
        final wallet = await store.generate(owner: accountAddress, name: 'Desk');
        await store.acknowledgeBackup(wallet.address);
        final connection = store.connection(wallet);
        final gate = Completer<void>();
        identity.externalGate = gate;
        if (rejected) identity.externalFailure = const AuthFailure('authWalletCancelled');
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountSwitchAuthorizationProvider.overrideWithValue(TestAccountSwitchAuthorization()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(identity.dispose);
        container.read(authProvider);
        await Future<void>.delayed(Duration.zero);
        final pending = container.read(authProvider.notifier).switchWithConnection(connection);
        expect(container.read(authProvider).identity?.walletAddress, accountAddress);
        final duplicate = store.connection(wallet);
        await container.read(authProvider.notifier).switchWithConnection(duplicate);
        expect(duplicate.isCurrent, false);
        await Future<void>.delayed(Duration.zero);
        expect(identity.externalLogins, 1);
        gate.complete();
        await pending;
        expect(
          container.read(authProvider).identity?.walletAddress,
          rejected ? accountAddress : wallet.address,
        );
        expect(connection.isCurrent, !rejected);
        expect(identity.logouts, 0);
        expect(identity.wallets, 0);
        if (!rejected) {
          await container.read(authProvider.notifier).logout();
          expect(container.read(authProvider).identity, null);
          expect((await store.list()).single.backedUp, true);
        }
        await connection.release();
      },
    );
  }
}
