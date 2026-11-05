import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/presentation/position_valuation_rows.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_card.dart';
import 'package:vanta/features/portfolio/presentation/position_mark_status.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets(
    'complete stream recovery clears the REST warning while partial outage remains recoverable',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final marks = StreamController<MarkPrices>.broadcast();
      final risk = TestPositionRiskRepository();
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
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const Scaffold(body: PositionMarkStatus())));
      await tester.pumpAndSettle();
      marks.add(
        MarkPrices(
          fresh: {'BTCUSDT'},
          connection: MarkPriceConnection.online,
          snapshotFailed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh mark prices: 1 / 1 symbols'), findsOneWidget);
      expect(
        find.text('Some mark prices are unavailable or stale. Retained values are historical.'),
        findsNothing,
      );
      marks.add(MarkPrices(connection: MarkPriceConnection.offline, snapshotFailed: true));
      await tester.pumpAndSettle();
      expect(find.text('Fresh mark prices: 0 / 1 symbols'), findsOneWidget);
      expect(
        find.text('Some mark prices are unavailable or stale. Retained values are historical.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retry-position-marks')), findsOneWidget);
      expect(risk.calls, 1);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await marks.close();
    },
  );
  testWidgets(
    'mark estimates preserve signed snapshot values and become historical after price loss or position expiry',
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
      final original = container.read(positionRiskProvider).account;
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SingleChildScrollView(
              child: PositionValuationRows(position: risk.result.positions.first),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Snapshot mark price'), findsOneWidget);
      expect(find.text('Estimated unrealized PnL'), findsNothing);
      final quote = mapMarkPrice(
        markPayload(price: '82000.000000000000000001'),
        receivedAt: markClock,
      );
      marks.add(
        MarkPrices(
          quotes: {'BTCUSDT': quote},
          fresh: {'BTCUSDT'},
          connection: MarkPriceConnection.online,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Current mark price'), findsOneWidget);
      expect(find.text('82,000.000000000000000001 USDT/BTC'), findsOneWidget);
      expect(find.text('Estimated unrealized PnL'), findsOneWidget);
      expect(find.text('Snapshot unrealized PnL'), findsOneWidget);
      expect(find.text('-0.000000000000001 USDT'), findsOneWidget);
      expect(container.read(positionRiskProvider).account, same(original));
      marks.add(MarkPrices(quotes: {'BTCUSDT': quote}, connection: MarkPriceConnection.offline));
      await tester.pumpAndSettle();
      expect(find.text('Historical mark price'), findsOneWidget);
      expect(find.byKey(const Key('position-estimate-stale-BTCUSDT-BOTH')), findsOneWidget);
      marks.add(
        MarkPrices(
          quotes: {'BTCUSDT': quote},
          fresh: {'BTCUSDT'},
          connection: MarkPriceConnection.online,
        ),
      );
      container.read(positionRiskProvider.notifier).markStale();
      await tester.pumpAndSettle();
      expect(find.text('Current mark price'), findsOneWidget);
      expect(find.byKey(const Key('position-estimate-stale-BTCUSDT-BOTH')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await marks.close();
    },
  );

  testWidgets('a newer signed position snapshot takes precedence over retained public marks', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository();
    final quote = mapMarkPrice(markPayload(price: '1'), receivedAt: DateTime.utc(2026, 1));
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
      markPricesStream: Stream.value(MarkPrices(quotes: {'BTCUSDT': quote}, fresh: {'BTCUSDT'})),
    );
    addTearDown(identity.dispose);
    await launch(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(body: PositionValuationRows(position: risk.result.positions.first)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Snapshot mark price'), findsOneWidget);
    expect(find.text('Estimated unrealized PnL'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('long decimal mark estimates wrap without overflow at $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = TestPositionRiskRepository();
      final quote = mapMarkPrice(markPayload(), receivedAt: markClock);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionRiskRepository: risk,
        markPricesStream: Stream.value(MarkPrices(quotes: {'BTCUSDT': quote}, fresh: {'BTCUSDT'})),
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(positionRiskProvider.notifier).refresh();
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SingleChildScrollView(
              child: PositionRiskCard(position: risk.result.positions.first),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(spec.$4 == 'en' ? 'Estimated unrealized PnL' : '估算未实现盈亏'),
      );
      await tester.pumpAndSettle();
      expect(find.text('81,000.123456789123456789 USDT/BTC'), findsOneWidget);
      expect(find.textContaining('90,000.123456789123456789'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
