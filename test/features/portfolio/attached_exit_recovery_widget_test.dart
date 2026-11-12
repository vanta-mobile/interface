import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/presentation/strategy_execution_screen.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final legacy in [true, false]) {
      testWidgets(
        'internal verification preserves original quantity, execution and lifecycle $locale legacy=$legacy',
        (tester) async {
          final intent = attachedIntent(
            quantity: '0.003',
            protection: const LiveOrderAttachment(
              stopLoss: AttachedExit(
                kind: LiveOrderTriggerKind.stop,
                price: '79000',
                execution: AttachedExitExecution.manualLimit,
                limitPrice: '78999.9',
              ),
            ),
          );
          var record = OrderRecoveryRecord(
            query: OrderQuery.capture(intent),
            createdAt: liveOrderClock,
          );
          if (legacy) {
            final fields = legacyRecoveryFields(encodeRecoveryRecord(record));
            fields['protectedQuantity'] = '0.001';
            record = decodeRecoveryRecord(fields);
          }
          final journal = MemoryOrderRecoveryJournal(records: [record]);
          addTearDown(journal.close);
          final identity = TestIdentityRepository()..restored = signingIdentity;
          addTearDown(identity.dispose);
          final repository = TestOrderRecoveryRepository(journal)
            ..result = LiveOrderResult(
              strategy: AttachedOrderSnapshot(
                strategyId: '9876',
                status: 'WORKING',
                legs: const [
                  AttachedOrderLeg(sequence: 1, status: 'PARTIALLY_FILLED', orderId: '100'),
                  AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW'),
                ],
              ),
            );
          final container = setup(
            tester,
            width: 320,
            scale: 1.5,
            language: Locale(locale),
            identityRepository: identity,
            recoveryJournal: journal,
            recoveryRepository: repository,
          );
          await launch(tester, container);
          expect(repository.calls, 0);
          await container.read(orderRecoveryProvider.notifier).query(record.key);
          await tester.pumpAndSettle();
          expect(repository.calls, 1);
          expect(repository.latestQuery!.protectedQuantity, legacy ? '0.001' : '0.003');
          expect(
            repository.latestQuery!.draft.attachment!.drivenOn,
            legacy ? AttachedOrderDrivenOn.filled : AttachedOrderDrivenOn.partialOrFilled,
          );
          expect(journal.snapshot.records, isEmpty);
          expect(
            repository.latestQuery!.draft.attachment!.stopLoss!.execution,
            legacy ? AttachedExitExecution.market : AttachedExitExecution.manualLimit,
          );
          final result = container.read(orderRecoveryProvider).result!;
          openStrategyExecution(
            tester.element(find.byType(Navigator).first),
            record.query,
            result.strategy!.strategyId,
          );
          await tester.pumpAndSettle();
          final details = tester.widget<StrategyExecutionScreen>(
            find.byType(StrategyExecutionScreen),
          );
          expect(details.query.strategyId, '9876');
          expect(identical(details.query.order, record.query), true);
          expect(details.query.order.protectedQuantity, legacy ? '0.001' : '0.003');
          expect(repository.calls, 1);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
      );
    }
  }
}
