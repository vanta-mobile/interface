import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/wallet_login_route.dart';
import '../../support/wallet_connection.dart';

void main() {
  testWidgets('EOA connects without a login signature and trading authorization stays explicit', (
    tester,
  ) async {
    final repository = TestIdentityRepository()..externalGate = Completer<void>();
    final connection = TestWalletConnection();
    final connector = TestWalletConnector(connection)..gate = Completer<void>();
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(tester, identityRepository: repository, walletConnector: connector);
    await launch(tester, container);
    await openWalletLogin(tester);
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
    expect(container.read(authProvider).walletStep, WalletLoginStep.connecting);
    repository.externalGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-wallet')), findsOneWidget);
    expect(find.byKey(const Key('create-wallet')), findsNothing);
    expect(repository.wallets, 0);
    expect(connection.personalSigns, 0);
    expect(connection.typedSigns, 0);
    expect(connector.connects, 1);
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(container.read(accountProvider).connected, false);
    repository.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity, null);
    expect(find.byKey(const Key('connect-external-wallet')), findsOneWidget);
    expect(tester.takeException(), null);
    await closeWalletLogin(tester, container);
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
    await openWalletLogin(tester);
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
    await closeWalletLogin(tester, container);
  });

  testWidgets('restored EOA requires reconnect and never shows wallet creation', (tester) async {
    final connection = TestWalletConnection();
    final connector = TestWalletConnector(connection)..gate = Completer<void>();
    final repository = TestIdentityRepository()
      ..externalGate = Completer<void>()
      ..restored = AuthIdentity(
        id: 'external-user',
        walletAddress: connection.address,
        walletKind: WalletKind.external,
      );
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(tester, identityRepository: repository, walletConnector: connector);
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-wallet')), findsNothing);
    expect(find.text('欢迎使用 Vanta'), findsOneWidget);
    expect(find.byKey(const Key('logout-identity')), findsNothing);
    expect(find.byKey(const Key('enter-demo')), findsNothing);
    final reconnect = find.byKey(const Key('connect-external-wallet'));
    await tester.ensureVisible(reconnect);
    await tester.tap(reconnect);
    await tester.pump();
    expect(tester.widget<AuthActionButton>(reconnect).busy, true);
    expect(
      find.descendant(of: reconnect, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(find.text('请在钱包中确认连接。'), findsOneWidget);
    await tester.tap(reconnect);
    expect(connector.connects, 1);
    connector.gate!.complete();
    await tester.pump();
    expect(find.text('请在钱包中确认连接。'), findsOneWidget);
    expect(find.text('请在钱包中签名以验证登录身份。'), findsNothing);
    repository.externalGate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(repository.wallets, 0);
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    await closeWalletLogin(tester, container);
  });

  testWidgets('failed reconnect preserves the restored identity and allows retry', (tester) async {
    final connection = TestWalletConnection();
    final repository = TestIdentityRepository()
      ..restored = AuthIdentity(
        id: 'external-user',
        walletAddress: connection.address,
        walletKind: WalletKind.external,
      );
    final connector = TestWalletConnector(connection)
      ..failure = const AuthFailure('authWalletConnectionTimeout');
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(tester, identityRepository: repository, walletConnector: connector);
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    final reconnect = find.byKey(const Key('connect-external-wallet'));
    await tester.ensureVisible(reconnect);
    await tester.tap(reconnect);
    await tester.pumpAndSettle();
    expect(find.text('钱包连接准备超时，请检查网络后重试。'), findsOneWidget);
    expect(container.read(authProvider).identity, same(repository.restored));
    expect(tester.widget<AuthActionButton>(reconnect).onPressed, isNotNull);
    expect(repository.externalLogins, 0);
    connector.failure = null;
    await tester.ensureVisible(reconnect);
    await tester.tap(reconnect);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(repository.wallets, 0);
    await closeWalletLogin(tester, container);
  });

  testWidgets('restored wallet connection still verifies the saved address', (tester) async {
    final connection = TestWalletConnection(address: '0x3333333333333333333333333333333333333333');
    final identity = const AuthIdentity(
      id: 'external-user',
      walletAddress: '0x2222222222222222222222222222222222222222',
      walletKind: WalletKind.external,
    );
    final repository = TestIdentityRepository()..restored = identity;
    addTearDown(repository.dispose);
    addTearDown(connection.dispose);
    final container = setup(
      tester,
      identityRepository: repository,
      walletConnector: TestWalletConnector(connection),
    );
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('connect-external-wallet')));
    await tester.tap(find.byKey(const Key('connect-external-wallet')));
    await tester.pumpAndSettle();
    expect(container.read(authProvider).failure?.key, 'authWalletChanged');
    expect(container.read(authProvider).identity, same(identity));
    expect(repository.externalLogins, 0);
    expect(connection.disconnected, 1);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    await closeWalletLogin(tester, container);
  });

  testWidgets('restored wallet opens full login and email clears the old identity', (tester) async {
    final repository = TestIdentityRepository()
      ..restored = const AuthIdentity(
        id: 'external-user',
        walletAddress: '0x2222222222222222222222222222222222222222',
        walletKind: WalletKind.external,
      );
    addTearDown(repository.dispose);
    final container = setup(tester, identityRepository: repository);
    await launch(tester, container);
    await openWalletLogin(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-use-another-wallet')), findsNothing);
    expect(repository.logouts, 0);
    expect(container.read(authProvider).identity, same(repository.restored));
    await tester.enterText(find.byKey(const Key('login-email')), 'test@example.com');
    await tester.ensureVisible(find.byKey(const Key('send-email-code')));
    await tester.tap(find.byKey(const Key('send-email-code')));
    await tester.pumpAndSettle();
    expect(repository.logouts, 1);
    expect(container.read(authProvider).identity, null);
    expect(find.byKey(const Key('login-code')), findsOneWidget);
    expect(repository.sent, 1);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    await closeWalletLogin(tester, container);
  });
}
