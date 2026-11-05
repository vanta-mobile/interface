import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/position_adl_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/position_adl_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/position_adl_indicator.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_screen.dart';

import '../../support/aster_account.dart';
import '../../support/position_adl.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-position-risk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-position-risk')));
    await tester.pumpAndSettle();
  }

  Finder getScroll() => find
      .descendant(
        of: find.byKey(const Key('position-risk-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> showAdl(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('position-adl-panel')),
      200,
      scrollable: getScroll(),
    );
    await tester.pumpAndSettle();
    final header = find.descendant(
      of: find.byKey(const Key('position-adl-panel')),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('read-position-adl')),
      200,
      scrollable: getScroll(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ADL is manually signed, blocks concurrent risk prompt and preserves stale data after refusal',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = TestPositionRiskRepository();
      final adl = TestPositionAdlRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        positionRiskRepository: risk,
        positionAdlRepository: adl,
      );
      addTearDown(identity.dispose);
      await launch(tester, container);
      await open(tester);
      expect(adl.calls, 0);
      await showAdl(tester);
      adl.gate = Completer<void>();
      await tester.tap(find.byKey(const Key('read-position-adl')));
      await tester.pump();
      expect(adl.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('read-position-adl'))).onPressed,
        null,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('read-position-risk'))).onPressed,
        null,
      );
      adl.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('position-adl-time')), findsOneWidget);
      await container.read(positionRiskProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final riskSnapshot = container.read(positionRiskProvider).account;
      final old = container.read(positionAdlProvider).account;
      adl.failure = const AccountReadFailure('authWalletRejected');
      await tester.tap(find.byKey(const Key('read-position-adl')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-read-error')), findsOneWidget);
      expect(find.byKey(const Key('position-adl-stale')), findsOneWidget);
      expect(container.read(positionAdlProvider).account, same(old));
      expect(container.read(positionRiskProvider).account, same(riskSnapshot));
      identity.events.add(null);
      await tester.pumpAndSettle();
      expect(container.read(positionAdlProvider).account, null);
      expect(find.byKey(const Key('position-adl-time')), findsNothing);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('signed-out ADL opens login without requesting data or creating a wallet', (
    tester,
  ) async {
    final identity = TestIdentityRepository();
    final adl = TestPositionAdlRepository();
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionAdlRepository: adl,
    );
    addTearDown(identity.dispose);
    await launch(tester, container);
    await open(tester);
    await showAdl(tester);
    await tester.tap(find.byKey(const Key('read-position-adl')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(adl.calls, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (var level = 0; level <= 4; level++) {
    testWidgets('four-bar ADL indicator maps level $level and exposes accessible text', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final adl = TestPositionAdlRepository()
        ..result = mapPositionAdl(
          [
            positionAdlRow()..['adlQuantile'] = {'BOTH': level},
          ],
          address: accountAddress,
          receivedAt: DateTime.utc(2026),
        );
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        positionAdlRepository: adl,
        positionRiskRepository: TestPositionRiskRepository(),
      );
      addTearDown(identity.dispose);
      await launch(tester, container);
      await container.read(positionAdlProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: PositionAdlIndicator(position: positionRiskFixture().positions.first)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Level $level / 4'), findsOneWidget);
      for (var bar = 0; bar < 4; bar++) {
        final widget = tester.widget<Container>(find.byKey(Key('adl-BTCUSDT-BOTH-$bar')));
        expect(widget.color, bar < level ? AppColors.negative : AppColors.muted);
      }
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('ADL queue: Level $level / 4'), findsOneWidget);
      semantics.dispose();
      container.read(positionAdlProvider.notifier).markStale();
      await tester.pump();
      expect(find.text('Historical level $level / 4 — refresh'), findsOneWidget);
      await container.read(positionAdlProvider.notifier).refresh();
      container.read(positionRiskProvider.notifier).acceptSnapshot(positionRiskFixture());
      await tester.pump();
      expect(find.text('Historical level $level / 4 — refresh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }

  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('unknown ADL and independent snapshots fit $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionAdlRepository: TestPositionAdlRepository(),
        positionRiskRepository: TestPositionRiskRepository(),
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await launch(tester, container);
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const PositionRiskScreen()));
      await tester.pumpAndSettle();
      await container.read(positionRiskProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final unknown = find.text(
        spec.$4 == 'en' ? 'Unknown — read or refresh matching ADL data' : '未知，请读取或刷新匹配的 ADL 数据',
      );
      await tester.scrollUntilVisible(unknown, 200, scrollable: getScroll());
      expect(unknown, findsOneWidget);
      expect(find.byKey(const Key('adl-BTCUSDT-BOTH-0')), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
