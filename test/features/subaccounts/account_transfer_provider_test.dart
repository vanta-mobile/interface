import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/subaccounts/application/account_transfer_provider.dart';
import 'package:vanta/features/subaccounts/presentation/account_transfer_screen.dart';

import '../../support/aster_account.dart';
import '../../support/generated_accounts.dart';

void main() {
  for (final value in ['0', '-1', '1e2', '0.0000000000000000001', '90']) {
    testWidgets('transfer rejects invalid or unavailable exact amount $value', (t) async {
      final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
      await f.mount(t, const AccountTransferScreen());
      await f.container
          .read(accountTransferProvider.notifier)
          .prepare(target: generatedChildAddress, asset: 'USDT', amount: value);
      expect(f.container.read(accountTransferProvider).failure, isNotNull);
      expect(f.repository.prepares, 0);
      expect(f.repository.sends, 0);
      await f.close(t);
    });
  }
  testWidgets('review preserves 18 decimal places, verifies fresh funds, and submits once', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const AccountTransferScreen());
    final controller = f.container.read(accountTransferProvider.notifier);
    await controller.prepare(
      target: generatedChildAddress,
      asset: 'USDT',
      amount: '1.000000000000000001',
    );
    final review = f.container.read(accountTransferProvider).review!;
    expect(review.record.terms['amount'], '1.000000000000000001');
    expect(review.record.terms['direction'], 'FUTURE_FUTURE');
    expect(f.repository.sends, 0);
    await controller.confirm(review);
    await controller.confirm(review);
    expect(f.repository.sends, 1);
    expect(f.account.calls, 2);
    expect(f.container.read(accountTransferProvider).submitted, isNotNull);
    await f.close(t);
  });
  testWidgets('account change during balance refresh prevents preparation', (t) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const AccountTransferScreen());
    f.account.gate = Completer<void>();
    final task = f.container
        .read(accountTransferProvider.notifier)
        .prepare(target: generatedChildAddress, asset: 'USDT', amount: '1');
    f.identity.events.add(null);
    f.account.gate!.complete();
    await task;
    expect(f.repository.prepares, 0);
    expect(f.repository.sends, 0);
    expect(f.container.read(authProvider).identity, null);
    await f.close(t);
  });
  for (final acknowledged in [false, true]) {
    testWidgets(
      'freeze intent acknowledged=$acknowledged blocks transfers without claiming remote frozen status',
      (t) async {
        final f = GeneratedAccountsFixture(
          t,
          records: [
            createdSubaccountRecord(),
            WalletOperationRecord(
              kind: WalletOperationKind.freezeSubaccount,
              address: accountAddress,
              nonce: 2,
              preparedAt: DateTime.utc(2026, 11, 9),
              terms: {'child': generatedChildAddress},
              acknowledged: acknowledged,
            ),
          ],
        );
        await f.mount(t, const AccountTransferScreen());
        await f.container
            .read(accountTransferProvider.notifier)
            .prepare(target: generatedChildAddress, asset: 'USDT', amount: '1');
        expect(
          f.container.read(accountTransferProvider).failure,
          acknowledged ? 'accountsFrozenNotice' : 'walletOperationPending',
        );
        expect(f.repository.sends, 0);
        expect(f.account.calls, 0);
        await f.close(t);
      },
    );
  }
}
