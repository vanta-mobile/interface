import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/authorization/presentation/enable_trading_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_authorization.dart';

const _identity = AuthIdentity(
  id: 'user-1',
  email: 'test@example.com',
  walletAddress: '0x1111111111111111111111111111111111111111',
  signingAvailable: true,
);

class _IdentityRepository extends TestIdentityRepository {
  @override
  Future<AuthIdentity> ensureWallet() async {
    await super.ensureWallet();
    return _identity;
  }
}

Future<ProviderContainer> _launch(
  WidgetTester tester, {
  required TestIdentityRepository identity,
  required TestTradingAuthorizationRepository authorization,
  bool direct = false,
  Size size = const Size(393, 818),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(identity.dispose);
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      privyConfigurationProvider.overrideWithValue(
        const PrivyConfiguration(appId: 'fixture', clientId: 'fixture'),
      ),
      tradingAuthorizationRepositoryProvider.overrideWithValue(authorization),
    ],
  );
  addTearDown(container.dispose);
  container.read(authProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => direct
                      ? const EnableTradingScreen()
                      : const LoginScreen(account: Text('Account settings')),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final social in SocialLoginProvider.values) {
    testWidgets('$social login automatically enables trading and returns home', (tester) async {
      final identity = _IdentityRepository();
      final authorization = TestTradingAuthorizationRepository();
      final container = await _launch(tester, identity: identity, authorization: authorization);
      await tester.tap(
        find.byKey(Key(social == SocialLoginProvider.google ? 'login-google' : 'login-x')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('enable-trading-page')), findsNothing);
      expect(container.read(authProvider).identity, _identity);
      expect(authorization.enables, 1);
      expect(authorization.review!.canWithdraw, false);
      expect(authorization.review!.ipWhitelist, isEmpty);
      expect(
        authorization.review!.expiresAt.difference(authorization.review!.preparedAt),
        const Duration(days: 30),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('signing disables duplicate submissions and returns home on acknowledgement', (
    tester,
  ) async {
    final identity = _IdentityRepository()..restored = _identity;
    final authorization = TestTradingAuthorizationRepository()..enableGate = Completer<void>();
    final container = await _launch(
      tester,
      identity: identity,
      authorization: authorization,
      direct: true,
    );
    final sign = find.byKey(const Key('enable-trading-sign'));
    await tester.tap(sign);
    await tester.pump();
    expect(authorization.enables, 1);
    expect(authorization.review!.canWithdraw, false);
    expect(authorization.review!.ipWhitelist, isEmpty);
    expect(
      authorization.review!.expiresAt.difference(authorization.review!.preparedAt),
      const Duration(days: 30),
    );
    expect(tester.widget<AuthActionButton>(sign).busy, true);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('enable-trading-switch'))).onPressed,
      isNull,
    );
    await container.read(tradingAuthorizationProvider.notifier).enableTrading();
    expect(authorization.enables, 1);
    authorization.enableGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    expect(container.read(authProvider).identity, _identity);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rejected signature keeps wallet and allows an explicit retry', (tester) async {
    final identity = _IdentityRepository()..restored = _identity;
    final authorization = TestTradingAuthorizationRepository()
      ..failure = const AccountReadFailure(
        'authWalletRejected',
        details: ApiErrorDetails(message: 'Signature declined'),
      );
    await _launch(tester, identity: identity, authorization: authorization, direct: true);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(find.text('Signature declined'), findsOneWidget);
    expect(find.textContaining('0x1111…1111'), findsOneWidget);
    authorization.failure = null;
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(authorization.enables, 2);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown result survives leaving and access checks never resubmit a grant', (
    tester,
  ) async {
    final identity = _IdentityRepository()..restored = _identity;
    final authorization = TestTradingAuthorizationRepository()
      ..result = TradingAuthorizationResult.unknown;
    final container = await _launch(
      tester,
      identity: identity,
      authorization: authorization,
      direct: true,
    );
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(find.text('Check signed API access'), findsOneWidget);
    final controller = container.read(tradingAuthorizationProvider.notifier);
    controller.cancel();
    controller.prepare();
    await controller.enableTrading();
    expect(authorization.enables, 1);
    expect(container.read(tradingAuthorizationProvider).review, isNull);
    await tester.tap(find.byKey(const Key('enable-trading-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Check signed API access'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(authorization.checks, 1);
    expect(authorization.enables, 1);
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    expect(container.read(tradingAuthorizationProvider).check!.futuresCanTrade, true);
    expect(find.textContaining('does not prove order execution'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving a pending signature retains its state on reopening', (tester) async {
    final identity = _IdentityRepository()..restored = _identity;
    final authorization = TestTradingAuthorizationRepository()..enableGate = Completer<void>();
    await _launch(tester, identity: identity, authorization: authorization, direct: true);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<AuthActionButton>(find.byKey(const Key('enable-trading-sign'))).busy,
      true,
    );
    expect(authorization.enables, 1);
    authorization.enableGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed embedded wallet creation can be retried before any grant', (tester) async {
    final identity = _IdentityRepository()..walletFailure = const AuthFailure('authNetwork');
    final authorization = TestTradingAuthorizationRepository();
    final container = await _launch(tester, identity: identity, authorization: authorization);
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(find.text('Create embedded wallet'), findsOneWidget);
    identity.walletFailure = null;
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.walletAddress, _identity.walletAddress);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    expect(authorization.enables, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final name in ['MetaMask', 'Trust Wallet', '', null]) {
    testWidgets('external wallet displays its Reown name or localized fallback: $name', (
      tester,
    ) async {
      final identity = _IdentityRepository()
        ..restored = AuthIdentity(
          id: 'user-1',
          walletAddress: _identity.walletAddress,
          walletKind: WalletKind.external,
          walletName: name,
          signingAvailable: true,
        );
      await _launch(
        tester,
        identity: identity,
        authorization: TestTradingAuthorizationRepository(),
        direct: true,
      );
      final expected = name == null || name.isEmpty ? 'External EOA wallet' : name;
      expect(find.text('$expected · 0x1111…1111'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('wallet summary copies the full address', (tester) async {
    final identity = _IdentityRepository()..restored = _identity;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _launch(
      tester,
      identity: identity,
      authorization: TestTradingAuthorizationRepository(),
      direct: true,
    );
    await tester.tap(find.byKey(const Key('enable-trading-wallet')));
    expect(copied, _identity.walletAddress);
    await tester.pumpWidget(const SizedBox());
  });

  for (final spec in [(const Size(320, 640), 1.8), (const Size(844, 390), 1.5)]) {
    testWidgets('sign and cancel remain reachable at ${spec.$1}, scale ${spec.$2}', (tester) async {
      final identity = _IdentityRepository()..restored = _identity;
      final authorization = TestTradingAuthorizationRepository();
      await _launch(
        tester,
        identity: identity,
        authorization: authorization,
        direct: true,
        size: spec.$1,
        scale: spec.$2,
      );
      expect(find.byKey(const Key('enable-trading-sign')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('enable-trading-cancel')).hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('enable-trading-switch')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('enable-trading-cancel')));
      await tester.pumpAndSettle();
      expect(authorization.enables, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
