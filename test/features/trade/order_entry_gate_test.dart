import 'dart:async';

import 'package:vanta/core/errors/error_text.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/authorization/presentation/enable_trading_screen.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';

import 'package:flutter/material.dart';
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/features/portfolio/presentation/embedded_time_in_force_selector.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/order_entry_gate_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';

import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('missing agent keeps the server error and offers explicit trading authorization', (
    t,
  ) async {
    final f = NavigationFixture(t);
    await launch(t, f.container);
    f.orders.readFailure = const AccountReadFailure(
      'accountPermissionRequired',
      code: -1000,
      details: ApiErrorDetails(message: 'No agent found', status: 400),
    );
    await f.container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT');
    await t.pumpAndSettle();
    final action = find.byKey(const Key('trade-order-retry'));
    final l = AppLocalizations.of(t.element(action));
    expect(find.textContaining('No agent found'), findsOneWidget);
    expect(find.textContaining('-1000'), findsOneWidget);
    expect(find.descendant(of: action, matching: find.text(l.enableTradingTitle)), findsOneWidget);
    expect(find.descendant(of: action, matching: find.text(l.statusRetry)), findsNothing);
    final reads = f.orders.reads;
    await t.ensureVisible(action);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(find.byType(EnableTradingScreen), findsOneWidget);
    expect(f.identity.signatures, 0);
    expect(f.orders.reads, reads);
    expect(f.orders.submits, 0);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.textContaining('No agent found'), findsOneWidget);
    expect(f.orders.submits, 0);
    expect(f.orders.reads, reads);
    await f.close(t);
  });

  testWidgets('an authorization failure hides cached order actions and preserves entered size', (
    t,
  ) async {
    final f = NavigationFixture(t);
    await launch(t, f.container);
    final controller = f.container.read(liveOrderProvider.notifier);
    await controller.load('BTCUSDT');
    await t.pumpAndSettle();
    final quantity = find.byKey(const Key('live-order-quantity'));
    await t.enterText(quantity, '125');
    f.orders.readFailure = const AccountReadFailure(
      'accountPermissionRequired',
      code: -1000,
      details: ApiErrorDetails(message: 'No agent found'),
    );
    await controller.load('BTCUSDT');
    await t.pumpAndSettle();
    expect(find.byType(LiveOrderForm), findsNothing);
    expect(find.textContaining('No agent found'), findsOneWidget);
    expect(f.orders.submits, 0);
    f.orders.readFailure = null;
    await controller.load('BTCUSDT');
    await t.pumpAndSettle();
    expect(t.widget<TextField>(quantity).controller!.text, '125');
    expect(find.textContaining('No agent found'), findsNothing);
    await f.close(t);
  });

  testWidgets('returning with a newly active grant refreshes facts without submitting an order', (
    t,
  ) async {
    final f = NavigationFixture(t);
    await launch(t, f.container);
    f.orders.readFailure = const AccountReadFailure('authorizationRequired');
    await f.container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT');
    await t.pumpAndSettle();
    final action = find.byKey(const Key('trade-order-retry'));
    await t.ensureVisible(action);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(find.byType(EnableTradingScreen), findsOneWidget);
    final reads = f.orders.reads;
    final store = f.container.read(tradingAgentStoreProvider);
    final agent = await store.prepare(
      signingIdentity.id,
      accountAddress,
      DateTime.now().add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    f.container.invalidate(tradingAgentProvider);
    await f.container.read(tradingAgentProvider.future);
    f.orders.readFailure = null;
    await t.pageBack();
    await t.pumpAndSettle();
    expect(f.orders.reads, greaterThan(reads));
    expect(f.orders.submits, 0);
    expect(f.identity.signatures, 0);
    await f.close(t);
  });

  testWidgets('unsigned form connects from buy and hides sell and separate read', (t) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    final buy = find.byKey(const Key('trade-pending-buy'));
    final l = AppLocalizations.of(t.element(buy));
    expect(find.descendant(of: buy, matching: find.text(l.connect)), findsOneWidget);
    expect(t.widget<FilledButton>(buy).onPressed, isNotNull);
    expect(find.byKey(const Key('trade-pending-sell')), findsNothing);
    expect(find.byKey(const Key('live-order-read')), findsNothing);
    await f.close(t);
  });
  testWidgets('unsigned BBO and advanced options open wallet connection', (t) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    Future<void> expectConnect(Finder control) async {
      await t.ensureVisible(control);
      await t.pumpAndSettle();
      await t.tap(control);
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
    }

    await expectConnect(find.byKey(const Key('live-order-bbo')));
    final advanced = find.byKey(const Key('live-order-advanced'));
    await t.ensureVisible(advanced);
    await t.tap(advanced);
    await t.pumpAndSettle();
    for (final key in ['trade-pending-tpsl', 'trade-pending-hidden', 'trade-pending-reduce-only']) {
      await expectConnect(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)).first,
      );
    }
    await expectConnect(find.byType(EmbeddedTimeInForceSelector));
    f.expectNoAccountMutation();
    await f.close(t);
  });
  for (final code in [-5050, -1]) {
    testWidgets('private read failure uses only appropriate section feedback $code', (t) async {
      final f = NavigationFixture(t);
      await launch(t, f.container);
      f.orders.readGate = Completer<void>();
      f.orders.readFailure = AccountReadFailure('accountDataInvalid', code: code);
      final task = f.container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT');
      await t.pump();
      expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
      expect(find.byKey(const Key('trade-pending-quantity')), findsOneWidget);
      expect(find.byKey(const Key('trade-available-pending')), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final l = AppLocalizations.of(t.element(find.byKey(const Key('trade-live-order'))));
      expect(find.text(l.accountReadPreparing), findsNothing);
      expect(find.text(l.accountReadLoading), findsNothing);
      f.orders.readGate!.complete();
      await task;
      await t.pumpAndSettle();
      expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
      expect(find.byKey(const Key('live-order-error')), findsNothing);
      expect(find.byKey(const Key('live-order-refresh-error')), findsNothing);
      expect(find.byType(LiveOrderForm), findsNothing);
      expect(find.byType(StatusFailureView), code == -5050 ? findsNothing : findsOneWidget);
      if (code == -5050) {
        expect(find.text(l.fundingDeposit), findsOneWidget);
      } else {
        expect(
          find.text(
            accountErrorText(
              t.element(find.byType(StatusFailureView)),
              f.container.read(mainOrderRefreshProvider).failure!,
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('trade-order-retry')), findsOneWidget);
      }
      await f.close(t);
    });
  }
  testWidgets('identity without signing still offers only connect', (t) async {
    final identity = NavigationIdentity()
      ..restored = const AuthIdentity(
        id: 'unsigned',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
        signingAvailable: false,
      );
    addTearDown(identity.dispose);
    final container = setup(t, identityRepository: identity);
    await launch(t, container);
    expect(container.read(orderEntryGateProvider), OrderEntryGate.connect);
    expect(find.byKey(const Key('trade-pending-sell')), findsNothing);
    expect(find.byKey(const Key('live-order-read')), findsNothing);
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump();
  });
  testWidgets('verified account read clears a previous trading deposit prerequisite', (t) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final accounts = TestAsterAccountRepository();
    final orders = TestLiveOrderRepository()
      ..readFailure = const AccountReadFailure('accountDepositRequired', code: -5050);
    final container = setup(
      t,
      identityRepository: identity,
      asterAccountRepository: accounts,
      liveOrderRepository: orders,
    );
    await launch(t, container);
    await container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT');
    await t.pumpAndSettle();
    expect(container.read(orderEntryGateProvider), OrderEntryGate.deposit);
    await container.read(accountReadProvider.notifier).refresh();
    await t.pumpAndSettle();
    expect(container.read(orderEntryGateProvider), OrderEntryGate.ready);
    expect(container.read(mainOrderRefreshProvider).failure, isNull);
    expect(find.byKey(const Key('trade-pending-sell')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump();
  });
  for (final code in [-5050, null]) {
    testWidgets('deposit gate requires verified business code $code', (t) async {
      final accounts = TestAsterAccountRepository()
        ..failure = AccountReadFailure('accountDepositRequired', code: code);
      final identity = NavigationIdentity()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final container = setup(t, identityRepository: identity, asterAccountRepository: accounts);
      await launch(t, container);
      await container.read(accountReadProvider.notifier).refresh();
      await t.pumpAndSettle();
      expect(
        container.read(orderEntryGateProvider),
        code == -5050 ? OrderEntryGate.deposit : OrderEntryGate.ready,
      );
      expect(find.byKey(const Key('live-order-read')), findsNothing);
      expect(
        find.byKey(const Key('trade-pending-sell')),
        code == -5050 ? findsNothing : findsOneWidget,
      );
      if (code == -5050) {
        final buy = find.byKey(const Key('trade-pending-buy'));
        final l = AppLocalizations.of(t.element(buy));
        expect(find.descendant(of: buy, matching: find.text(l.fundingDeposit)), findsOneWidget);
        expect(await container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT'), false);
        expect(accounts.calls, 1);
      }
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await t.pump();
    });
  }
}
