import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/funding/application/withdrawal_provider.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/account_operations.dart';
import '../../support/deposit_wallet.dart';

void main() {
  testWidgets('withdraw grant is explicit, normalized and cleared on identity change', (t) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final c = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(
          TestTradingAuthorizationRepository(),
        ),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(identity.dispose);
    c.read(authProvider);
    await t.pump();
    final controller = c.read(tradingAuthorizationProvider.notifier);
    controller.prepare(canWithdraw: true, ipWhitelist: 'bad');
    expect(c.read(tradingAuthorizationProvider).failure, 'authorizationIpInvalid');
    controller.prepare(canWithdraw: true, ipWhitelist: ' 203.0.113.8  ');
    expect(c.read(tradingAuthorizationProvider).review!.canWithdraw, true);
    expect(c.read(tradingAuthorizationProvider).review!.ipWhitelist, '203.0.113.8');
    controller.cancel();
    controller.prepare(ipWhitelist: '203.0.113.8');
    expect(c.read(tradingAuthorizationProvider).review!.canWithdraw, false);
    expect(c.read(tradingAuthorizationProvider).review!.ipWhitelist, '');
    identity.events.add(null);
    await t.pump();
    expect(c.read(tradingAuthorizationProvider).review, null);
  });
  for (final action in ['authorization', 'subaccount', 'withdrawal']) {
    for (final event in ['stop', 'logout']) {
      testWidgets('$action $event discards late UI result and never dispatches a second request', (
        t,
      ) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final grant = TestTradingAuthorizationRepository(),
            sub = TestSubaccountManagementRepository(),
            withdraw = TestWithdrawalRepository();
        final c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            tradingAuthorizationRepositoryProvider.overrideWithValue(grant),
            subaccountManagementRepositoryProvider.overrideWithValue(sub),
            withdrawalRepositoryProvider.overrideWithValue(withdraw),
          ],
        );
        addTearDown(c.dispose);
        addTearDown(identity.dispose);
        c.read(authProvider);
        await t.pump();
        final gate = Completer<void>();
        late Future<void> future;
        if (action == 'authorization') {
          final controller = c.read(tradingAuthorizationProvider.notifier);
          controller.prepare();
          grant.gate = gate;
          final review = c.read(tradingAuthorizationProvider).review!;
          future = controller.confirm(review);
          await t.pump();
          if (event == 'stop') {
            controller.stop();
          } else {
            identity.events.add(null);
            await t.pump();
          }
          gate.complete();
          await future;
          expect(
            c.read(tradingAuthorizationProvider).result,
            event == 'stop' ? TradingAuthorizationResult.unknown : null,
          );
          if (event == 'stop') {
            controller.prepare();
            expect(c.read(tradingAuthorizationProvider).review, null);
            await controller.confirm(review);
            await controller.enableTrading();
            expect(c.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
          }
          expect(grant.sends, 1);
        } else if (action == 'subaccount') {
          final controller = c.read(subaccountManagementProvider.notifier);
          await controller.prepare(WalletOperationKind.freezeSubaccount, {
            'child': '0x3333333333333333333333333333333333333333',
          });
          final review = c.read(subaccountManagementProvider).review!;
          sub.gate = gate;
          future = controller.confirm(review);
          await t.pump();
          if (event == 'stop') {
            controller.stop();
          } else {
            identity.events.add(null);
            await t.pump();
          }
          gate.complete();
          await future;
          await controller.confirm(review);
          expect(c.read(subaccountManagementProvider).result, null);
          expect(sub.sends, 1);
        } else {
          final controller = c.read(withdrawalProvider.notifier);
          await controller.prepare(depositQuery(route: 'autoWithdraw'), '1');
          final review = c.read(withdrawalProvider).review!;
          withdraw.gate = gate;
          future = controller.confirm(review);
          await t.pump();
          if (event == 'stop') {
            controller.stop();
          } else {
            identity.events.add(null);
            await t.pump();
          }
          gate.complete();
          await future;
          await controller.confirm(review);
          expect(c.read(withdrawalProvider).result, null);
          expect(withdraw.sends, 1);
        }
      });
    }
  }
}
