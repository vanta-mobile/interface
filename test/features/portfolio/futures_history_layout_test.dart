import '../../support/aster_account.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/futures_history_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/presentation/futures_history_record_card.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/futures_history.dart';
import '../../support/futures_history_widget.dart';
import '../../support/identity_repository.dart';

void main() {
  for (final shape in [(320.0, 844.0, 1.5), (844.0, 390.0, 1.5), (768.0, 1024.0, 1.0)]) {
    for (final language in ['en', 'zh']) {
      for (final kind in FuturesHistoryKind.values) {
        testWidgets(
          'history $kind fits ${shape.$1}x${shape.$2} $language, translates, expires and logs out',
          (tester) async {
            final identity = TestIdentityRepository()..restored = signingIdentity;
            final repository = TestFuturesHistoryRepository();
            final container = await launchFuturesHistory(
              tester,
              repository,
              identity: identity,
              width: shape.$1,
              height: shape.$2,
              scale: shape.$3,
              language: language,
            );
            await chooseFuturesKind(tester, kind);
            if (kind == FuturesHistoryKind.trades) await setFuturesSymbol(tester, 'BTCUSDT');
            await tapFutures(tester, 'read-futures-history');
            final card = find.byType(FuturesHistoryRecordCard);
            expect(card, findsOneWidget);
            await revealFutures(tester, card);
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            final snapshot = container.read(futuresHistoryProvider).account;
            container.read(localeProvider.notifier).select(language == 'en' ? 'zh' : 'en');
            await tester.pumpAndSettle();
            expect(container.read(futuresHistoryProvider).account, same(snapshot));
            expect(repository.queries, hasLength(1));
            expect(tester.takeException(), null);
            await tester.pump(const Duration(seconds: 31));
            expect(find.byKey(const Key('futures-history-snapshot-stale')), findsOneWidget);
            identity.events.add(null);
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('futures-history-wallet')), findsNothing);
            expect(find.byType(FuturesHistoryRecordCard), findsNothing);
            expect(container.read(futuresHistoryProvider).query.symbol, isEmpty);
            expect(container.read(futuresHistoryProvider).query.incomeType, isEmpty);
            expect(repository.queries, hasLength(1));
            expect(tester.takeException(), null);
            await closeFuturesHistory(tester, container);
          },
        );
      }
    }
  }
  testWidgets('background/resume retains stale history without automatic reread', (tester) async {
    final repository = TestFuturesHistoryRepository();
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history');
    final snapshot = container.read(futuresHistoryProvider).account;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(container.read(futuresHistoryProvider).stale, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(container.read(futuresHistoryProvider).account, same(snapshot));
    expect(find.byKey(const Key('futures-history-snapshot-stale')), findsOneWidget);
    expect(repository.queries, hasLength(1));
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });
}
