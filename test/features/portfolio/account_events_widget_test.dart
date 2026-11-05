import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/presentation/account_event_status.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_panel.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_card.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_valuation_rows.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget page) async {
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'balance event displays absolute wallet value, clears unavailable fields and labels partial history',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final account = TestAsterAccountRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        asterAccountRepository: account,
      );
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(accountReadProvider.notifier).refresh();
      container.read(accountReadProvider.notifier).applyEvent(accountUpdate());
      await open(tester, const Scaffold(body: SingleChildScrollView(child: AsterAccountPanel())));
      expect(find.text('102.000000000000000001 USDT'), findsOneWidget);
      expect(find.text('92.000000000000000001 USDT'), findsOneWidget);
      expect(find.text('89.000000000000000001 USDT'), findsNothing);
      expect(find.textContaining('Last applied account event:'), findsOneWidget);
      expect(find.textContaining('Missing rows do not mean closed positions'), findsOneWidget);
      expect(find.text('99999 USDT'), findsNothing);
      expect(account.calls, 1);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('position count and current-symbol filter follow explicit close events', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository();
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
    );
    addTearDown(identity.dispose);
    await launch(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    await open(tester, const PositionRiskScreen());
    await tester.scrollUntilVisible(
      find.byKey(const Key('position-risk-current-symbol')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('position-risk-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('position-risk-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('position-risk-current-symbol')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('position-risk-count')));
    expect(find.text('Position records (1)'), findsOneWidget);
    container
        .read(positionRiskProvider.notifier)
        .applyEvent(
          accountUpdate(
            positions: [accountPositionUpdate(quantity: '0', wallet: '0')],
          ),
        );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('position-risk-count')));
    expect(find.text('Position records (0)'), findsOneWidget);
    expect(container.read(positionRiskProvider).account!.positions.single.symbol, 'ETHUSDT');
    expect(risk.calls, 1);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'mark estimates wait for a server quote newer than the position event and use its updated quantity',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = TestPositionRiskRepository();
      final marks = StreamController<MarkPrices>.broadcast();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        positionRiskRepository: risk,
        markPricesStream: marks.stream,
      );
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(positionRiskProvider.notifier).refresh();
      container
          .read(positionRiskProvider.notifier)
          .applyEvent(accountUpdate(positions: [accountPositionUpdate()..['ep'] = '80000']));
      await open(
        tester,
        Scaffold(
          body: Consumer(
            builder: (_, ref, _) => PositionValuationRows(
              position: ref.watch(positionRiskProvider).account!.positions.first,
            ),
          ),
        ),
      );
      void quote(int time) => marks.add(
        MarkPrices(
          quotes: {
            'BTCUSDT': mapMarkPrice(
              markPayload(time: time, price: '82000'),
              receivedAt: DateTime.utc(2026, 11, 3),
            ),
          },
          fresh: {'BTCUSDT'},
        ),
      );
      quote(accountEventClock - 5);
      await tester.pumpAndSettle();
      expect(find.text('Estimated unrealized PnL'), findsNothing);
      expect(find.text('Event unrealized PnL'), findsOneWidget);
      quote(accountEventClock + 5);
      await tester.pumpAndSettle();
      expect(find.text('Estimated unrealized PnL'), findsOneWidget);
      expect(find.text('-400 USDT'), findsOneWidget);
      expect(find.text('-16,400 USDT'), findsOneWidget);
      expect(find.byKey(const Key('position-estimate-stale-BTCUSDT-BOTH')), findsOneWidget);
      expect(risk.calls, 1);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await marks.close();
    },
  );
  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('event provenance and unavailable risk fields wrap at $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionRiskRepository: TestPositionRiskRepository(),
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(positionRiskProvider.notifier).refresh();
      container.read(positionRiskProvider.notifier).applyEvent(accountUpdate());
      final data = container.read(positionRiskProvider).account!;
      await open(
        tester,
        Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AccountEventStatus(time: data.lastEventAt),
                  PositionRiskCard(position: data.positions.first),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text(spec.$4 == 'en' ? 'Event unrealized PnL' : '事件未实现盈亏'), findsOneWidget);
      expect(find.textContaining('5×'), findsNothing);
      expect(find.textContaining('90,000.123'), findsNothing);
      final time = find.text(spec.$4 == 'en' ? 'Record event time (UTC)' : '记录事件时间（UTC）');
      await tester.ensureVisible(time);
      await tester.pumpAndSettle();
      expect(time, findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
