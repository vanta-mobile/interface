import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/spot_open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/data/spot_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/presentation/spot_open_order_card.dart';
import 'package:vanta/features/portfolio/presentation/spot_open_orders_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/portfolio_account_tools.dart';
import '../../support/identity_repository.dart';
import '../../support/spot_open_orders.dart';
import '../../support/trade_fixture.dart';
import '../funding/deposit_wallet_widget_test.dart' show reveal;
import 'spot_open_orders_events_test.dart' show spotUpdate;

Future<void> tapSpot(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder, scrollKey: 'spot-open-orders-scroll');
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets(
      'Spot all-order read, exact refs, filter count, events, retained failure and logout fit $spec',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity,
            repository = TestSpotOpenOrdersRepository();
        addTearDown(identity.dispose);
        final c = setup(
          tester,
          width: spec.$1,
          scale: 1.5,
          language: Locale(spec.$3),
          identityRepository: identity,
          spotOpenOrdersRepository: repository,
        );
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(tester, c);
        openSpotOpenOrders(tester.element(find.byType(Navigator).first));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(SpotOpenOrdersScreen)));
        expect(repository.calls, 0);
        expect(find.byType(SpotOpenOrderCard), findsNothing);
        await tapSpot(tester, 'read-spot-open-orders');
        final count = find.byKey(const Key('spot-open-orders-count'));
        await reveal(tester, count, scrollKey: 'spot-open-orders-scroll');
        expect(find.text(l10n.openOrdersCount(2)), findsOneWidget);
        final filter = find.byKey(const Key('spot-open-orders-filter'));
        await reveal(tester, filter, scrollKey: 'spot-open-orders-scroll');
        await tester.enterText(filter, ' btc ');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(find.text(l10n.openOrdersCount(1)), findsOneWidget);
        expect(find.byType(SpotOpenOrderCard), findsOneWidget);
        await reveal(tester, find.text('9007199254740993'), scrollKey: 'spot-open-orders-scroll');
        expect(find.text('original-9007199254740993'), findsOneWidget);
        expect(find.textContaining('0.100000000000000001 BTC'), findsWidgets);
        expect(find.textContaining('Long'), findsNothing);
        await reveal(tester, filter, scrollKey: 'spot-open-orders-scroll');
        await tester.enterText(filter, 'eth');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        repository.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
        await tapSpot(tester, 'read-spot-open-orders');
        expect(find.textContaining('-2015'), findsOneWidget);
        expect(c.read(spotOpenOrdersProvider).account!.orders.length, 2);
        await reveal(tester, count, scrollKey: 'spot-open-orders-scroll');
        expect(find.text(l10n.openOrdersCount(1)), findsOneWidget);
        c
            .read(spotOpenOrdersProvider.notifier)
            .applyEvent(spotUpdate(symbol: 'ETHUSDT', id: '7', status: 'CANCELED'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.openOrdersCount(0)), findsOneWidget);
        expect(find.text(l10n.spotOpenOrdersNoMatch), findsOneWidget);
        expect(identity.wallets, 0);
        expect(tester.takeException(), null);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(SpotOpenOrderCard), findsNothing);
        expect(c.read(spotOpenOrdersProvider).account, null);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  testWidgets('signed-out read opens authentication and account Spot entry does not auto read', (
    tester,
  ) async {
    final identity = TestIdentityRepository(), repository = TestSpotOpenOrdersRepository();
    addTearDown(identity.dispose);
    final c = setup(tester, identityRepository: identity, spotOpenOrdersRepository: repository);
    await launch(tester, c);
    await openPortfolioAccountTools(tester);
    await tester.tap(find.text('现货'));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('spot-open-orders-entry'));
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(SpotOpenOrdersScreen), findsOneWidget);
    expect(repository.calls, 0);
    await tapSpot(tester, 'read-spot-open-orders');
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.calls, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('empty Spot baseline uses Spot wording', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity,
        repository = TestSpotOpenOrdersRepository();
    addTearDown(identity.dispose);
    repository.result = spotOrdersFixture(rows: []);
    final c = setup(
      tester,
      width: 320,
      scale: 1.5,
      identityRepository: identity,
      spotOpenOrdersRepository: repository,
    );
    await launch(tester, c);
    openSpotOpenOrders(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tapSpot(tester, 'read-spot-open-orders');
    final l10n = AppLocalizations.of(tester.element(find.byType(SpotOpenOrdersScreen)));
    await reveal(tester, find.text(l10n.spotOpenOrdersEmpty), scrollKey: 'spot-open-orders-scroll');
    expect(find.text(l10n.spotOpenOrdersEmpty), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('leaving a pending read discards late rows without another signature', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity,
        repository = TestSpotOpenOrdersRepository();
    addTearDown(identity.dispose);
    final c = setup(tester, identityRepository: identity, spotOpenOrdersRepository: repository);
    await launch(tester, c);
    openSpotOpenOrders(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    repository.gate = Completer();
    await tester.tap(find.byKey(const Key('read-spot-open-orders')));
    await tester.pump();
    expect(repository.calls, 1);
    Navigator.of(tester.element(find.byType(SpotOpenOrdersScreen))).pop();
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(c.read(spotOpenOrdersProvider).account, null);
    expect(find.byType(SpotOpenOrdersScreen), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('quote-sized market event keeps unknown base total and creation time visible', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity,
        repository = TestSpotOpenOrdersRepository();
    addTearDown(identity.dispose);
    final row = spotOpenOrderPayload()
      ..['type'] = 'MARKET'
      ..['origType'] = 'MARKET'
      ..['price'] = '0'
      ..['origQty'] = '0'
      ..['origQuoteOrderQty'] = '100.000000000000000001'
      ..['time'] = null;
    repository.result = spotOrdersFixture(rows: [row]);
    final c = setup(
      tester,
      width: 320,
      scale: 1.5,
      identityRepository: identity,
      spotOpenOrdersRepository: repository,
    );
    await launch(tester, c);
    openSpotOpenOrders(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tapSpot(tester, 'read-spot-open-orders');
    final l10n = AppLocalizations.of(tester.element(find.byType(SpotOpenOrdersScreen)));
    await reveal(
      tester,
      find.text(l10n.spotOpenOrdersQuantityUnknown),
      scrollKey: 'spot-open-orders-scroll',
    );
    expect(find.text(l10n.spotOpenOrdersQuantityUnknown), findsOneWidget);
    expect(find.text('100.000000000000000001 USDT'), findsOneWidget);
    expect(find.text(l10n.openOrdersCreationUnknown), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('missing Spot units keep signed rows with explicit unknown quantity units', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity,
        repository = TestSpotOpenOrdersRepository();
    addTearDown(identity.dispose);
    repository.result = mapSpotOpenOrders(
      [spotOpenOrderPayload()],
      address: accountAddress,
      receivedAt: DateTime.now().toUtc(),
    );
    final c = setup(
      tester,
      width: 320,
      scale: 1.5,
      identityRepository: identity,
      spotOpenOrdersRepository: repository,
    );
    await launch(tester, c);
    openSpotOpenOrders(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tapSpot(tester, 'read-spot-open-orders');
    final l10n = AppLocalizations.of(tester.element(find.byType(SpotOpenOrdersScreen)));
    await reveal(tester, find.text(l10n.spotOpenOrdersUnits), scrollKey: 'spot-open-orders-scroll');
    expect(find.text(l10n.spotOpenOrdersUnits), findsOneWidget);
    expect(find.textContaining(l10n.accountUnitUnavailable), findsWidgets);
    expect(c.read(spotOpenOrdersProvider).account!.orders.single.units, null);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
