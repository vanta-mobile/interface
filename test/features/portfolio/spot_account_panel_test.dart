import '../../support/portfolio_account_tools.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';
import 'package:vanta/features/portfolio/presentation/spot_account_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('signed-out Spot displays no demo funds and its read button opens sign-in', (
    tester,
  ) async {
    final identity = TestIdentityRepository();
    final spots = TestSpotRepository();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, asterSpotRepository: spots);
    await launch(tester, container);
    container.read(accountProvider.notifier).connect();
    await openPortfolioAccountTools(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('现货'));
    await tester.pumpAndSettle();
    expect(find.byType(SpotAccountPanel), findsOneWidget);
    expect(find.text('10000.00'), findsNothing);
    expect(spots.calls, 0);
    await tester.ensureVisible(find.byKey(const Key('read-spot-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-spot-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(spots.calls, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('manual Spot read, asset filters, failed refresh, language and identity isolation', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final spots = TestSpotRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      asterSpotRepository: spots,
    );
    await launch(tester, container);
    await openPortfolioAccountTools(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spot'));
    await tester.pumpAndSettle();
    expect(spots.calls, 0);
    spots.gate = Completer<void>();
    await tester.ensureVisible(find.byKey(const Key('read-spot-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-spot-account')));
    await tester.pump();
    expect(find.text('Signing the account query…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('read-spot-account'))).onPressed, null);
    spots.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('0.010000000000000001 BTC'), findsOneWidget);
    expect(find.text('0.000000000000000001 BTC'), findsOneWidget);
    expect(find.text('2 ETH'), findsNWidgets(2)); // Locked-only asset remains visible.
    expect(find.text('BNB'), findsNothing);
    expect(container.read(accountReadProvider).account, null);
    await tester.ensureVisible(find.byKey(const Key('spot-hide-zero-balance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spot-hide-zero-balance')));
    await tester.pumpAndSettle();
    expect(find.text('BNB'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('spot-asset-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot-asset-search')), ' eth ');
    await tester.pumpAndSettle();
    expect(find.text('BTC'), findsNothing);
    expect(find.text('ETH'), findsOneWidget);
    spots.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    await tester.ensureVisible(find.byKey(const Key('read-spot-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-spot-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('spot-snapshot-stale')), findsOneWidget);
    expect(find.textContaining('Aster error code: -2015'), findsOneWidget);
    expect(find.text('ETH'), findsOneWidget);
    container.read(localeProvider.notifier).select('zh');
    await tester.pumpAndSettle();
    expect(find.text('Aster 现货账户'), findsOneWidget);
    expect(find.text('冻结余额'), findsOneWidget);
    expect(find.text('ETH'), findsOneWidget);
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(spotAccountReadProvider).account, null);
    expect(find.byKey(const Key('spot-account-address')), findsNothing);
    expect(find.text('ETH'), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('a successful empty Spot account has a spot-specific empty message', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final spots = TestSpotRepository()
      ..result = AsterSpotAccount(
        address: accountAddress,
        receivedAt: DateTime.utc(2026),
        balances: [],
      );
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, asterSpotRepository: spots);
    await launch(tester, container);
    await openPortfolioAccountTools(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('现货'));
    await tester.pumpAndSettle();
    await container.read(spotAccountReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('现货账户暂无资产。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [
    (360.0, 844.0, 1.5, 'zh'),
    (390.0, 844.0, 2.0, 'en'),
    (844.0, 390.0, 1.5, 'en'),
  ]) {
    testWidgets('Spot numbers and read controls fit ${spec.$1} x ${spec.$2}, scale ${spec.$3}', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final spots = TestSpotRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        asterSpotRepository: spots,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      await openPortfolioAccountTools(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(spec.$4 == 'zh' ? '现货' : 'Spot'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('read-spot-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('read-spot-account')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('BTC'));
      await tester.pumpAndSettle();
      expect(find.text('0.010000000000000001 BTC'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
