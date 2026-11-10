import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';

import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

void main() {
  testWidgets(
    'authorized portfolio loads owner assets once and refresh preserves data until settled',
    (tester) async {
      final identity = NavigationIdentity()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final account = TestAsterAccountRepository();
      final store = MemoryTradingAgentStorage().store(DateTime.now);
      final agent = await store.prepare(
        signingIdentity.id,
        accountAddress,
        DateTime.now().add(const Duration(days: 30)),
      );
      await store.setStatus(agent, TradingAgentStatus.unknown);
      await store.setStatus(agent, TradingAgentStatus.active);
      final container = setup(
        tester,
        identityRepository: identity,
        asterAccountRepository: account,
        tradingAgentStore: store,
      );
      await launch(tester, container);
      await tapNavigationControl(tester, 'navigation-portfolio');
      expect(account.calls, 1);
      expect(container.read(accountReadProvider).account?.address, accountAddress);
      expect(find.byKey(const Key('read-aster-account')), findsNothing);
      expect(find.byKey(const Key('portfolio-enable-trading')), findsNothing);
      expect(identity.signatures, 0);
      container.read(portfolioOverviewProvider);
      await tester.pumpAndSettle();
      expect(account.calls, 1);

      account.gate = Completer<void>();
      var settled = false;
      final refresh = container.read(portfolioRefreshProvider)().then((_) => settled = true);
      await tester.pump();
      expect(settled, false);
      expect(container.read(accountReadProvider).account, isNotNull);
      expect(find.byKey(const Key('portfolio-account-loading')), findsNothing);
      account.gate!.complete();
      await refresh;
      await tester.pumpAndSettle();
      expect(settled, true);
      expect(account.calls, 2);
      expect(identity.signatures, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('an unknown grant does not load or prompt; activation loads the visible page', (
    tester,
  ) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final account = TestAsterAccountRepository();
    final store = MemoryTradingAgentStorage().store(DateTime.now);
    final agent = await store.prepare(
      signingIdentity.id,
      accountAddress,
      DateTime.now().add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    final container = setup(
      tester,
      identityRepository: identity,
      asterAccountRepository: account,
      tradingAgentStore: store,
    );
    await launch(tester, container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    expect(account.calls, 0);
    expect(identity.signatures, 0);
    expect(find.byKey(const Key('read-aster-account')), findsNothing);
    expect(find.byKey(const Key('portfolio-enable-trading')), findsOneWidget);
    await store.setStatus(agent, TradingAgentStatus.active);
    container.invalidate(tradingAgentProvider);
    await tester.pumpAndSettle();
    expect(account.calls, 1);
    expect(find.byKey(const Key('portfolio-enable-trading')), findsNothing);
    expect(identity.signatures, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
