import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/funding/application/withdrawal_provider.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_screen.dart';
import '../../support/identity_repository.dart';

void main() {
  testWidgets('stopping a withdrawal permits the next one and ignores the old response', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestWithdrawalRepository();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        withdrawalRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.dispose();
    });
    container.read(authProvider);
    await tester.pump();
    final controller = container.read(withdrawalProvider.notifier);
    final query = depositQuery(route: 'autoWithdraw');
    final firstGate = Completer<void>(), secondGate = Completer<void>();
    repository.gate = firstGate;
    final first = controller.submit(query, '1', shownFee: repository.fee);
    await tester.pump();
    controller.stop();
    repository.gate = secondGate;
    final second = controller.submit(query, '2', shownFee: repository.fee);
    await tester.pump();
    expect(repository.submits, 2);
    firstGate.complete();
    await first;
    expect(container.read(withdrawalProvider).busy, true);
    expect(container.read(withdrawalProvider).result, isNull);
    // The old finally block must not enable a third concurrent submission.
    await controller.submit(query, '3', shownFee: repository.fee);
    expect(repository.submits, 2);
    secondGate.complete();
    await second;
    expect(container.read(withdrawalProvider).result!.terms['amount'], '2');
    expect(container.read(withdrawalProvider).busy, false);
  });
}
