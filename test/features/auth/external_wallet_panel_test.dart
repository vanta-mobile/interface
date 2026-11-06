import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/identity_panel.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/wallet_connection.dart';

void main() {
  testWidgets('EOA connect, signature, expiry and demo funds remain separate', (tester) async {
    final repository = TestIdentityRepository()..externalGate = Completer<void>();
    final connection = TestWalletConnection();
    final connector = TestWalletConnector(connection)..gate = Completer<void>();
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(tester, identityRepository: repository, walletConnector: connector);
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('connect-external-wallet'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(container.read(authProvider).walletStep, WalletLoginStep.connecting);
    expect(tester.widget<AuthActionButton>(button).busy, true);
    expect(
      tester
          .widget<FilledButton>(find.descendant(of: button, matching: find.byType(FilledButton)))
          .onPressed,
      null,
    );
    connector.gate!.complete();
    await tester.pump();
    expect(container.read(authProvider).walletStep, WalletLoginStep.signing);
    repository.externalGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(IdentityPanel), matching: find.text(connection.address)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create-wallet')), findsNothing);
    expect(repository.wallets, 0);
    expect(connector.connects, 1);
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(container.read(accountProvider).connected, false);
    repository.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity, null);
    expect(find.byKey(const Key('connect-external-wallet')), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancel retains the email and allows another EOA attempt', (tester) async {
    final repository = TestIdentityRepository();
    final connection = TestWalletConnection();
    final connector = TestWalletConnector(connection)
      ..failure = const AuthFailure('authWalletCancelled');
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(tester, identityRepository: repository, walletConnector: connector);
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), 'test@example.com');
    final button = find.byKey(const Key('connect-external-wallet'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).failure?.key, 'authWalletCancelled');
    expect(
      tester.widget<TextField>(find.byKey(const Key('login-email'))).controller!.text,
      'test@example.com',
    );
    expect(repository.wallets, 0);
    connector.failure = null;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.walletKind, WalletKind.external);
    expect(repository.wallets, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restored EOA requires reconnect and never shows wallet creation', (tester) async {
    final connection = TestWalletConnection();
    final repository = TestIdentityRepository()
      ..restored = AuthIdentity(
        id: 'external-user',
        walletAddress: connection.address,
        walletKind: WalletKind.external,
      );
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(
      tester,
      identityRepository: repository,
      walletConnector: TestWalletConnector(connection),
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-wallet')), findsNothing);
    final reconnect = find.byKey(const Key('reconnect-external-wallet'));
    await tester.ensureVisible(reconnect);
    await tester.tap(reconnect);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(repository.wallets, 0);
    expect(find.byKey(const Key('reconnect-external-wallet')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
