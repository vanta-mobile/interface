import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late MemoryOrderRecoveryJournal journal;
  late TestOrderRecoveryRepository reader;
  late TestLiveOrderRepository orders;
  late OrderRecoveryRecord record;
  setUp(() async {
    record = OrderRecoveryRecord(
      query: OrderQuery.capture(liveIntent()),
      createdAt: liveOrderClock,
    );
    identity = TestIdentityRepository()..restored = signingIdentity;
    journal = MemoryOrderRecoveryJournal(records: [record]);
    reader = TestOrderRecoveryRepository(journal);
    orders = TestLiveOrderRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        orderRecoveryJournalProvider.overrideWithValue(journal),
        orderRecoveryRepositoryProvider.overrideWithValue(reader),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
      ],
    );
    container.read(authProvider);
    container.read(orderRecoveryProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await journal.close();
  });
  OrderRecoveryController controller() => container.read(orderRecoveryProvider.notifier);
  test('restored pending blocks order/config writes; no automatic signatures or query', () async {
    expect(reader.calls, 0);
    expect(identity.wallets, 0);
    expect(container.read(pendingWalletOrdersProvider).single.key, record.key);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    expect(container.read(symbolSettingsActivityProvider).recoveryBlocked, true);
    for (final setting in SymbolSetting.values.where((s) => s != SymbolSetting.recovery)) {
      expect(activity.acquire(setting), null);
    }
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    expect(orders.reads, 0);
    await controller().query(record.key);
    expect(reader.calls, 1);
    expect(reader.latestQuery!.clientOrderId, 'vanta-test-123');
    expect(journal.snapshot.records, isEmpty);
    expect(container.read(symbolSettingsActivityProvider).recoveryBlocked, false);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    expect(orders.reads, 1);
  });
  test('failed query retains pending and original ID through query-only retry', () async {
    reader.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().query(record.key);
    expect(journal.snapshot.records.length, 1);
    expect(container.read(symbolSettingsActivityProvider).unresolved, true);
    reader.result = orders.result;
    await controller().query(record.key);
    expect(reader.calls, 2);
    expect(reader.latestQuery!.key, record.key);
    expect(journal.snapshot.records, isEmpty);
  });
  test(
    'different account cannot see/query original record; returning wallet restores its block',
    () async {
      identity.events.add(
        const AuthIdentity(
          id: 'other',
          walletAddress: '0x3333333333333333333333333333333333333333',
          signingAvailable: true,
        ),
      );
      expect(container.read(pendingWalletOrdersProvider), isEmpty);
      await controller().query(record.key);
      expect(reader.calls, 0);
      final activity = container.read(symbolSettingsActivityProvider.notifier);
      final token = activity.acquire(SymbolSetting.leverage);
      expect(token, isNotNull);
      activity.finish(token!, unresolved: false);
      identity.events.add(signingIdentity);
      expect(container.read(pendingWalletOrdersProvider).single.key, record.key);
      expect(activity.acquire(SymbolSetting.leverage), null);
    },
  );
  test(
    'same address with unavailable signer requires reconnect and never creates wallet',
    () async {
      identity.events.add(
        const AuthIdentity(
          id: 'aster-test',
          walletAddress: accountAddress,
          walletKind: WalletKind.external,
          signingAvailable: false,
        ),
      );
      await controller().query(record.key);
      expect(reader.calls, 0);
      expect(identity.wallets, 0);
      expect(journal.snapshot.records.length, 1);
    },
  );
  test(
    'identity changes while query is pending discard late result and keep durable record',
    () async {
      reader.gate = Completer<void>();
      final pending = controller().query(record.key);
      await container.read(authProvider.notifier).logout();
      reader.gate!.complete();
      await pending;
      expect(container.read(orderRecoveryProvider).record, null);
      expect(journal.snapshot.records.length, 1);
      expect(container.read(pendingWalletOrdersProvider), isEmpty);
    },
  );
  test('storage failure blocks new operations without dropping known entries', () async {
    journal.publish(
      OrderRecoverySnapshot(
        records: [record],
        failure: const AccountReadFailure('orderRecoveryStorage'),
      ),
    );
    expect(
      container.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order),
      null,
    );
    await controller().query(record.key);
    expect(reader.calls, 0);
    expect(journal.snapshot.records.single.key, record.key);
    journal.publish(OrderRecoverySnapshot(records: [record]));
    await controller().query(record.key);
    expect(reader.calls, 1);
  });
  test('duplicate tap does not open multiple wallet prompts', () async {
    reader.gate = Completer<void>();
    final first = controller().query(record.key);
    await controller().query(record.key);
    expect(reader.calls, 1);
    reader.gate!.complete();
    await first;
  });
}
