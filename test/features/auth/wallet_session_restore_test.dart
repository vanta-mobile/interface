import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/wallet_preference_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';
import 'package:vanta/features/auth/presentation/wallet_session_host.dart';

import '../../support/wallet_connection.dart';

void main() {
  test('explicit disconnect persists a signed-out marker across repository recreation', () async {
    final connection = TestWalletConnection();
    final preferences = MemoryWalletPreferences()
      ..value = WalletPreference('saved', WalletKind.external, connection.address);
    PrivyIdentityRepository create() => PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: preferences,
    );
    final repository = create();
    expect((await repository.initialize())?.needsWalletConnection, true);
    await repository.loginWithWallet(connection);
    await repository.logout();
    expect(connection.disconnected, 1);
    expect(preferences.value?.address, isNull);
    await repository.dispose();
    final restarted = create();
    expect(await restarted.initialize(), isNull);
    await restarted.dispose();
    await connection.dispose();
  });
  for (final outcome in ['restore', 'missing', 'timeout', 'late']) {
    testWidgets('startup wallet session $outcome and remote disconnect', (tester) async {
      final connection = TestWalletConnection();
      final preferences = MemoryWalletPreferences()
        ..value = WalletPreference('saved', WalletKind.external, connection.address);
      final repository = PrivyIdentityRepository(
        const PrivyConfiguration(appId: '', clientId: ''),
        preferences: preferences,
      );
      addTearDown(repository.dispose);
      addTearDown(connection.dispose);
      final connector = _Restorer(connection)
        ..missing = outcome == 'missing'
        ..failure = outcome == 'timeout' ? const AuthFailure('authWalletConnectionTimeout') : null
        ..gate = outcome == 'late' ? Completer<void>() : null;
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repository),
          walletConnectorProvider.overrideWithValue(connector),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WalletSessionHost(child: SizedBox())),
        ),
      );
      await tester.pumpAndSettle();
      expect(connector.restores, 1);
      expect(connector.connects, 0);
      final controller = container.read(authProvider.notifier);
      if (outcome == 'restore') {
        expect(container.read(authProvider).needsWalletConnection, false);
        expect(connection.personalSigns + connection.typedSigns, 0);
        connection.invalidate();
        await tester.pumpAndSettle();
        expect(container.read(authProvider).identity, isNull);
        expect(preferences.value?.address, isNull);
        expect(await repository.initialize(), isNull);
        final restarted = PrivyIdentityRepository(
          const PrivyConfiguration(appId: '', clientId: ''),
          preferences: preferences,
        );
        addTearDown(restarted.dispose);
        expect(await restarted.initialize(), isNull);
      } else if (outcome == 'missing') {
        expect(container.read(authProvider).identity, isNull);
        expect(preferences.value?.address, isNull);
      } else if (outcome == 'timeout') {
        expect(container.read(authProvider).identity?.walletAddress, connection.address);
        expect(container.read(authProvider).busy, false);
        connector.failure = null;
        final context = tester.element(find.byType(SizedBox).first);
        final restore = controller.restoreWalletSession(context);
        await tester.pumpAndSettle();
        await restore;
        expect(container.read(authProvider).needsWalletConnection, false);
      } else {
        // Disposal supersedes an in-flight startup restore.
        container.dispose();
        connector.gate!.complete();
        await tester.pumpAndSettle();
        expect(connection.isCurrent, false);
        await tester.pumpWidget(const SizedBox());
        return;
      }
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}

class _Restorer extends TestWalletConnector implements WalletSessionRestorer {
  _Restorer(super.connection);
  int restores = 0;
  bool missing = false;
  @override
  Future<WalletConnection?> restore(BuildContext context, {required String expectedAddress}) async {
    restores++;
    expect(expectedAddress, connection.address);
    await gate?.future;
    if (failure case final error?) throw error;
    return missing ? null : connection;
  }
}
