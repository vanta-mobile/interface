import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/points/presentation/points_page.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/presentation/quick_order_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/order_form.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

String quantityLabel(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('quick-order-quantity'))).decoration!.labelText!;

AppLocalizations messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(QuickOrderPanel)));

const publicBtc = AsterInstrument(symbol: 'BTCUSDT', base: 'PUBLICBTC', ticker: {});

void main() {
  for (final language in ['en', 'zh']) {
    for (final spec in [(320.0, 844.0, 1.5), (844.0, 390.0, 1.0), (768.0, 1024.0, 1.0)]) {
      for (final signedIn in [false, true]) {
        testWidgets('first visit chart/BTC/blank quick input $language $spec signed=$signedIn', (
          tester,
        ) async {
          final fixture = NavigationFixture(
            tester,
            language: language,
            width: spec.$1,
            scale: spec.$3,
            signedIn: signedIn,
          );
          tester.view.physicalSize = Size(spec.$1, spec.$2);
          await launch(tester, fixture.container);
          expect(fixture.container.read(symbolProvider), 'BTCUSDT');
          expect(
            tester
                .widget<SegmentedButton<bool>>(find.byKey(const Key('trade-workspace-tabs')))
                .selected,
            {true},
          );
          expect(find.byType(QuickOrderPanel), findsOneWidget);
          expect(find.byType(OrderForm), findsNothing);
          expect(find.byType(PointsPage), findsNothing);
          expect(quickQuantity(tester), '');
          expect(quantityLabel(tester), messages(tester).liveOrderQuantity('BTC'));
          for (final percent in [25, 50, 75, 100]) {
            final chip = tester.widget<ChoiceChip>(find.byKey(Key('quick-order-percent-$percent')));
            expect(chip.selected, false);
            expect(chip.onSelected, null);
          }
          for (final side in ['buy', 'sell']) {
            expect(
              tester.widget<FilledButton>(find.byKey(Key('quick-order-$side'))).onPressed,
              null,
            );
          }
          for (final key in [
            'leverage',
            'margin-mode',
            'position-mode',
            'asset-mode',
            'available',
          ]) {
            expect(quickValue(tester, 'quick-order-$key'), '—');
          }
          expect(
            tester
                .widget<SwitchListTile>(
                  find.byKey(const Key('quick-order-confirmation-preference')),
                )
                .value,
            true,
          );
          for (final key in [
            'quick-order-quantity',
            'quick-order-buy',
            'quick-order-confirmation-preference',
          ]) {
            await tester.ensureVisible(find.byKey(Key(key)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
          }
          fixture.expectNoAccountMutation();
          await fixture.close(tester);
        });
      }
    }

    testWidgets('explicit initial symbol is honored $language', (tester) async {
      final fixture = NavigationFixture(tester, language: language);
      fixture.container.read(symbolProvider.notifier).select('ETHUSDT');
      await launch(tester, fixture.container);
      expect(fixture.container.read(symbolProvider), 'ETHUSDT');
      expect(quantityLabel(tester), messages(tester).liveOrderQuantity('ETH'));
      expect(find.byType(QuickOrderPanel), findsOneWidget);
      expect(quickQuantity(tester), '');
      fixture.expectNoAccountMutation();
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });

    for (final assetMode in FuturesAssetMode.values) {
      testWidgets(
        'explicit read displays actual account settings, no preset writes $language $assetMode',
        (tester) async {
          final fixture = NavigationFixture(tester, language: language, width: 320, scale: 1.5);
          final original = liveContext(
            mode: FuturesPositionMode.hedge,
            assetMode: assetMode,
            bid: '79999',
            ask: '80001',
            available: '7.123456789012345678',
          );
          fixture.orders.context = LiveOrderContext(
            address: original.address,
            rules: original.rules,
            mode: original.mode,
            marginMode: assetMode == FuturesAssetMode.multi
                ? PositionMarginMode.cross
                : PositionMarginMode.isolated,
            leverage: 37,
            markPrice: original.markPrice,
            lastPrice: original.lastPrice,
            receivedAt: original.receivedAt,
            positions: original.positions,
            bid: original.bid,
            ask: original.ask,
            funds: original.funds,
          );
          await launch(tester, fixture.container);
          fixture.expectNoAccountMutation();
          await tapNavigationControl(tester, 'quick-order-read');
          final l10n = messages(tester);
          expect(quickValue(tester, 'quick-order-leverage'), '37×');
          expect(quickValue(tester, 'quick-order-position-mode'), l10n.positionModeHedge);
          expect(
            quickValue(tester, 'quick-order-margin-mode'),
            assetMode == FuturesAssetMode.multi ? l10n.cross : l10n.accountIsolatedMode,
          );
          expect(
            quickValue(tester, 'quick-order-asset-mode'),
            assetMode == FuturesAssetMode.multi ? l10n.assetModeMulti : l10n.assetModeSingle,
          );
          expect(quickValue(tester, 'quick-order-available'), '7.123456789012345678 USDT');
          expect(quickQuantity(tester), '');
          await tapNavigationControl(tester, 'navigation-portfolio');
          await tapNavigationControl(tester, 'navigation-futures');
          expect(quickValue(tester, 'quick-order-leverage'), '37×');
          fixture.expectNoAccountMutation(contextReads: 1, sizingReads: 1);
          expect(tester.takeException(), null);
          await fixture.close(tester);
        },
      );
    }
  }

  testWidgets('unit waits for matched public metadata without private read or symbol guessing', (
    tester,
  ) async {
    final gate = Completer<List<AsterInstrument>>();
    final fixture = NavigationFixture(tester, instrumentsLoader: () => gate.future);
    await launch(tester, fixture.container);
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('—'));
    gate.complete([publicBtc]);
    await tester.pumpAndSettle();
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('PUBLICBTC'));
    fixture.container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('—'));
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('metadata failure stays unknown; public retry restores exact unit', (tester) async {
    var fail = true;
    final fixture = NavigationFixture(
      tester,
      instrumentsLoader: () async {
        if (fail) throw StateError('synthetic public metadata failure');
        return [publicBtc];
      },
    );
    await launch(tester, fixture.container);
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('—'));
    fail = false;
    fixture.container.invalidate(instrumentsProvider);
    await tester.pumpAndSettle();
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('PUBLICBTC'));
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('signed contract unit overrides public metadata; missing balance remains unknown', (
    tester,
  ) async {
    final fixture = NavigationFixture(tester, instrumentsLoader: () async => [publicBtc]);
    fixture.orders.context = liveContext(available: null);
    await launch(tester, fixture.container);
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('PUBLICBTC'));
    await tapNavigationControl(tester, 'quick-order-read');
    expect(quantityLabel(tester), messages(tester).liveOrderQuantity('BTC'));
    expect(quickValue(tester, 'quick-order-available'), '—');
    expect(fixture.container.read(liveOrderProvider).context, same(fixture.orders.context));
    fixture.expectNoAccountMutation(contextReads: 1, sizingReads: 1);
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });
}
