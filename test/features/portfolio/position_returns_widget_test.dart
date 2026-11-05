import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_card.dart';
import 'package:vanta/features/portfolio/presentation/position_valuation_rows.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  TestPositionRiskRepository repository({bool isolated = false}) =>
      TestPositionRiskRepository()
        ..result = mapPositionRisk(
          [
            positionRiskRow()
              ..['positionAmt'] = '2'
              ..['entryPrice'] = '100'
              ..['markPrice'] = '110'
              ..['notional'] = '220'
              ..['unRealizedProfit'] = '20'
              ..['leverage'] = '10'
              ..['marginType'] = isolated ? 'isolated' : 'cross'
              ..['isolatedWallet'] = '999',
          ],
          address: accountAddress,
          receivedAt: DateTime.utc(2026, 11, 2),
          units: accountFixture().units,
        );

  Future<void> open(WidgetTester tester, ProviderContainer container, {bool card = false}) async {
    await launch(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Consumer(
                builder: (_, ref, _) {
                  final position = ref.watch(positionRiskProvider).account!.positions.first;
                  return card
                      ? PositionRiskCard(position: position)
                      : PositionValuationRows(position: position);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final isolated in [false, true]) {
    testWidgets(
      'snapshot ROE and ${isolated ? 'isolated allocation' : 'cross margin'} keep separate bases',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final risk = repository(isolated: isolated);
        final container = setup(
          tester,
          language: const Locale('en'),
          identityRepository: identity,
          positionRiskRepository: risk,
        );
        addTearDown(identity.dispose);
        await open(tester, container);
        expect(find.text('+90.91%'), findsOneWidget);
        expect(find.text('Snapshot ROE estimate (%)'), findsOneWidget);
        expect(find.text('Estimated initial margin basis'), findsOneWidget);
        expect(
          find.text(isolated ? 'Allocated isolated wallet' : 'Estimated cross position margin'),
          findsOneWidget,
        );
        if (isolated) expect(find.text('999 USDT'), findsOneWidget);
        expect(risk.calls, 1);
        expect(identity.wallets, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }

  testWidgets(
    'public marks recalculate ROE; stale account and price still show historical warning',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = repository();
      final marks = StreamController<MarkPrices>.broadcast();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        positionRiskRepository: risk,
        markPricesStream: marks.stream,
      );
      addTearDown(identity.dispose);
      await open(tester, container);
      final quote = mapMarkPrice(markPayload(price: '120'), receivedAt: markClock);
      marks.add(MarkPrices(quotes: {'BTCUSDT': quote}, fresh: {'BTCUSDT'}));
      await tester.pumpAndSettle();
      expect(find.text('Estimated ROE (%)'), findsOneWidget);
      expect(find.text('+166.67%'), findsOneWidget);
      expect(find.text('24 USDT'), findsNWidgets(2));
      container.read(positionRiskProvider.notifier).markStale();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('position-estimate-stale-BTCUSDT-BOTH')), findsOneWidget);
      marks.add(MarkPrices(quotes: {'BTCUSDT': quote}, connection: MarkPriceConnection.offline));
      await tester.pumpAndSettle();
      expect(find.text('Historical mark price'), findsOneWidget);
      expect(find.text('+166.67%'), findsOneWidget);
      expect(risk.calls, 1);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await marks.close();
    },
  );

  testWidgets('event clears obsolete leverage and ROE rather than applying it to new quantity', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = repository(isolated: true);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
    );
    addTearDown(identity.dispose);
    await open(tester, container);
    expect(find.text('+90.91%'), findsOneWidget);
    container.read(positionRiskProvider.notifier).applyEvent(accountUpdate());
    await tester.pumpAndSettle();
    expect(find.text('+90.91%'), findsNothing);
    expect(find.text('1.50 USDT'), findsOneWidget);
    expect(find.text('Estimated initial margin basis'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(risk.calls, 1);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('ROE fields and formula wrap accessibly at $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionRiskRepository: repository(),
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await open(tester, container, card: true);
      await tester.ensureVisible(find.text('+90.91%'));
      await tester.pumpAndSettle();
      expect(
        find.text(spec.$4 == 'en' ? 'Snapshot ROE estimate (%)' : '快照仓位收益率估算（ROE）'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
