import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/presentation/order_recovery_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> show(WidgetTester tester, Finder target) async {
    final scroll = find
        .descendant(
          of: find.byKey(const Key('order-recovery-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 180, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'zh']) {
    testWidgets(
      'recovery entry, unknown retry and verified result; 320/large/landscape $language',
      (tester) async {
        final record = OrderRecoveryRecord(
          query: OrderQuery.capture(liveIntent()),
          createdAt: liveOrderClock,
        );
        final journal = MemoryOrderRecoveryJournal(records: [record]);
        addTearDown(journal.close);
        final identity = TestIdentityRepository()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final repository = TestOrderRecoveryRepository(journal)
          ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          recoveryJournal: journal,
          recoveryRepository: repository,
        );
        await launch(tester, container);
        expect(repository.calls, 0);
        await tester.tap(find.byKey(const Key('trade-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('order-recovery-entry')));
        await tester.pumpAndSettle();
        final messages = AppLocalizations.of(tester.element(find.byType(OrderRecoveryScreen)));
        expect(find.text(messages.orderRecoveryScope), findsOneWidget);
        final button = find.byKey(ValueKey('recover-${record.key}'));
        await show(tester, button);
        expect(find.text('vanta-test-123'), findsOneWidget);
        await tester.tap(button.hitTestable());
        await tester.pumpAndSettle();
        expect(repository.calls, 1);
        expect(journal.snapshot.records.length, 1);
        expect(tester.takeException(), null);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        repository.result = TestLiveOrderRepository().result;
        await show(tester, button);
        await tester.tap(button.hitTestable());
        await tester.pumpAndSettle();
        expect(repository.calls, 2);
        expect(journal.snapshot.records, isEmpty);
        expect(find.text(messages.orderRecoveryVerified), findsOneWidget);
        expect(find.text('12345'), findsOneWidget);
        expect(find.text(messages.orderRecoveryEmpty), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  testWidgets('storage failure remains visible, has retry and does not sign', (tester) async {
    final journal = MemoryOrderRecoveryJournal();
    addTearDown(journal.close);
    journal.publish(
      OrderRecoverySnapshot(failure: const AccountReadFailure('orderRecoveryStorage')),
    );
    final repository = TestOrderRecoveryRepository(journal);
    final container = setup(tester, recoveryJournal: journal, recoveryRepository: repository);
    await launch(tester, container);
    openOrderRecovery(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    final messages = AppLocalizations.of(tester.element(find.byType(OrderRecoveryScreen)));
    expect(find.text(messages.orderRecoveryStorage), findsOneWidget);
    final retry = find.byKey(const Key('order-recovery-reload'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text(messages.orderRecoveryStorage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('signer reconnect is explicit; other wallet pending is not exposed', (tester) async {
    final record = OrderRecoveryRecord(
      query: OrderQuery.capture(liveIntent()),
      createdAt: liveOrderClock,
    );
    final journal = MemoryOrderRecoveryJournal(records: [record]);
    addTearDown(journal.close);
    final identity = TestIdentityRepository()..restored = identityWithWallet;
    addTearDown(identity.dispose);
    final repository = TestOrderRecoveryRepository(journal);
    final container = setup(
      tester,
      identityRepository: identity,
      recoveryJournal: journal,
      recoveryRepository: repository,
    );
    await launch(tester, container);
    openOrderRecovery(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    expect(find.text(record.query.clientOrderId), findsNothing);
    expect(find.byKey(const Key('order-recovery-connect')), findsOneWidget);
    expect(repository.calls, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
