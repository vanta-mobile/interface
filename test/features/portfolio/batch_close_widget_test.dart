import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/batch_close_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/presentation/batch_close_controls.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_screen.dart';

import '../../support/aster_account.dart';
import '../../support/batch_close.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    Navigator.of(tester.element(find.byType(Navigator).first))
        .push<void>(MaterialPageRoute(builder: (_) => const PositionRiskScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, String key) async {
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('position-risk-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('signed-out and unread close-all is disabled without automatic prompts', (
    tester,
  ) async {
    final identity = TestIdentityRepository(), risk = TestPositionRiskRepository();
    final repository = TestBatchLiveRepository(batchRiskFixture());
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      positionRiskRepository: risk,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await visible(tester, 'batch-close-open');
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('batch-close-open'))).onPressed,
      null,
    );
    expect(risk.calls, 0);
    expect(repository.posts, isEmpty);
    expect(identity.wallets, 0);
    await dispose(tester, container);
  });
  testWidgets('confirmation lists exact wallet sides quantities IDs; cancel submits nothing', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository()..result = batchRiskFixture();
    final repository = TestBatchLiveRepository(risk.result);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tap(tester, 'batch-close-open');
    final dialog = find.byType(AlertDialog);
    for (final text in [accountAddress, 'BTCUSDT', 'ETHUSDT', '0.01 BTC', '0.02 ETH']) {
      expect(
        find.descendant(of: dialog, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    expect(find.descendant(of: dialog, matching: find.text('BOTH')), findsNWidgets(2));
    expect(
      find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (w) => w is SelectableText && (w.data?.startsWith('vanta-') ?? false),
        ),
      ),
      findsNWidgets(2),
    );
    expect(find.descendant(of: dialog, matching: find.text('ZEROUSDT')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.posts, isEmpty);
    expect(repository.reads, isEmpty);
    expect(container.read(batchCloseProvider).intent, null);
    await dispose(tester, container);
  });
  testWidgets('current-symbol scope sends only confirmed position and displays remaining read', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository()..result = batchRiskFixture();
    final repository = TestBatchLiveRepository(risk.result);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tap(tester, 'position-risk-current-symbol');
    expect(tester.widget<BatchCloseControls>(find.byType(BatchCloseControls)).symbol, 'BTCUSDT');
    await tap(tester, 'batch-close-open');
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('ETHUSDT')),
      findsNothing,
    );
    risk.result = PositionRiskSnapshot(
      address: accountAddress,
      receivedAt: liveOrderClock,
      positions: [],
    );
    await tester.tap(find.byKey(const Key('batch-close-confirm')));
    await tester.pumpAndSettle();
    expect(repository.posts.map((p) => p.context.symbol), ['BTCUSDT']);
    expect(risk.calls, 2);
    await visible(tester, 'batch-close-read-remaining');
    expect(find.text('0 BTC'), findsOneWidget);
    expect(find.textContaining('Signed query: FILLED'), findsOneWidget);
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
  testWidgets('unknown batch stays query-only; failure and unsubmitted positions remain visible', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository()..result = batchRiskFixture();
    final repository = TestBatchLiveRepository(risk.result)..unknown = true;
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      positionRiskRepository: risk,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await container.read(positionRiskProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tap(tester, 'batch-close-open');
    await tester.tap(find.byKey(const Key('batch-close-confirm')));
    await tester.pumpAndSettle();
    await visible(tester, 'batch-close-recheck');
    expect(find.text('Not submitted'), findsOneWidget);
    expect(repository.posts.length, 1);
    repository.unknown = false;
    await tester.tap(find.byKey(const Key('batch-close-recheck')));
    await tester.pumpAndSettle();
    expect(repository.posts.length, 1);
    expect(repository.reads.length, 1);
    expect(risk.calls, 1);
    await visible(tester, 'batch-close-result-ETHUSDT:BOTH');
    expect(find.text('Not submitted'), findsOneWidget);
    expect(find.byKey(const Key('batch-close-recheck')), findsNothing);
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'close-all confirmation and per-position results fit narrow enlarged and landscape $locale',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final risk = TestPositionRiskRepository()..result = batchRiskFixture(hedge: true);
        final repository = TestBatchLiveRepository(risk.result, hedge: true);
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(locale),
          identityRepository: identity,
          positionRiskRepository: risk,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
        );
        await open(tester, container);
        await container.read(positionRiskProvider.notifier).refresh();
        await tester.pumpAndSettle();
        await tap(tester, 'batch-close-open');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), null);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        risk.result = PositionRiskSnapshot(
          address: accountAddress,
          receivedAt: liveOrderClock,
          positions: [],
        );
        await tester.tap(find.byKey(const Key('batch-close-confirm')));
        await tester.pumpAndSettle();
        await visible(tester, 'batch-close-read-remaining');
        expect(repository.posts.length, 3);
        expect(find.text('0 BTC'), findsNWidgets(2));
        expect(find.text('0 ETH'), findsOneWidget);
        expect(tester.takeException(), null);
        expect(identity.wallets, 0);
        await dispose(tester, container);
      },
    );
  }

  testWidgets(
    'remaining read preserves current signed quantity and suppresses stale or failed data',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = TestPositionRiskRepository()..result = batchRiskFixture();
      final repository = TestBatchLiveRepository(risk.result);
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        positionRiskRepository: risk,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      await container.read(positionRiskProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await tap(tester, 'batch-close-open');
      risk.result = batchRiskFixture(btcQuantity: '-0.003');
      await tester.tap(find.byKey(const Key('batch-close-confirm')));
      await tester.pumpAndSettle();
      await visible(tester, 'batch-close-read-remaining');
      final btcResult = find.byKey(const Key('batch-close-result-BTCUSDT:BOTH'));
      final ethResult = find.byKey(const Key('batch-close-result-ETHUSDT:BOTH'));
      final remainingBtc = find.descendant(of: btcResult, matching: find.text('-0.003 BTC'));
      expect(remainingBtc, findsOneWidget);
      expect(find.descendant(of: ethResult, matching: find.text('-0.02 ETH')), findsOneWidget);
      container.read(positionRiskProvider.notifier).markStale();
      await tester.pumpAndSettle();
      expect(remainingBtc, findsNothing);
      risk.failure = const AccountReadFailure('authWalletRejected');
      await tap(tester, 'batch-close-read-remaining');
      expect(remainingBtc, findsNothing);
      expect(repository.posts.length, 2);
      expect(container.read(batchCloseProvider).needsRecheck, false);
      expect(tester.takeException(), null);
      await dispose(tester, container);
    },
  );
}
