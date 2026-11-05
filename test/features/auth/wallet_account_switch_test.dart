import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/identity_repository.dart';
import '../../support/wallet_connection.dart';
import '../../support/aster_account.dart';

void main() {
  for (final variant in ['success', 'wrong-address', 'cancelled', 'logout-failed']) {
    testWidgets(
      'explicit account switch $variant verifies selected new identity and never creates wallet',
      (t) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final child = TestWalletConnection(address: '0x3333333333333333333333333333333333333333');
        final connector = TestWalletConnector(child);
        if (variant == 'logout-failed') {
          identity.logoutFailure = const AuthFailure('authUnavailable');
        }
        if (variant == 'cancelled') {
          identity.externalFailure = const AuthFailure('authWalletCancelled');
        }
        final c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            walletConnectorProvider.overrideWithValue(connector),
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
        } else if (variant == 'logout-failed') {
          expect(c.read(authProvider).identity?.walletAddress, accountAddress);
          expect(identity.externalLogins, 0);
        } else {
          expect(c.read(authProvider).identity, null);
        }
        expect(identity.wallets, 0);
        expect(identity.logouts, 1);
      },
    );
  }
}
