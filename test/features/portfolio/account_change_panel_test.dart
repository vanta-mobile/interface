import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/account_change_panel.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(padding: EdgeInsets.all(16), child: AccountChangePanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-change-panel')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'signed-out monitor opens real sign-in UI without requesting keys or creating wallets',
    (tester) async {
      final identity = TestIdentityRepository();
      final changes = TestAccountChangeRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        accountChangeRepository: changes,
        monitorClock: () => changes.now,
      );
      addTearDown(identity.dispose);
      await open(tester, container);
      await tester.ensureVisible(find.byKey(const Key('authorize-account-changes')));
      await tester.tap(find.byKey(const Key('authorize-account-changes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(changes.authorizations, 0);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await changes.dispose();
    },
  );
  testWidgets('connected status never claims live snapshots; reconnect and stop never sign', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final changes = TestAccountChangeRepository();
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      accountChangeRepository: changes,
      monitorClock: () => changes.now,
    );
    addTearDown(identity.dispose);
    await open(tester, container);
    await tester.tap(find.byKey(const Key('authorize-account-changes')));
    await tester.pump();
    changes.channels.single.add(const AccountChangeEvent.connected());
    changes.channels.single.add(
      AccountChangeEvent.changed(AccountChangeKind.account, DateTime.utc(2026, 11, 3)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Change monitor connected · snapshots still need verification'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-change-last-event')), findsOneWidget);
    expect(
      find.textContaining(
        'Totals, available funds, leverage, liquidation prices and ADL need signed verification',
      ),
      findsOneWidget,
    );
    changes.channels.single.addError(const AccountReadFailure('accountNetwork'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reconnect-account-changes')));
    await tester.tap(find.byKey(const Key('reconnect-account-changes')));
    await tester.pump();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await tester.pumpAndSettle();
    expect(changes.authorizations, 1);
    await tester.ensureVisible(find.byKey(const Key('stop-account-changes')));
    await tester.tap(find.byKey(const Key('stop-account-changes')));
    await tester.pumpAndSettle();
    expect(find.text('Not monitoring'), findsOneWidget);
    expect(changes.canceled, 2);
    expect(changes.authorizations, 1);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await changes.dispose();
  });
  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('expanded monitor timestamps and controls wrap at $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final changes = TestAccountChangeRepository();
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        accountChangeRepository: changes,
        monitorClock: () => changes.now,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await open(tester, container);
      await tester.ensureVisible(find.byKey(const Key('authorize-account-changes')));
      await tester.tap(find.byKey(const Key('authorize-account-changes')));
      await tester.pump();
      changes.channels.single.add(const AccountChangeEvent.connected());
      changes.channels.single.add(
        AccountChangeEvent.changed(AccountChangeKind.order, DateTime.utc(2026, 11, 3, 23, 59, 59)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('account-change-last-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-change-last-event')), findsOneWidget);
      expect(tester.takeException(), null);
      expect(container.read(accountChangeProvider).connection, AccountChangeConnection.connected);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await changes.dispose();
    });
  }
}
