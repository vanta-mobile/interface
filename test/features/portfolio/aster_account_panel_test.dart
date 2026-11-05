import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('portfolio requires sign-in and never borrows the demo balance', (tester) async {
    final identity = TestIdentityRepository();
    final accounts = TestAsterAccountRepository();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, asterAccountRepository: accounts);
    await launch(tester, container);
    container.read(accountProvider.notifier).connect();
    await tester.tap(find.text('资产'));
    await tester.pumpAndSettle();
    expect(find.byType(AsterAccountPanel), findsOneWidget);
    expect(find.text('10000.00'), findsNothing);
    expect(accounts.calls, 0);
    await tester.ensureVisible(find.byKey(const Key('read-aster-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-aster-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(accounts.calls, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual signing, stale error, asset filters, demo separation and logout', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final accounts = TestAsterAccountRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      asterAccountRepository: accounts,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    expect(accounts.calls, 0);
    expect(find.byKey(const Key('aster-account-address')), findsOneWidget);
    accounts.gate = Completer<void>();
    await tester.ensureVisible(find.byKey(const Key('read-aster-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-aster-account')));
    await tester.pump();
    expect(find.text('Confirm the account read signature in your wallet.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('read-aster-account'))).onPressed,
      null,
    );
    accounts.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-snapshot-time')), findsOneWidget);
    expect(find.text('0.000000000000000001 BTC'), findsOneWidget);
    expect(find.text('80,000.01 USDT/BTC'), findsOneWidget);
    expect(find.text('-1 USDT'), findsNWidgets(3));
    expect(find.text('BNB'), findsNothing);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('BNB'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('account-asset-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-asset-search')), 'does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No assets match the current filters.'), findsOneWidget);
    accounts.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    await tester.ensureVisible(find.byKey(const Key('read-aster-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-aster-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-snapshot-stale')), findsOneWidget);
    expect(find.textContaining('Aster error code: -2015'), findsOneWidget);
    expect(find.text('No assets match the current filters.'), findsOneWidget); // input retained
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(accountReadProvider).account, null);
    expect(find.byKey(const Key('aster-account-address')), findsNothing);
    expect(find.byKey(const Key('account-snapshot-time')), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [(360.0, 1.0, 'zh'), (390.0, 2.0, 'en'), (844.0, 1.5, 'en')]) {
    testWidgets(
      'account numbers, metadata failure and errors fit ${spec.$1}, scale ${spec.$2}, ${spec.$3}',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final accounts = TestAsterAccountRepository()
          ..result = mapAsterAccount(
            accountPayload()..['totalMarginBalance'] = null,
            address: accountAddress,
            receivedAt: DateTime.utc(2026),
          );
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: spec.$1,
          scale: spec.$2,
          identityRepository: identity,
          asterAccountRepository: accounts,
          language: Locale(spec.$3),
        );
        if (spec.$1 == 844) tester.view.physicalSize = const Size(844, 390);
        await launch(tester, container);
        await tester.tap(find.text(spec.$3 == 'en' ? 'Portfolio' : '资产'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('read-aster-account')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('read-aster-account')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('account-snapshot-time')), findsOneWidget);
        await tester.ensureVisible(find.text('BTCUSDT').last);
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(
          find.textContaining(spec.$3 == 'en' ? '(unit unavailable)' : '（单位待确认）'),
          findsNWidgets(4),
        );
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}
