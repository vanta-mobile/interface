import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_account_load_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

void main() {
  for (final depositRequired in [true, false]) {
    testWidgets(
      'portfolio gates automatic reads only for verified deposit-required code: $depositRequired',
      (tester) async {
        const serverMessage = 'This function can only be used after deposit Aster.';
        final identity = NavigationIdentity()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final account = TestAsterAccountRepository()
          ..failure = AccountReadFailure(
            'accountDepositRequired',
            code: depositRequired ? -5050 : null,
            details: const ApiErrorDetails(message: serverMessage),
          );
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
        expect(container.read(portfolioOverviewProvider).totalUsd, isNull);
        expect(find.byKey(const Key('portfolio-deposit-required')), findsNothing);
        // The redesigned page shows account feedback below the Futures list,
        // which can sit below the fold.
        expect(
          find.byKey(const Key('account-read-error'), skipOffstage: false),
          depositRequired ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(serverMessage, skipOffstage: false),
          depositRequired ? findsNothing : findsOneWidget,
        );
        // The original structured server failure remains available to diagnostics.
        expect(container.read(accountReadProvider).failure?.details?.message, serverMessage);
        await tapNavigationControl(tester, 'navigation-assistant');
        await tapNavigationControl(tester, 'navigation-portfolio');
        container.invalidate(portfolioAccountLoadProvider);
        await tester.pumpAndSettle();
        expect(account.calls, depositRequired ? 1 : greaterThan(1));

        // A successful post-deposit refresh may legitimately contain no funds.
        account.failure = null;
        account.result = AsterAccount(
          address: accountAddress,
          receivedAt: DateTime.now(),
          assets: const [],
          positions: const [],
          walletBalance: Decimal.zero,
        );
        final indicator = find.byKey(const Key('portfolio-page'));
        await tester.drag(indicator, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(container.read(accountReadProvider).account, same(account.result));
        expect(container.read(accountReadProvider).failure, isNull);
        expect(find.byKey(const Key('portfolio-deposit-required')), findsNothing);
        final calls = account.calls;
        container.read(accountReadProvider.notifier).markStale();
        container.invalidate(portfolioAccountLoadProvider);
        await tester.pumpAndSettle();
        expect(account.calls, calls + 1); // zero balance is not a deposit gate
        expect(identity.signatures, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets('deposit-required status is cleared when the owner changes', (tester) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final accounts = TestAsterAccountRepository()
      ..failure = const AccountReadFailure('accountDepositRequired', code: -5050);
    final container = setup(tester, identityRepository: identity, asterAccountRepository: accounts);
    await launch(tester, container);
    await container.read(accountReadProvider.notifier).refresh();
    expect(container.read(accountReadProvider).failure?.code, -5050);
    const nextAddress = '0x3333333333333333333333333333333333333333';
    identity.events.add(
      const AuthIdentity(
        id: 'next-owner',
        walletAddress: nextAddress,
        walletKind: WalletKind.external,
        signingAvailable: true,
      ),
    );
    await tester.pump();
    expect(container.read(authProvider).identity?.walletAddress, nextAddress);
    expect(container.read(accountReadProvider).failure, isNull);
    accounts.failure = null;
    accounts.result = accountFixture(address: nextAddress);
    await container.read(accountReadProvider.notifier).refresh();
    expect(accounts.calls, 2);
    expect(container.read(accountReadProvider).account?.address, nextAddress);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
