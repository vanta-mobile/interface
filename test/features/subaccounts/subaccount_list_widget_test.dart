import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/data/subaccount_list_mapper.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_list_screen.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/subaccounts.dart';
import '../../support/trade_fixture.dart';

Future<void> show(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(
        of: find.byKey(const Key('subaccount-list-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(target, 150, scrollable: scroll);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [(320.0, 844.0, 'zh'), (320.0, 844.0, 'en'), (844.0, 390.0, 'en')]) {
    testWidgets('account-menu entry, explicit read, copy ID, search and failed refresh fit $spec', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestSubaccountListRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: 1.5,
        language: Locale(spec.$3),
        identityRepository: identity,
        subaccountListRepository: repository,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      final before = container.read(accountProvider);
      await tester.tap(find.byKey(const Key('account-button')));
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('subaccount-list-entry'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(SubaccountListScreen), findsOneWidget);
      expect(repository.calls, 0);
      final l10n = AppLocalizations.of(tester.element(find.byType(SubaccountListScreen)));
      final refresh = find.byKey(const Key('subaccount-list-refresh'));
      await show(tester, refresh);
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      await show(tester, find.text('9007199254740993'));
      expect(find.text('交易台 / Desk A'), findsOneWidget);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final copy = find.byKey(const Key('subaccount-copy-9007199254740993'));
      await show(tester, copy);
      await tester.tap(copy.hitTestable());
      expect(copied, '9007199254740993');
      final search = find.byKey(const Key('subaccount-list-search'));
      await show(tester, search);
      await tester.enterText(search, ' desk a ');
      await tester.pumpAndSettle();
      expect(find.text('100000'), findsNothing);
      repository.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
      await show(tester, refresh);
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('account-read-error')));
      expect(find.textContaining('-2015'), findsOneWidget);
      await show(tester, search);
      expect(tester.widget<TextField>(search).controller?.text ?? '', ' desk a ');
      expect(find.text('100000'), findsNothing);
      repository.failure = null;
      await show(tester, refresh);
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      await show(tester, search);
      await tester.enterText(search, 'no such account');
      await tester.pumpAndSettle();
      expect(find.text(l10n.subaccountNoMatches), findsOneWidget);
      expect(container.read(accountProvider), same(before));
      expect(container.read(authProvider).identity, same(signingIdentity));
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets('signed-out list requests login without private reads or demo children', (
    tester,
  ) async {
    final identity = TestIdentityRepository();
    final repository = TestSubaccountListRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      subaccountListRepository: repository,
    );
    await launch(tester, container);
    openSubaccountList(tester.element(find.byKey(const Key('account-button'))));
    await tester.pumpAndSettle();
    final refresh = find.byKey(const Key('subaccount-list-refresh'));
    await show(tester, refresh);
    await tester.tap(refresh.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.text('9007199254740993'), findsNothing);
    expect(repository.calls, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('stopping waiting or leaving the screen discards a late sign result', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestSubaccountListRepository()..gate = Completer();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      subaccountListRepository: repository,
    );
    await launch(tester, container);
    openSubaccountList(tester.element(find.byKey(const Key('account-button'))));
    await tester.pumpAndSettle();
    final refresh = find.byKey(const Key('subaccount-list-refresh'));
    await show(tester, refresh);
    await tester.tap(refresh.hitTestable());
    await tester.pump();
    expect(container.read(subaccountListProvider).busy, true);
    final stop = find.byKey(const Key('subaccount-list-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(repository.sends, 0);
    repository.gate = Completer();
    await show(tester, refresh);
    await tester.tap(refresh.hitTestable());
    await tester.pump();
    Navigator.of(tester.element(find.byType(SubaccountListScreen))).pop();
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(repository.sends, 0);
    expect(container.exists(subaccountListProvider), false);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'logout immediately hides directory and search; empty reads and parent-only responses remain explicit',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestSubaccountListRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        subaccountListRepository: repository,
      );
      await launch(tester, container);
      openSubaccountList(tester.element(find.byKey(const Key('account-button'))));
      await tester.pumpAndSettle();
      final refresh = find.byKey(const Key('subaccount-list-refresh'));
      for (final rows in [
        <Map<String, Object?>>[],
        [subaccountRows().last],
      ]) {
        repository.result = mapSubaccountDirectory(
          rows,
          address: accountAddress,
          receivedAt: DateTime.now(),
        );
        await show(tester, refresh);
        await tester.tap(refresh.hitTestable());
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(SubaccountListScreen)));
        await show(tester, find.text(l10n.subaccountNoChildren));
        expect(find.text(l10n.subaccountNoChildren), findsOneWidget);
      }
      repository.result = subaccountFixture();
      await show(tester, refresh);
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('subaccount-list-search')));
      identity.events.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('subaccount-list-search')), findsNothing);
      expect(find.text('9007199254740993'), findsNothing);
      expect(find.byKey(const Key('subaccount-connected-wallet')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
